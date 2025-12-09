//
//  Shooting.swift
//  SpaceGame
//

import SpriteKit

extension GameScene {

    // MARK: - Öffentlich: vom Input aufgerufen

    func shoot() {
        guard playerShip != nil else { return }

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

        // Vorwärts-Richtung des Schiffs
        let dirX = -sin(angle)
        let dirY =  cos(angle)

        // "Rechts"-Vektor (Querachse)
        let rightX = cos(angle)
        let rightY = sin(angle)

        // Bullet-Node (Sprite + Physik)
        let bullet = createPlayerBulletNode()

        // Startposition: etwas vor dem Schiff plus seitliche Verschiebung
        let bulletLength = max(bullet.size.width, bullet.size.height)
        let forwardOffset: CGFloat = ship.size.height / 2 + bulletLength / 2 + 10

        let baseX = ship.position.x + dirX * forwardOffset
        let baseY = ship.position.y + dirY * forwardOffset

        let sideX = rightX * sideOffset
        let sideY = rightY * sideOffset

        bullet.position = CGPoint(x: baseX + sideX, y: baseY + sideY)
        bullet.zRotation = angle
        bullet.zPosition = ship.zPosition + 1

        addChild(bullet)

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

    /// Erzeugt ein einzelnes Projektil mit Neon-Look + Glow + Funken
    private func createPlayerBulletNode() -> SKSpriteNode {
        // Größe relativ zum Schiff
        let shipSize = playerShip?.size ?? CGSize(width: size.width * 0.1,
                                                  height: size.height * 0.1)

        // 🔵 Kürzer & breiter, damit er „energiemäßig“ aussieht
        let width  = shipSize.width * 0.22
        let height = shipSize.height * 0.45   // kürzer als vorher

        let bullet = SKSpriteNode(
            color: .cyan,
            size: CGSize(width: width, height: height)
        )

        // Neon-Look
        bullet.color = .cyan
        bullet.colorBlendFactor = 1.0
        bullet.alpha = 0.95
        bullet.blendMode = .add   // ⭐ Additive Blend für Glow

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

        // 🌟 zusätzlicher Glow mit SKShapeNode (weicher Rand)
        let glow = SKShapeNode(rectOf: bullet.size, cornerRadius: width / 2)
        glow.fillColor = .cyan
        glow.strokeColor = .clear
        glow.glowWidth = width * 1.6
        glow.alpha = 0.6
        glow.zPosition = -1
        bullet.addChild(glow)

        // 💨 weicher „Dunst“-Trail
        let trail = createBulletTrail(bulletLength: height)
        trail.targetNode = self
        bullet.addChild(trail)

        // 🔷 einzelne schnelle Funken
        let sparks = createBulletSparks(bulletLength: height)
        sparks.targetNode = self
        bullet.addChild(sparks)

        return bullet
    }

    /// Weicher Neon-Trail hinter dem Projektil
    private func createBulletTrail(bulletLength: CGFloat) -> SKEmitterNode {
        let emitter = SKEmitterNode()

        emitter.particleTexture = nil
        emitter.particleBirthRate = 200
        emitter.particleLifetime = 0.35
        emitter.particleLifetimeRange = 0.1

        emitter.particleSpeed = 0
        emitter.particleSpeedRange = 30

        emitter.emissionAngleRange = .pi        // rund ums Projektil
        emitter.particleAlpha = 0.8
        emitter.particleAlphaRange = 0.2
        emitter.particleAlphaSpeed = -2.5

        emitter.particleScale = 0.23
        emitter.particleScaleRange = 0.12
        emitter.particleScaleSpeed = -0.4

        emitter.particleColor = .cyan
        emitter.particleColorBlendFactor = 1.0
        emitter.particleBlendMode = .add

        // sitzt hinter der Mitte des Projektils
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

        emitter.particleColor = .cyan
        emitter.particleColorBlendFactor = 1.0
        emitter.particleBlendMode = .add

        // leicht hinter der Spitze des Lasers
        emitter.position = CGPoint(x: 0, y: -bulletLength * 0.2)
        emitter.zPosition = 0

        return emitter
    }

    // MARK: - Schießen (Gegner bleibt wie gehabt)

    func enemyShoot(from enemy: SKSpriteNode, towards target: CGPoint) {
        let dx = target.x - enemy.position.x
        let dy = target.y - enemy.position.y
        let distance = sqrt(dx*dx + dy*dy)
        guard distance > 0.1 else { return }

        let dirX = dx / distance
        let dirY = dy / distance

        let bulletSize = CGSize(width: 12, height: 18)
        let bullet = SKSpriteNode(color: .red, size: bulletSize)
        bullet.blendMode = .add
        bullet.color = .red
        bullet.colorBlendFactor = 1.0

        let offset: CGFloat = max(enemy.size.width, enemy.size.height) / 2 + 10

        let startX = enemy.position.x + dirX * offset
        let startY = enemy.position.y + dirY * offset

        bullet.position = CGPoint(x: startX, y: startY)
        bullet.zPosition = enemy.zPosition + 1
        bullet.zRotation = atan2(dirY, dirX) - .pi / 2

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

        bullet.run(.sequence([
            .wait(forDuration: 3.0),
            .removeFromParent()
        ]))
    }

    func handleEnemyShooting(currentTime: TimeInterval) {
        guard let playerShip = playerShip else { return }

        if currentTime - lastEnemyFireTime < enemyFireInterval {
            return
        }
        lastEnemyFireTime = currentTime

        // alle verfolgenden Schiffe schießen
        for enemy in enemyShips {
            enemyShoot(from: enemy, towards: playerShip.position)
        }
    }
}
