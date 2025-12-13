//
//  Shooting.swift
//  SpaceGame
//

import SpriteKit

extension GameScene {

    // MARK: - Öffentlich: vom Input aufgerufen

    /// Schießt ein Projektil (oder bei Triple-Shot 3) mit fetten Effekten
    func shoot() {
        guard playerShip != nil else { return }

        // ✅ SFX fix (passend zu SoundManager.playSFX)
        SoundManager.shared.playSFX(Sound.playerShot, in: self)

        if isTripleShotActive {
            // Mitte, links, rechts (seitlich versetzt)
            spawnPlayerBullet(sideOffset: 0)
            spawnPlayerBullet(sideOffset: 20)
            spawnPlayerBullet(sideOffset: -20)
        } else {
            // Nur ein Schuss in der Mitte
            spawnPlayerBullet(sideOffset: 0)
        }
    }

    // MARK: - Hilfsfunktion: einzelnes Projektil erzeugen

    /// sideOffset: Verschiebung quer zur Blickrichtung des Schiffs (in Punkten)
    private func spawnPlayerBullet(sideOffset: CGFloat) {
        guard let ship = playerShip else { return }

        let angle = ship.zRotation

        // Vorwärts-Richtung des Schiffs (lokales +Y)
        let dirX = -sin(angle)
        let dirY =  cos(angle)

        // "Rechts"-Vektor (Querachse)
        let rightX = cos(angle)
        let rightY = sin(angle)

        // Bullet-Node (Sprite + Physik + Visuals)
        let bullet = createPlayerBulletNode()

        // Startposition: etwas vor dem Schiff plus seitliche Verschiebung.
        // Da anchorPoint = (0, 0.5) ist, liegt die "Rückseite" an der Mündung.
        let forwardOffset: CGFloat = ship.size.height / 2 + 10

        let baseX = ship.position.x + dirX * forwardOffset
        let baseY = ship.position.y + dirY * forwardOffset

        let sideX = rightX * sideOffset
        let sideY = rightY * sideOffset

        let startPos = CGPoint(x: baseX + sideX, y: baseY + sideY)

        bullet.position  = startPos
        bullet.zRotation = angle
        bullet.zPosition = ship.zPosition + 1

        // 💥 Energy-Bolt: kleiner Scale-Pop beim Spawn
        bullet.setScale(0.6)
        let pop = SKAction.scale(to: 1.0, duration: 0.06)
        pop.timingMode = .easeOut
        bullet.run(pop)

        addChild(bullet)

        // 💥 Mündungs-Flash an der Kanone (blau)
        let forwardAngle = atan2(dirY, dirX)
        spawnMuzzleFlash(at: startPos,
                         directionAngle: forwardAngle,
                         zPos: bullet.zPosition + 1)

        // 💨 Ghost-Trail hinter dem Projektil (bläulich)
        let playerGhostColor = SKColor(red: 0.55, green: 0.9, blue: 1.0, alpha: 1.0)
        attachGhostTrail(to: bullet, color: playerGhostColor)

        // Geschwindigkeit
        let bulletSpeed: CGFloat = 700
        let vx = dirX * bulletSpeed
        let vy = dirY * bulletSpeed
        bullet.physicsBody?.velocity = CGVector(dx: vx, dy: vy)

        // Lebensdauer
        bullet.run(.sequence([
            .wait(forDuration: 2.0),
            .removeFromParent()
        ]))
    }

    // MARK: - Player Bullet Look (Blue Energy-Bolt)

