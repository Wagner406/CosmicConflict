//
//  BossFight.swift
//  SpaceGame
//

import SpriteKit

// MARK: - Boss Fight
extension GameScene {

    enum BossPhase {
        case phase1
        case phase2
        case phase3
        case dead
    }

    // ✅ 10 Hits pro Phase → 30 HP total
    private var bossHitsPerPhase: Int { 10 }
    private var bossTotalHP: Int { bossHitsPerPhase * 3 } // 30

    // MARK: - Tuning
    private var phase3PauseDuration: TimeInterval { 2.5 }

    /// Wie oft soll Phase 3 eine Shield-Pause machen?
    private var phase3NextPauseRange: ClosedRange<TimeInterval> { 9.0...13.0 }

    /// Mindestabstand zwischen Minion-Spawns (auch wenn Pause öfter kommt)
    private var phase3MinionCooldown: TimeInterval { 14.0 }

    // MARK: - Helpers

    private func clamp(_ v: CGFloat, _ minV: CGFloat, _ maxV: CGFloat) -> CGFloat {
        max(minV, min(maxV, v))
    }

    /// Sichtbarer Bereich in Scene-Units (Camera-Zoom berücksichtigt)
    private func visibleSceneWidth() -> CGFloat {
        guard cameraNode.parent != nil else { return size.width }
        let zoom = max(0.0001, cameraNode.xScale)
        return size.width / zoom
    }

    private func visibleSceneHeight() -> CGFloat {
        guard cameraNode.parent != nil else { return size.height }
        let zoom = max(0.0001, cameraNode.yScale)
        return size.height / zoom
    }

    /// Referenz-Größe für Boss (stabil bei iPhone/iPad + Rotation + Zoom)
    private func bossReferenceSize() -> CGFloat {
        min(visibleSceneWidth(), visibleSceneHeight())
    }

    /// HIER stellst du die Boss-Größe ein (ein einziger Ort)
    private func desiredBossWidth() -> CGFloat {
        let base = bossReferenceSize()
        return clamp(base * 0.34, 140, 260)   // <- kleiner? 0.30 / min/max runter. Größer? 0.38 / max hoch.
    }

    /// Kannst du aus GameScene.didChangeSize(...) aufrufen (und wir rufen es auch intern einmal verzögert auf)
    func relayoutBossIfNeeded() {
        guard let b = boss else { return }
        let tex = b.texture ?? SKTexture(imageNamed: "Boss")

        let scale = desiredBossWidth() / max(1, tex.size().width)
        b.setScale(scale)

        // Hitbox neu (weil Größe sich ändert)
        let radius = max(b.size.width, b.size.height) * 0.35
        b.physicsBody = SKPhysicsBody(circleOfRadius: radius)
        b.physicsBody?.isDynamic = false
        b.physicsBody?.categoryBitMask = PhysicsCategory.enemy
        b.physicsBody?.contactTestBitMask = PhysicsCategory.bullet | PhysicsCategory.player
        b.physicsBody?.collisionBitMask = 0

        // Shield-Ring folgt ohnehin der Boss-Size (bei neu aktivieren),
        // aber wenn gerade aktiv, passt du ihn hier auch an:
        if let shield = bossShieldNode {
            shield.removeAllActions()
            shield.removeFromParent()
            bossShieldNode = nil
            if bossIsShieldActive { applyBossShield(on: b) }
        }
    }

    // MARK: - Setup

    func setupBossIfNeeded() {
        guard boss == nil else { return }

        let bossTexture = SKTexture(imageNamed: "Boss")
        let b = SKSpriteNode(texture: bossTexture)
        b.name = "boss"
        b.zPosition = 40

        // ✅ FIX: Boss-Größe anhand der sichtbaren Kamera-Fläche (nicht Level-Frame!)
        let scale = desiredBossWidth() / max(1, bossTexture.size().width)
        b.setScale(scale)

        if let lvl = levelNode {
            b.position = CGPoint(x: lvl.frame.midX, y: lvl.frame.maxY - 250)
        } else {
            b.position = CGPoint(x: 0, y: 300)
        }

        if b.userData == nil { b.userData = NSMutableDictionary() }
        let maxHP = bossTotalHP
        b.userData?["bossMaxHP"] = maxHP
        b.userData?["bossHP"] = maxHP

        let radius = max(b.size.width, b.size.height) * 0.35
        b.physicsBody = SKPhysicsBody(circleOfRadius: radius)
        b.physicsBody?.isDynamic = false
        b.physicsBody?.categoryBitMask = PhysicsCategory.enemy
        b.physicsBody?.contactTestBitMask = PhysicsCategory.bullet | PhysicsCategory.player
        b.physicsBody?.collisionBitMask = 0

        addChild(b)
        boss = b
        enemies.append(b)

        bossPhase = .phase1
        bossIsShieldActive = false
        removeBossShield()

        // Timer init
        bossPauseUntil = 0
        bossNextMoveTime = 0
        bossNextShotTime = 0

        bossBurstShotsRemaining = 0
        bossBurstNextShotTime = 0

        // Phase-3 state init (stored in GameScene)
        bossNextShieldPauseTime = 0
        bossDidSpawnMinionsThisPause = false
        bossPhase3UseShotgunNext = true
        bossNextMinionSpawnTime = 0

        // ✅ Wichtig:
        // In didMove() setzt du danach cameraNode.setScale(bossCameraZoom).
        // Damit der Boss danach NICHT plötzlich riesig bleibt, resizen wir 1 Tick später nochmal.
        run(.sequence([
            .wait(forDuration: 0.0),
            .run { [weak self] in self?.relayoutBossIfNeeded() }
        ]))
    }

