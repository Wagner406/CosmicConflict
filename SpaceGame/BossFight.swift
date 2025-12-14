//
//  Bossfight.swift
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

    // ✅ 10 Schüsse pro Phase → 30 HP total
    private var bossHitsPerPhase: Int { 10 }
    private var bossTotalHP: Int { bossHitsPerPhase * 3 } // 30

    // MARK: Setup

    func setupBossIfNeeded() {
        guard boss == nil else { return }

        // ✅ Asset heißt "Boss"
        let bossTexture = SKTexture(imageNamed: "Boss")
        let b = SKSpriteNode(texture: bossTexture)
        b.name = "boss"
        b.zPosition = 40

        // Größe
        let desiredWidth = size.width * 0.45
        let scale = desiredWidth / max(1, bossTexture.size().width)
        b.setScale(scale)

        // Spawn oben in der Arena
        if let lvl = levelNode {
            b.position = CGPoint(x: lvl.frame.midX, y: lvl.frame.maxY - 250)
        } else {
            b.position = CGPoint(x: 0, y: 300)
        }

        // ✅ Boss-HP: fix 30 (3 Phasen à 10 Hits)
        if b.userData == nil { b.userData = NSMutableDictionary() }
        let maxHP = bossTotalHP
        b.userData?["bossMaxHP"] = maxHP
        b.userData?["bossHP"] = maxHP

        // Physik: Boss ist "enemy"
        let radius = max(b.size.width, b.size.height) * 0.35
        b.physicsBody = SKPhysicsBody(circleOfRadius: radius)
        b.physicsBody?.isDynamic = false
        b.physicsBody?.categoryBitMask = PhysicsCategory.enemy
        b.physicsBody?.contactTestBitMask = PhysicsCategory.bullet | PhysicsCategory.player
        b.physicsBody?.collisionBitMask = 0

        addChild(b)
        boss = b
        enemies.append(b)

        // Initial Phase
        bossPhase = .phase1
        bossIsShieldActive = false
        removeBossShield()

        // Timer init (wichtig, sonst keine Pause)
        bossLastPauseTriggerTime = 0
        bossPauseUntil = 0

        // Schuss- und Move-Timer
        bossNextMoveTime = 0
        bossNextShotTime = 0

        bossBurstShotsRemaining = 0
        bossBurstNextShotTime = 0

        // ✅ HUD: sichtbar + initial updaten
        setupBossHUD()
        updateBossHUD()
    }

    // MARK: Main Update

    func updateBossFight(currentTime: TimeInterval) {
        guard let b = boss, bossPhase != .dead else { return }

        updateBossPhaseIfNeeded()

        // ✅ Phase 1: alle 10s Pause erzwingen (2.0s)
        if bossPhase == .phase1 {
            if bossLastPauseTriggerTime == 0 {
                bossLastPauseTriggerTime = currentTime
            }

            if currentTime - bossLastPauseTriggerTime >= 10.0 {
                bossPauseUntil = currentTime + 2.0
                bossLastPauseTriggerTime = currentTime
            }
        }

        // Während Pause: keine Bewegung
        let isPaused = currentTime < bossPauseUntil

        if !isPaused {
            updateBossMovement(currentTime: currentTime)
        } else {
            b.removeAction(forKey: "bossMove")
        }

        // Shooting
        updateBossShooting(currentTime: currentTime, isPaused: isPaused)

        // HUD immer aktuell
        updateBossHUD()
    }

    // MARK: Phase Switching (✅ exakt 10 Hits pro Phase)

    private func updateBossPhaseIfNeeded() {
        guard let b = boss,
              let hp = b.userData?["bossHP"] as? Int
        else { return }

        // HP-Ranges:
        // 21...30 = Phase 1 (10 Hits bis 20)
        // 11...20 = Phase 2 (10 Hits bis 10)
        //  1...10 = Phase 3 (10 Hits bis 0)
        //  0      = dead
        if hp <= 0 {
            if bossPhase != .dead { bossPhase = .dead }
            return
        }

        if hp > bossHitsPerPhase * 2 {             // >20
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
            }
        }
    }

    // MARK: Movement (slower + less chaotic)

    private func updateBossMovement(currentTime: TimeInterval) {
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
        let limitedTarget = CGPoint(x: b.position.x + nx * step,
                                    y: b.position.y + ny * step)

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

    // MARK: Shooting

    private func updateBossShooting(currentTime: TimeInterval, isPaused: Bool) {
        guard let b = boss, let p = playerShip else { return }

        switch bossPhase {
        case .phase1:
            if currentTime < bossNextShotTime { return }

            let next = TimeInterval.random(in: 3.0...4.0)
            bossNextShotTime = currentTime + next

            bossFireShotgun(from: b, to: p.position, pelletCount: 6, spread: .pi / 10)

        case .phase2:
            if bossBurstShotsRemaining <= 0 && currentTime >= bossNextShotTime {
                bossBurstShotsRemaining = 5
                bossBurstNextShotTime = currentTime
                bossNextShotTime = currentTime + 3.0

                spawnBossMinions(count: 2)
            }

            fireBossBurstIfNeeded(currentTime: currentTime, from: b, to: p.position)

        case .phase3:
            if isPaused {
                if !bossIsShieldActive {
                    bossIsShieldActive = true
                    applyBossShield(on: b)
                    spawnBossMinions(count: 4)
                }
                return
            } else {
                if bossIsShieldActive {
                    bossIsShieldActive = false
                    removeBossShield()
                }
            }

            if currentTime < bossNextShotTime { return }

            let choose = Int.random(in: 0...1)
            if choose == 0 {
                bossBurstShotsRemaining = 5
                bossBurstNextShotTime = currentTime
                bossNextShotTime = currentTime + 3.2
            } else {
                bossNextShotTime = currentTime + 3.2
                bossFireShotgun(from: b, to: p.position, pelletCount: 7, spread: .pi / 9)
            }

            fireBossBurstIfNeeded(currentTime: currentTime, from: b, to: p.position)

        case .dead:
            return
        }
    }

    // MARK: HUD

    func setupBossHUD() {
        bossHealthBarBg?.removeFromParent()
        bossHealthBarFill?.removeFromParent()
        bossHealthLabel?.removeFromParent()
        bossPhaseLabel?.removeFromParent()

        let barWidth: CGFloat = 360
        let barHeight: CGFloat = 18

        let yTop: CGFloat = (size.height / 2) - 70
        let xLeft: CGFloat = -barWidth / 2

        let bg = SKShapeNode(rect: CGRect(x: xLeft, y: yTop, width: barWidth, height: barHeight), cornerRadius: 6)
        bg.fillColor = SKColor(white: 0.0, alpha: 0.45)
        bg.strokeColor = SKColor(white: 1.0, alpha: 0.25)
        bg.lineWidth = 2
        bg.zPosition = 500

        let fill = SKShapeNode(rect: CGRect(x: xLeft, y: yTop, width: barWidth, height: barHeight), cornerRadius: 6)
        fill.fillColor = .red
        fill.strokeColor = .clear
        fill.zPosition = 501

        let name = SKLabelNode(fontNamed: "AvenirNext-Bold")
        name.text = level.config.bossName ?? "BOSS"
        name.fontSize = 18
        name.fontColor = .white
        name.horizontalAlignmentMode = .center
        name.verticalAlignmentMode = .center
        name.position = CGPoint(x: 0, y: yTop + barHeight + 16)
        name.zPosition = 502

        let phase = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        phase.text = "PHASE 1"
        phase.fontSize = 22
        phase.fontColor = .yellow
        phase.horizontalAlignmentMode = .center
        phase.verticalAlignmentMode = .center
        phase.position = CGPoint(x: 0, y: yTop - 26)
        phase.zPosition = 502
        
        let phaseBg = SKShapeNode(rectOf: CGSize(width: 160, height: 34), cornerRadius: 10)
        phaseBg.fillColor = SKColor(white: 0.0, alpha: 0.55)
        phaseBg.strokeColor = SKColor(white: 1.0, alpha: 0.18)
        phaseBg.lineWidth = 2
        phaseBg.position = phase.position
        phaseBg.zPosition = 501
        hudNode.addChild(phaseBg)

        hudNode.addChild(bg)
        hudNode.addChild(fill)
        hudNode.addChild(name)
        hudNode.addChild(phase)

        bossHealthBarBg = bg
        bossHealthBarFill = fill
        bossHealthLabel = name
        bossPhaseLabel = phase

        updateBossHUD()
    }

    func updateBossHUD() {
        guard let b = boss,
              let hp = b.userData?["bossHP"] as? Int,
              let maxHP = b.userData?["bossMaxHP"] as? Int,
              let fill = bossHealthBarFill
        else { return }

        let pct = max(0, min(1, CGFloat(hp) / CGFloat(maxHP)))

        let barWidth: CGFloat = 360
        let barHeight: CGFloat = 18
        let yTop: CGFloat = (size.height / 2) - 70
        let xLeft: CGFloat = -barWidth / 2

        fill.path = CGPath(
            roundedRect: CGRect(x: xLeft, y: yTop, width: barWidth * pct, height: barHeight),
            cornerWidth: 6,
            cornerHeight: 6,
            transform: nil
        )

        if let phaseLabel = bossPhaseLabel {
            switch bossPhase {
            case .phase1: phaseLabel.text = "PHASE 1"
            case .phase2: phaseLabel.text = "PHASE 2"
            case .phase3: phaseLabel.text = "PHASE 3"
            case .dead:   phaseLabel.text = "DEFEATED"
            }
        }
    }

    // MARK: Burst helper

    private func fireBossBurstIfNeeded(currentTime: TimeInterval, from b: SKSpriteNode, to target: CGPoint) {
        guard bossBurstShotsRemaining > 0 else { return }
        if currentTime < bossBurstNextShotTime { return }

        bossBurstShotsRemaining -= 1
        bossBurstNextShotTime = currentTime + 0.12

        bossFireSingle(from: b, to: target)
    }

    // MARK: Boss Damage (✅ schnell + sichtbar)

    func applyDamageToBoss(_ boss: SKSpriteNode, amount: Int) {
        if bossIsShieldActive { return }

        if boss.userData == nil { boss.userData = NSMutableDictionary() }

        let hp = (boss.userData?["bossHP"] as? Int) ?? bossTotalHP
        let newHP = max(0, hp - amount)
        boss.userData?["bossHP"] = newHP

        flashBossOnHit(boss)

        // ✅ Phase ggf. sofort wechseln
        updateBossPhaseIfNeeded()

        // ✅ HUD sofort aktualisieren
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

        bossHealthBarBg?.removeFromParent()
        bossHealthBarFill?.removeFromParent()
        bossHealthLabel?.removeFromParent()
        bossPhaseLabel?.removeFromParent()
        bossHealthBarBg = nil
        bossHealthBarFill = nil
        bossHealthLabel = nil
        bossPhaseLabel = nil

        SoundManager.shared.playRandomExplosion(in: self)
        //playEnemyShipExplosion(at: boss.position, zPosition: boss.zPosition)

        boss.removeAllActions()
        boss.physicsBody = nil
        boss.run(.sequence([.fadeOut(withDuration: 0.25), .removeFromParent()]))

        enemies.removeAll { $0 == boss }
        self.boss = nil

        isLevelCompleted = true

        // ✅ Banner anzeigen
        showBossLevelCompleteBanner()

        // ✅ erst nach kurzer Zeit zurück ins Menü
        run(.sequence([
            .wait(forDuration: 1.4),
            .run { [weak self] in
                self?.onLevelCompleted?()
            }
        ]))
    }

    // MARK: Shield Visual

    private func applyBossShield(on boss: SKSpriteNode) {
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
        bossShieldNode?.removeAllActions()
        bossShieldNode?.removeFromParent()
        bossShieldNode = nil
    }

    /// ✅ wird aus GameScene.didSimulatePhysics() aufgerufen
    func bossFollowShieldIfNeeded() {
        if let b = boss, let shield = bossShieldNode {
            shield.position = b.position
        }
    }

    // MARK: Shots

    private func bossFireSingle(from boss: SKSpriteNode, to target: CGPoint) {
        spawnBossBullet(from: boss.position, to: target, speed: 520)
    }

    private func bossFireShotgun(from boss: SKSpriteNode, to target: CGPoint, pelletCount: Int, spread: CGFloat) {
        let baseAngle = atan2(target.y - boss.position.y, target.x - boss.position.x)

        for i in 0..<pelletCount {
            let t = pelletCount <= 1 ? 0 : CGFloat(i) / CGFloat(pelletCount - 1)
            let offset = (t - 0.5) * spread
            let ang = baseAngle + offset

            let dir = CGPoint(x: cos(ang), y: sin(ang))
            let far = CGPoint(x: boss.position.x + dir.x * 1000,
                              y: boss.position.y + dir.y * 1000)

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

    // MARK: Minions

    private func spawnBossMinions(count: Int) {
        guard let lvl = levelNode else { return }

        for _ in 0..<count {
            let x = CGFloat.random(in: (lvl.frame.midX - 300)...(lvl.frame.midX + 300))
            let y = CGFloat.random(in: (lvl.frame.midY)...(lvl.frame.maxY - 220))
            let pos = CGPoint(x: x, y: y)

            // Wenn du schon eine EnemyShip-Spawn Funktion hast -> hier aufrufen:
            // spawnEnemyShip(at: pos)
            _ = pos
        }
    }
    
    // ✅ Boss-Level Complete Banner (wie Level 1)
    func showBossLevelCompleteBanner() {
        // Falls schon da → entfernen
        hudNode.childNode(withName: "bossLevelCompleteBanner")?.removeFromParent()

        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.name = "bossLevelCompleteBanner"
        label.text = "LEVEL COMPLETE"
        label.fontSize = 46
        label.fontColor = .yellow
        label.zPosition = 9999
        label.alpha = 0.0
        label.position = CGPoint(x: 0, y: 0) // Mitte vom Screen (HUD ist an Kamera)

        // Optional: kleine dunkle Box dahinter, damit es IMMER lesbar ist
        let padW: CGFloat = 520
        let padH: CGFloat = 90
        let bg = SKShapeNode(rectOf: CGSize(width: padW, height: padH), cornerRadius: 18)
        bg.fillColor = SKColor(white: 0.0, alpha: 0.55)
        bg.strokeColor = SKColor(white: 1.0, alpha: 0.20)
        bg.lineWidth = 2
        bg.zPosition = label.zPosition - 1
        bg.alpha = 0.0
        bg.position = label.position

        hudNode.addChild(bg)
        hudNode.addChild(label)

        let fadeIn  = SKAction.fadeAlpha(to: 1.0, duration: 0.18)
        let hold    = SKAction.wait(forDuration: 1.2)
        let fadeOut = SKAction.fadeAlpha(to: 0.0, duration: 0.25)

        label.run(.sequence([fadeIn, hold, fadeOut, .removeFromParent()]))
        bg.run(.sequence([fadeIn, hold, fadeOut, .removeFromParent()]))
    }
}