    /// Erzeugt ein einzelnes Projektil mit Capsule-Look + Glow + Trail
    private func createPlayerBulletNode() -> SKSpriteNode {
        // Größe relativ zum Schiff
        let shipSize = playerShip?.size ?? CGSize(width: size.width * 0.1,
                                                  height: size.height * 0.1)

        // Länglich, damit es wie ein Laser-Bolt wirkt
        let width  = shipSize.width * 0.22
        let height = shipSize.height * 0.45

        // Basis-Sprite nur für Physik – VISUELL unsichtbar
        let bullet = SKSpriteNode(
            color: .clear,
            size: CGSize(width: width, height: height)
        )

        bullet.alpha = 1.0
        bullet.blendMode = .add
        bullet.anchorPoint = CGPoint(x: 0.0, y: 0.5) // hinteres Ende = Spawnpunkt

        // Physik
        let body = SKPhysicsBody(rectangleOf: bullet.size)
        body.isDynamic = true
        body.affectedByGravity = false
        body.allowsRotation = false
        body.usesPreciseCollisionDetection = true

        body.categoryBitMask = PhysicsCategory.bullet
        body.collisionBitMask = 0
        body.contactTestBitMask = PhysicsCategory.enemy

        bullet.physicsBody = body

        // --- VISUELLE CAPSULE: innerer Kern + äußerer Glow ---

        let coreSize = CGSize(width: width * 0.55, height: height * 0.85)

        // heller, leicht bläulicher Kern
        let core = SKShapeNode(rectOf: coreSize, cornerRadius: coreSize.width / 2)
        core.fillColor = SKColor(red: 0.8, green: 0.95, blue: 1.0, alpha: 1.0)
        core.strokeColor = .clear
        core.glowWidth = coreSize.height * 0.9
        core.alpha = 0.95
        core.zPosition = 0
        core.blendMode = .add
        bullet.addChild(core)

        // 🔵 kräftiger blauer Outer-Glow
        let outer = SKShapeNode(rectOf: coreSize, cornerRadius: coreSize.width / 2)
        outer.fillColor = SKColor(red: 0.2, green: 0.6, blue: 1.0, alpha: 1.0)
        outer.strokeColor = .clear
        outer.glowWidth = coreSize.height * 1.3
        outer.alpha = 0.9
        outer.zPosition = -0.5
        outer.blendMode = .add
        bullet.addChild(outer)

        // 💨 weicher „Dunst“-Trail (Emitter, blau/cyan)
        let trail = createBulletTrail(bulletLength: height)
        trail.targetNode = self
        bullet.addChild(trail)

        // 🔷 schnelle Funken hinter dem Bolt (blau/cyan)
        let sparks = createBulletSparks(bulletLength: height)
        sparks.targetNode = self
        bullet.addChild(sparks)

        return bullet
    }

    /// Weicher Neon-Trail hinter dem Projektil (Partikel-Hauch)
    private func createBulletTrail(bulletLength: CGFloat) -> SKEmitterNode {
        let emitter = SKEmitterNode()

        emitter.particleTexture = nil
        emitter.particleBirthRate = 140
        emitter.particleLifetime = 0.30
        emitter.particleLifetimeRange = 0.08

        emitter.particleSpeed = 0
        emitter.particleSpeedRange = 25

        emitter.emissionAngleRange = .pi        // rund ums Projektil
        emitter.particleAlpha = 0.8
        emitter.particleAlphaRange = 0.2
        emitter.particleAlphaSpeed = -2.5

        emitter.particleScale = 0.23
        emitter.particleScaleRange = 0.12
        emitter.particleScaleSpeed = -0.4

        // blau/cyan
        emitter.particleColor = SKColor(red: 0.3, green: 0.7, blue: 1.0, alpha: 1.0)
        emitter.particleColorBlendFactor = 1.0
        emitter.particleBlendMode = .add

        // sitzt hinter der Mitte des Projektils (lokales -Y)
        emitter.position = CGPoint(x: 0, y: -bulletLength * 0.4)
        emitter.zPosition = -1

        return emitter
    }

    /// Schnelle blaue Funken, die nach hinten wegfliegen
    private func createBulletSparks(bulletLength: CGFloat) -> SKEmitterNode {
        let emitter = SKEmitterNode()

        emitter.particleTexture = nil
        emitter.particleBirthRate = 40
        emitter.particleLifetime = 0.25
        emitter.particleLifetimeRange = 0.1

        // fliegen nach hinten weg (lokal -Y)
        emitter.emissionAngle = -.pi / 2
        emitter.emissionAngleRange = .pi / 6

        emitter.particleSpeed = 260
        emitter.particleSpeedRange = 60

        emitter.particleAlpha = 0.95
        emitter.particleAlphaRange = 0.1
        emitter.particleAlphaSpeed = -3.5

        emitter.particleScale = 0.22
        emitter.particleScaleRange = 0.1
        emitter.particleScaleSpeed = -0.6

        emitter.particleColor = SKColor(red: 0.4, green: 0.8, blue: 1.0, alpha: 1.0)
        emitter.particleColorBlendFactor = 1.0
        emitter.particleBlendMode = .add

        // leicht hinter der "Spitze"
        emitter.position = CGPoint(x: 0, y: -bulletLength * 0.2)
        emitter.zPosition = 0

        return emitter
    }

    // MARK: - Ghost-Trail (glühende Dots, ohne Emitter)