    // MARK: - Main Update

    func updateBossFight(currentTime: TimeInterval) {
        guard let b = boss, bossPhase != .dead else { return }

        updateBossPhaseIfNeeded(currentTime: currentTime)

        // ✅ Phase 3 – regelmäßige Schild-Pause (mit größeren Abständen)
        if bossPhase == .phase3 {
            if bossNextShieldPauseTime == 0 {
                bossNextShieldPauseTime = currentTime + TimeInterval.random(in: phase3NextPauseRange)
            }

            if currentTime >= bossNextShieldPauseTime {
                bossPauseUntil = currentTime + phase3PauseDuration
                bossNextShieldPauseTime = currentTime + TimeInterval.random(in: phase3NextPauseRange)

                // pro Pause neu erlauben (aber Spawn ist trotzdem zeit-gegated)
                bossDidSpawnMinionsThisPause = false
            }
        }

        let isPaused = currentTime < bossPauseUntil

        if !isPaused {
            updateBossMovement(currentTime: currentTime)
        } else {
            b.removeAction(forKey: "bossMove")
        }

        updateBossShooting(currentTime: currentTime, isPaused: isPaused)

        // HUD aktuell halten (liegt in BossHUD.swift)
        updateBossHUD()
    }

    // MARK: - Phase Switching

    private func updateBossPhaseIfNeeded(currentTime: TimeInterval) {
        guard let b = boss,
              let hp = b.userData?["bossHP"] as? Int
        else { return }

        if hp <= 0 {
            if bossPhase != .dead { bossPhase = .dead }
            return
        }

        if hp > bossHitsPerPhase * 2 {             // > 20
            if bossPhase != .phase1 {
                bossPhase = .phase1
                bossIsShieldActive = false
                removeBossShield()
                bossBurstShotsRemaining = 0
            }

        } else if hp > bossHitsPerPhase {          // 11...20
            if bossPhase != .phase2 {
                bossPhase = .phase2
                bossIsShieldActive = false
                removeBossShield()
                bossBurstShotsRemaining = 0
            }

        } else {                                   // 1...10
            if bossPhase != .phase3 {
                bossPhase = .phase3
                bossIsShieldActive = false
                removeBossShield()
                bossBurstShotsRemaining = 0

                // Phase-3 State sauber resetten
                bossNextShieldPauseTime = 0
                bossDidSpawnMinionsThisPause = false
                bossPauseUntil = 0

                bossPhase3UseShotgunNext = true
                bossNextMinionSpawnTime = currentTime + 3.0 // nicht sofort spammen

                // damit er nicht "alte" Shot-Timer übernimmt
                bossNextShotTime = currentTime + 0.6
            }
        }
    }

    // MARK: - Movement

    private func updateBossMovement(currentTime: TimeInterval) {
        // während Pause keine neue Bewegung planen
        if bossPhase == .phase3 && currentTime < bossPauseUntil { return }
        guard let b = boss else { return }

        let retargetInterval: TimeInterval
        switch bossPhase {
        case .phase1: retargetInterval = 1.4
        case .phase2: retargetInterval = 1.1
        case .phase3: retargetInterval = 0.9
        case .dead:   retargetInterval = 999
        }

        if currentTime < bossNextMoveTime { return }
        bossNextMoveTime = currentTime + retargetInterval

        guard let lvl = levelNode else { return }

        let minX = lvl.frame.minX + 200
        let maxX = lvl.frame.maxX - 200
        let minY = lvl.frame.midY
        let maxY = lvl.frame.maxY - 160

        let target = CGPoint(
            x: CGFloat.random(in: minX...maxX),
            y: CGFloat.random(in: minY...maxY)
        )

        let speed: CGFloat
        switch bossPhase {
        case .phase1: speed = 120
        case .phase2: speed = 160
        case .phase3: speed = 190
        case .dead:   speed = 0
        }

        let maxStep: CGFloat = 260
        let dx = target.x - b.position.x
        let dy = target.y - b.position.y
        let dist = max(1, hypot(dx, dy))

        let step = min(maxStep, dist)
        let nx = dx / dist
        let ny = dy / dist
        let limitedTarget = CGPoint(
            x: b.position.x + nx * step,
            y: b.position.y + ny * step
        )

        let duration = TimeInterval(step / max(1, speed))

        b.removeAction(forKey: "bossMove")
        let move = SKAction.move(to: limitedTarget, duration: duration)
        move.timingMode = .easeInEaseOut
        b.run(move, withKey: "bossMove")

        if let p = playerShip {
            let ang = atan2(p.position.y - b.position.y, p.position.x - b.position.x)
            b.zRotation = ang - .pi / 2
        }
    }