    /// Hängt ein Ghost-Trail-Action an ein Projektil (Farbe je nach Schütze)
    private func attachGhostTrail(to bullet: SKSpriteNode, color: SKColor) {
        let spawnInterval: TimeInterval = 0.028

        let spawnGhost = SKAction.run { [weak self, weak bullet] in
            guard let self = self, let bullet = bullet else { return }

            let angle = bullet.zRotation
            let dist  = bullet.size.height * 0.4

            // hinter dem Projektil (lokales -Y)
            let backX = sin(angle) * dist
            let backY = -cos(angle) * dist

            let pos = CGPoint(
                x: bullet.position.x + backX,
                y: bullet.position.y + backY
            )

            let radius = bullet.size.width * 0.18
            let dot = SKShapeNode(circleOfRadius: radius)
            dot.position = pos
            dot.zPosition = bullet.zPosition - 1
            dot.fillColor = color
            dot.strokeColor = .clear
            dot.glowWidth = radius * 1.5
            dot.alpha = 0.6
            dot.blendMode = .add

            self.addChild(dot)

            let dur: TimeInterval = 0.16
            let fade  = SKAction.fadeOut(withDuration: dur)
            let scale = SKAction.scale(to: 0.2, duration: dur)
            let group = SKAction.group([fade, scale])
            dot.run(.sequence([group, .removeFromParent()]))
        }

        let seq = SKAction.sequence([
            .wait(forDuration: spawnInterval),
            spawnGhost
        ])

        bullet.run(.repeatForever(seq), withKey: "ghostTrail")
    }

    // MARK: - Muzzle-Flash (Kanonen-Flash am Schiff)

    /// Kurzer, heftiger Flash an der Mündung
    private func spawnMuzzleFlash(at position: CGPoint,
                                  directionAngle: CGFloat,
                                  zPos: CGFloat) {

        // 1) Runder Kern (weiß + blauer Glow)
        let radius: CGFloat = 14

        let core = SKShapeNode(circleOfRadius: radius)
        core.position = position
        core.zPosition = zPos
        core.fillColor = .white
        core.strokeColor = .clear
        core.glowWidth = radius * 2.0
        core.alpha = 0.95
        core.blendMode = .add
        addChild(core)

        let coreDuration: TimeInterval = 0.06
        let coreFade  = SKAction.fadeOut(withDuration: coreDuration)
        let coreScale = SKAction.scale(to: 0.4, duration: coreDuration)
        let coreGroup = SKAction.group([coreFade, coreScale])
        core.run(.sequence([coreGroup, .removeFromParent()]))

        // 2) Kurzer Strahl nach vorne (blau)
        let beamLength: CGFloat = 36
        let beamThickness: CGFloat = 10

        let beam = SKSpriteNode(
            color: SKColor(red: 0.3, green: 0.7, blue: 1.0, alpha: 1.0),
            size: CGSize(width: beamLength, height: beamThickness)
        )

        beam.position = position
        beam.zPosition = zPos
        beam.alpha = 0.9
        beam.blendMode = .add
        beam.anchorPoint = CGPoint(x: 0.0, y: 0.5)
        beam.zRotation = directionAngle

        addChild(beam)

        let beamDuration: TimeInterval = 0.07
        let beamFade  = SKAction.fadeOut(withDuration: beamDuration)
        let beamScale = SKAction.scaleX(to: 0.2, duration: beamDuration)
        let beamGroup = SKAction.group([beamFade, beamScale])
        beam.run(.sequence([beamGroup, .removeFromParent()]))

        // 3) Kleine Muzzle-Funken (blau)
        let sparkCount = 4
        for _ in 0..<sparkCount {
            let sLength: CGFloat = CGFloat.random(in: 10...18)
            let sThickness: CGFloat = 3

            let spark = SKSpriteNode(
                color: SKColor(red: 0.5, green: 0.8, blue: 1.0, alpha: 1.0),
                size: CGSize(width: sLength, height: sThickness)
            )

            spark.position = position
            spark.zPosition = zPos
            spark.alpha = 0.95
            spark.blendMode = .add
            spark.anchorPoint = CGPoint(x: 0.0, y: 0.5)

            let jitter = CGFloat.random(in: -(.pi/6)...(.pi/6))
            let a = directionAngle + jitter
            spark.zRotation = a

            let dist: CGFloat = CGFloat.random(in: 18...36)
            let dx = cos(a) * dist
            let dy = sin(a) * dist

            let dur: TimeInterval = 0.09
            let move  = SKAction.moveBy(x: dx, y: dy, duration: dur)
            let fade  = SKAction.fadeOut(withDuration: dur)
            let scale = SKAction.scaleX(to: 0.2, duration: dur)
            let group = SKAction.group([move, fade, scale])

            spark.run(.sequence([group, .removeFromParent()]))
            addChild(spark)
        }
    }

    // MARK: - Schießen der Gegner (rote Bolts)