    // MARK: - Shooting

    private func updateBossShooting(currentTime: TimeInterval, isPaused: Bool) {
        guard let b = boss, let p = playerShip else { return }

        switch bossPhase {

        case .phase1:
            if currentTime < bossNextShotTime { return }
            bossNextShotTime = currentTime + TimeInterval.random(in: 3.0...4.0)
            bossFireShotgun(from: b, to: p.position, pelletCount: 6, spread: .pi / 10)

        case .phase2:
            if bossBurstShotsRemaining <= 0 && currentTime >= bossNextShotTime {
                bossBurstShotsRemaining = 5
                bossBurstNextShotTime = currentTime
                bossNextShotTime = currentTime + 3.0
            }
            fireBossBurstIfNeeded(currentTime: currentTime, from: b, to: p.position)

        case .phase3:
            if isPaused {
                if !bossIsShieldActive {
                    bossIsShieldActive = true
                    applyBossShield(on: b)
                }

                if !bossDidSpawnMinionsThisPause,
                   currentTime >= bossNextMinionSpawnTime {
                    spawnBossMinions(count: 2)
                    bossDidSpawnMinionsThisPause = true
                    bossNextMinionSpawnTime = currentTime + phase3MinionCooldown
                }
                return
            } else {
                if bossIsShieldActive {
                    bossIsShieldActive = false
                    removeBossShield()
                }
            }

            if bossBurstShotsRemaining > 0 {
                fireBossBurstIfNeeded(currentTime: currentTime, from: b, to: p.position)
                return
            }

            if currentTime < bossNextShotTime { return }

            if bossPhase3UseShotgunNext {
                bossFireShotgun(from: b, to: p.position, pelletCount: 7, spread: .pi / 9)
                bossNextShotTime = currentTime + 3.0
            } else {
                bossBurstShotsRemaining = 5
                bossBurstNextShotTime = currentTime
                bossNextShotTime = currentTime + 3.0
                fireBossBurstIfNeeded(currentTime: currentTime, from: b, to: p.position)
            }

            bossPhase3UseShotgunNext.toggle()

        case .dead:
            return
        }
    }

    private func fireBossBurstIfNeeded(currentTime: TimeInterval, from b: SKSpriteNode, to target: CGPoint) {
        guard bossBurstShotsRemaining > 0 else { return }
        if currentTime < bossBurstNextShotTime { return }

        bossBurstShotsRemaining -= 1
        bossBurstNextShotTime = currentTime + 0.12
        bossFireSingle(from: b, to: target)
    }

    // MARK: - Boss Damage

    func applyDamageToBoss(_ boss: SKSpriteNode, amount: Int) {
        if bossIsShieldActive { return }
        if boss.userData == nil { boss.userData = NSMutableDictionary() }

        let hp = (boss.userData?["bossHP"] as? Int) ?? bossTotalHP
        let newHP = max(0, hp - amount)
        boss.userData?["bossHP"] = newHP

        SoundManager.shared.playRandomBossHit(in: self)
        
        flashBossOnHit(boss)

        updateBossPhaseIfNeeded(currentTime: currentTimeForCollisions)
        updateBossHUD()

        if newHP <= 0 {
            killBoss(boss)
        }
    }

    private func flashBossOnHit(_ boss: SKSpriteNode) {
        boss.removeAction(forKey: "bossHitFlash")
        let inA = SKAction.fadeAlpha(to: 0.6, duration: 0.05)
        let outA = SKAction.fadeAlpha(to: 1.0, duration: 0.08)
        boss.run(.sequence([inA, outA]), withKey: "bossHitFlash")
    }