    func enemyShoot(from enemy: SKSpriteNode, towards target: CGPoint) {

        // ✅ SFX fix (passend zu SoundManager.playSFX)
        SoundManager.shared.playSFX(Sound.enemyShot, in: self)

        let dx = target.x - enemy.position.x
        let dy = target.y - enemy.position.y
        let distance = sqrt(dx*dx + dy*dy)
        guard distance > 0.1 else { return }

        let dirX = dx / distance
        let dirY = dy / distance

        let bulletSize = CGSize(width: 14, height: 24)

        // Basis-Sprite unsichtbar, Visuals als Kinder
        let bullet = SKSpriteNode(color: .clear, size: bulletSize)
        bullet.anchorPoint = CGPoint(x: 0.0, y: 0.5)
        bullet.blendMode = .add
        bullet.alpha = 1.0

        // Rot/Orange-Capsule
        let coreSize = CGSize(width: bulletSize.width * 0.6,
                              height: bulletSize.height * 0.9)

        let core = SKShapeNode(rectOf: coreSize, cornerRadius: coreSize.width / 2)
        core.fillColor = SKColor(red: 1.0, green: 0.85, blue: 0.7, alpha: 1.0)
        core.strokeColor = .clear
        core.glowWidth = coreSize.height * 1.0
        core.alpha = 0.95
        core.zPosition = 0
        core.blendMode = .add
        bullet.addChild(core)

        let outer = SKShapeNode(rectOf: coreSize, cornerRadius: coreSize.width / 2)
        outer.fillColor = SKColor(red: 1.0, green: 0.25, blue: 0.15, alpha: 1.0)
        outer.strokeColor = .clear
        outer.glowWidth = coreSize.height * 1.4
        outer.alpha = 0.9
        outer.zPosition = -0.5
        outer.blendMode = .add
        bullet.addChild(outer)

        let offset: CGFloat = max(enemy.size.width, enemy.size.height) / 2 + 10

        let startX = enemy.position.x + dirX * offset
        let startY = enemy.position.y + dirY * offset

        bullet.position = CGPoint(x: startX, y: startY)
        bullet.zPosition = enemy.zPosition + 1

        // zRotation so, dass lokale +Y in Schussrichtung zeigt
        bullet.zRotation = atan2(dirY, dirX) - .pi / 2

        // kleiner Scale-Pop
        bullet.setScale(0.7)
        let pop = SKAction.scale(to: 1.0, duration: 0.06)
        pop.timingMode = .easeOut
        bullet.run(pop)

        let body = SKPhysicsBody(rectangleOf: bulletSize)
        body.isDynamic = true
        body.affectedByGravity = false
        body.allowsRotation = false
        body.usesPreciseCollisionDetection = true

        body.categoryBitMask = PhysicsCategory.enemyBullet
        body.collisionBitMask = 0
        body.contactTestBitMask = PhysicsCategory.player

        bullet.physicsBody = body
        addChild(bullet)

        let bulletSpeed: CGFloat = 250
        let vx = dirX * bulletSpeed
        let vy = dirY * bulletSpeed
        bullet.physicsBody?.velocity = CGVector(dx: vx, dy: vy)

        // 🔴 kleiner Ghost-Trail auch für Enemy-Shots (orange/rot)
        let enemyGhostColor = SKColor(red: 1.0, green: 0.6, blue: 0.3, alpha: 1.0)
        attachGhostTrail(to: bullet, color: enemyGhostColor)

        bullet.run(.sequence([
            .wait(forDuration: 3.0),
            .removeFromParent()
        ]))
    }

    func handleEnemyShooting(currentTime: TimeInterval) {
        guard let playerShip = playerShip else { return }

        for enemy in enemyShips {

            // userData sicherstellen
            if enemy.userData == nil {
                enemy.userData = NSMutableDictionary()
            }

            // 1) Erster Start: jedem Gegner einen eigenen Offset geben (desync)
            if enemy.userData?["nextFireTime"] == nil {
                let initialOffset = TimeInterval.random(in: 0.0...enemyFireInterval)
                enemy.userData?["nextFireTime"] = currentTime + initialOffset
            }

            // 2) Prüfen ob dieser Gegner jetzt schießen darf
            let nextFire = (enemy.userData?["nextFireTime"] as? TimeInterval)
            ?? (currentTime + enemyFireInterval)

            if currentTime >= nextFire {

                // --- LOOK AT PLAYER (nur direkt vorm Schuss) ---
                let dx = playerShip.position.x - enemy.position.x
                let dy = playerShip.position.y - enemy.position.y
                let desiredZ = atan2(dy, dx) - .pi / 2

                enemy.removeAction(forKey: "aimRotate")
                let rotate = SKAction.rotate(toAngle: desiredZ, duration: 0.06, shortestUnitArc: true)
                enemy.run(rotate, withKey: "aimRotate")

                // Schießen
                enemyShoot(from: enemy, towards: playerShip.position)

                // 3) Nächstes Schießen planen + kleiner random jitter
                let jitter = TimeInterval.random(in: -0.25...0.35)
                let interval = max(0.35, enemyFireInterval + jitter)

                enemy.userData?["nextFireTime"] = currentTime + interval
            }
        }
    }
}