    private func killBoss(_ boss: SKSpriteNode) {
        bossPhase = .dead
        bossIsShieldActive = false
        removeBossShield()

        teardownBossHUD()

        let base = bossReferenceSize()
        let explosionWidth = clamp(base * 0.42, 180, 380)

        vfx.playEnemyShipExplosion(at: boss.position,
                                   zPosition: boss.zPosition,
                                   desiredWidth: explosionWidth)
        SoundManager.shared.playRandomExplosion(in: self)

        boss.removeAllActions()
        boss.physicsBody = nil
        boss.run(.sequence([.fadeOut(withDuration: 0.25), .removeFromParent()]))

        enemies.removeAll { $0 == boss }
        self.boss = nil

        // ✅ NICHT vorher isLevelCompleted setzen
        handleLevelCompleted()

        run(.sequence([
            .wait(forDuration: 3.0),
            .run { [weak self] in
                self?.onLevelCompleted?()
            }
        ]))
    }

    // MARK: - Shield Visual

    private func applyBossShield(on boss: SKSpriteNode) {
        SoundManager.shared.playSFX(Sound.shieldOn, in: self)
        
        removeBossShield()

        let r = max(boss.size.width, boss.size.height) * 0.55
        let ring = SKShapeNode(circleOfRadius: r)
        ring.position = boss.position
        ring.zPosition = boss.zPosition + 2
        ring.strokeColor = .cyan
        ring.lineWidth = 6
        ring.glowWidth = 18
        ring.fillColor = .clear
        ring.alpha = 0.85
        ring.blendMode = .add
        addChild(ring)

        bossShieldNode = ring

        let s1 = SKAction.scale(to: 1.05, duration: 0.25)
        let s2 = SKAction.scale(to: 0.98, duration: 0.25)
        ring.run(.repeatForever(.sequence([s1, s2])), withKey: "shieldPulse")
    }

    private func removeBossShield() {
        guard bossShieldNode != nil else { return }

        SoundManager.shared.playSFX(Sound.shieldOff, in: self)

        bossShieldNode?.removeAllActions()
        bossShieldNode?.removeFromParent()
        bossShieldNode = nil
    }

    func bossFollowShieldIfNeeded() {
        if let b = boss, let shield = bossShieldNode {
            shield.position = b.position
        }
    }

    // MARK: - Shots

    private func bossFireSingle(from boss: SKSpriteNode, to target: CGPoint) {
        SoundManager.shared.playSFX(Sound.multiShot, in: self)
        spawnBossBullet(from: boss.position, to: target, speed: 520)
    }

    private func bossFireShotgun(from boss: SKSpriteNode, to target: CGPoint, pelletCount: Int, spread: CGFloat) {
        SoundManager.shared.playSFX(Sound.shotGun, in: self)
        let baseAngle = atan2(target.y - boss.position.y, target.x - boss.position.x)

        for i in 0..<pelletCount {
            let t = pelletCount <= 1 ? 0 : CGFloat(i) / CGFloat(pelletCount - 1)
            let offset = (t - 0.5) * spread
            let ang = baseAngle + offset

            let dir = CGPoint(x: cos(ang), y: sin(ang))
            let far = CGPoint(
                x: boss.position.x + dir.x * 1000,
                y: boss.position.y + dir.y * 1000
            )

            spawnBossBullet(from: boss.position, to: far, speed: 540)
        }
    }

    private func spawnBossBullet(from: CGPoint, to: CGPoint, speed: CGFloat) {
        let bullet = SKSpriteNode(color: .cyan, size: CGSize(width: 10, height: 4))
        bullet.position = from
        bullet.zPosition = 55
        bullet.blendMode = .add

        bullet.physicsBody = SKPhysicsBody(rectangleOf: bullet.size)
        bullet.physicsBody?.isDynamic = true
        bullet.physicsBody?.affectedByGravity = false
        bullet.physicsBody?.categoryBitMask = PhysicsCategory.enemyBullet
        bullet.physicsBody?.contactTestBitMask = PhysicsCategory.player
        bullet.physicsBody?.collisionBitMask = 0

        addChild(bullet)

        let dx = to.x - from.x
        let dy = to.y - from.y
        let dist = max(1, hypot(dx, dy))
        let vx = dx / dist * speed
        let vy = dy / dist * speed

        bullet.zRotation = atan2(vy, vx)
        bullet.physicsBody?.velocity = CGVector(dx: vx, dy: vy)

        bullet.run(.sequence([.wait(forDuration: 4.0), .removeFromParent()]))
    }

    // MARK: - Minions

    private func spawnBossMinions(count: Int) {
        guard let lvl = levelNode else { return }

        for _ in 0..<count {
            let x = CGFloat.random(in: (lvl.frame.midX - 300)...(lvl.frame.midX + 300))
            let y = CGFloat.random(in: (lvl.frame.midY)...(lvl.frame.maxY - 220))
            let pos = CGPoint(x: x, y: y)

            let enemy = makeChaserShip()
            enemy.position = pos

            if enemy.userData == nil { enemy.userData = NSMutableDictionary() }
            enemy.userData?["isBossMinion"] = true
            enemy.name = "bossMinion"

            addChild(enemy)
            enemies.append(enemy)
            enemyShips.append(enemy)
        }
    }
}
