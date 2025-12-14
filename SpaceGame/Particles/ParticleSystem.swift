//
//  ParticleSystem.swift
//  SpaceGame
//
//  Manages continuous / high-frequency particle effects:
//  - Player thruster
//  - Enemy thrusters
//  - Asteroid dust trail
//

import SpriteKit

final class ParticleSystem {

    // MARK: - Public tuning

    struct Config {
        // spawn limits (seconds)
        var playerThrusterInterval: TimeInterval = 0.03
        var enemyThrusterInterval: TimeInterval  = 0.045
        var asteroidDustInterval: TimeInterval   = 0.08

        // enable flags (useful for debugging / performance testing)
        var enablePlayerThruster: Bool = true
        var enableEnemyThrusters: Bool = true
        var enableAsteroidDust: Bool   = true
    }

    var config = Config()

    // MARK: - Internal state (rate limiting)

    private var lastPlayerThrusterTime: TimeInterval = 0
    private var lastEnemyThrusterTime: TimeInterval = 0
    private var lastAsteroidDustTime: TimeInterval = 0

    // MARK: - Lifecycle

    func reset() {
        lastPlayerThrusterTime = 0
        lastEnemyThrusterTime = 0
        lastAsteroidDustTime = 0
    }

    // MARK: - Update entry point

    /// Call once per frame from GameScene.update(...)
    func update(in scene: SKScene,
                currentTime: TimeInterval,
                player: SKSpriteNode?,
                enemyShips: [SKSpriteNode],
                enemies: [SKSpriteNode],
                boss: SKSpriteNode?) {

        if config.enablePlayerThruster {
            spawnPlayerThrusterIfNeeded(in: scene, currentTime: currentTime, ship: player)
        }

        if config.enableEnemyThrusters {
            spawnEnemyThrustersIfNeeded(in: scene, currentTime: currentTime, enemyShips: enemyShips)
        }

        if config.enableAsteroidDust {
            spawnAsteroidDustIfNeeded(in: scene,
                                      currentTime: currentTime,
                                      enemies: enemies,
                                      enemyShips: enemyShips,
                                      boss: boss)
        }
    }

    // MARK: - Player Thruster

    private func spawnPlayerThrusterIfNeeded(in scene: SKScene,
                                             currentTime: TimeInterval,
                                             ship: SKSpriteNode?) {
        guard let ship else { return }
        guard currentTime - lastPlayerThrusterTime >= config.playerThrusterInterval else { return }
        lastPlayerThrusterTime = currentTime

        let angle = ship.zRotation

        // In deiner Movement-Logik ist forward = (-sin, cos), daher: forwardAngle = angle + π/2
        let forwardAngle = angle + .pi / 2
        let backAngle    = forwardAngle + .pi

        // base position behind ship
        let distanceBehind: CGFloat = ship.size.height * 0.6
        let basePos = CGPoint(
            x: ship.position.x + cos(backAngle) * distanceBehind,
            y: ship.position.y + sin(backAngle) * distanceBehind
        )

        // 1) glowing core
        let coreRadius = ship.size.width * 0.11
        let core = SKShapeNode(circleOfRadius: coreRadius)
        core.position = basePos
        core.zPosition = ship.zPosition - 1
        core.fillColor = .white
        core.strokeColor = .clear
        core.glowWidth = coreRadius * 1.6
        core.lineWidth = 0
        core.alpha = 0.95
        core.blendMode = .add
        scene.addChild(core)

        let coreDuration: TimeInterval = 0.18
        let coreMove = SKAction.moveBy(
            x: cos(backAngle) * ship.size.height * 0.25,
            y: sin(backAngle) * ship.size.height * 0.25,
            duration: coreDuration
        )
        let coreFade  = SKAction.fadeOut(withDuration: coreDuration)
        let coreScale = SKAction.scale(to: 0.25, duration: coreDuration)
        core.run(.sequence([.group([coreMove, coreFade, coreScale]), .removeFromParent()]))

        // 2) streak sparks
        let sparkCount = 3
        for _ in 0..<sparkCount {
            let length = ship.size.width * CGFloat.random(in: 0.24...0.34)
            let thickness = length * 0.22

            let spark = SKSpriteNode(color: .white, size: CGSize(width: length, height: thickness))
            spark.position = basePos
            spark.zPosition = ship.zPosition - 1
            spark.alpha = 0.95
            spark.blendMode = .add
            spark.anchorPoint = CGPoint(x: 0.0, y: 0.5)

            let jitter = CGFloat.random(in: -(.pi/10)...(.pi/10))
            let dirAngle = backAngle + jitter
            spark.zRotation = dirAngle

            let distance = ship.size.height * CGFloat.random(in: 0.35...0.7)
            let dx = cos(dirAngle) * distance
            let dy = sin(dirAngle) * distance

            let duration: TimeInterval = 0.2
            let move  = SKAction.moveBy(x: dx, y: dy, duration: duration)
            let fade  = SKAction.fadeOut(withDuration: duration)
            let scale = SKAction.scaleX(to: 0.25, duration: duration)

            spark.run(.sequence([.group([move, fade, scale]), .removeFromParent()]))
            scene.addChild(spark)
        }
    }

    // MARK: - Enemy Thrusters

    private func spawnEnemyThrustersIfNeeded(in scene: SKScene,
                                            currentTime: TimeInterval,
                                            enemyShips: [SKSpriteNode]) {
        guard currentTime - lastEnemyThrusterTime >= config.enemyThrusterInterval else { return }
        lastEnemyThrusterTime = currentTime

        for enemy in enemyShips {
            let angle = enemy.zRotation
            let forwardAngle = angle + .pi / 2
            let backAngle    = forwardAngle + .pi

            let distanceBehind: CGFloat = enemy.size.height * 0.6
            let basePos = CGPoint(
                x: enemy.position.x + cos(backAngle) * distanceBehind,
                y: enemy.position.y + sin(backAngle) * distanceBehind
            )

            // 1) smaller core
            let coreRadius = enemy.size.width * 0.09
            let core = SKShapeNode(circleOfRadius: coreRadius)
            core.position = basePos
            core.zPosition = enemy.zPosition - 1
            core.fillColor = .white
            core.strokeColor = .clear
            core.glowWidth = coreRadius * 1.4
            core.lineWidth = 0
            core.alpha = 0.85
            core.blendMode = .add
            scene.addChild(core)

            let coreDuration: TimeInterval = 0.16
            let coreMove = SKAction.moveBy(
                x: cos(backAngle) * enemy.size.height * 0.22,
                y: sin(backAngle) * enemy.size.height * 0.22,
                duration: coreDuration
            )
            let coreFade  = SKAction.fadeOut(withDuration: coreDuration)
            let coreScale = SKAction.scale(to: 0.25, duration: coreDuration)
            core.run(.sequence([.group([coreMove, coreFade, coreScale]), .removeFromParent()]))

            // 2) streak sparks
            let sparkCount = 2
            for _ in 0..<sparkCount {
                let length = enemy.size.width * CGFloat.random(in: 0.20...0.30)
                let thickness = length * 0.22

                let spark = SKSpriteNode(color: .white, size: CGSize(width: length, height: thickness))
                spark.position = basePos
                spark.zPosition = enemy.zPosition - 1
                spark.alpha = 0.9
                spark.blendMode = .add
                spark.anchorPoint = CGPoint(x: 0.0, y: 0.5)

                let jitter = CGFloat.random(in: -(.pi/12)...(.pi/12))
                let dirAngle = backAngle + jitter
                spark.zRotation = dirAngle

                let distance = enemy.size.height * CGFloat.random(in: 0.3...0.55)
                let dx = cos(dirAngle) * distance
                let dy = sin(dirAngle) * distance

                let duration: TimeInterval = 0.18
                let move  = SKAction.moveBy(x: dx, y: dy, duration: duration)
                let fade  = SKAction.fadeOut(withDuration: duration)
                let scale = SKAction.scaleX(to: 0.25, duration: duration)

                spark.run(.sequence([.group([move, fade, scale]), .removeFromParent()]))
                scene.addChild(spark)
            }
        }
    }

    // MARK: - Asteroid Dust

    private func spawnAsteroidDustIfNeeded(in scene: SKScene,
                                          currentTime: TimeInterval,
                                          enemies: [SKSpriteNode],
                                          enemyShips: [SKSpriteNode],
                                          boss: SKSpriteNode?) {

        guard currentTime - lastAsteroidDustTime >= config.asteroidDustInterval else { return }
        lastAsteroidDustTime = currentTime

        for asteroid in enemies where !enemyShips.contains(asteroid) && asteroid != boss {

            let jitterX = CGFloat.random(in: -asteroid.size.width * 0.4 ... asteroid.size.width * 0.4)
            let jitterY = CGFloat.random(in: -asteroid.size.height * 0.4 ... asteroid.size.height * 0.4)

            let radius = asteroid.size.width * CGFloat.random(in: 0.03...0.08)

            // warm rock colors
            let baseR: CGFloat = 0.60
            let baseG: CGFloat = 0.45
            let baseB: CGFloat = 0.25
            let colorJitter: CGFloat = 0.06

            let r = max(0, min(1, baseR + CGFloat.random(in: -colorJitter...colorJitter)))
            let g = max(0, min(1, baseG + CGFloat.random(in: -colorJitter...colorJitter)))
            let b = max(0, min(1, baseB + CGFloat.random(in: -colorJitter...colorJitter)))

            let chunk = SKShapeNode(circleOfRadius: radius)
            chunk.position = CGPoint(x: asteroid.position.x + jitterX, y: asteroid.position.y + jitterY)
            chunk.zPosition = asteroid.zPosition - 1
            chunk.fillColor = SKColor(red: r, green: g, blue: b, alpha: 1.0)
            chunk.strokeColor = .clear
            chunk.glowWidth = 0
            chunk.alpha = 0.95
            chunk.lineWidth = 0
            chunk.blendMode = .alpha

            scene.addChild(chunk)

            // drift down slightly and fade
            let driftY: CGFloat = -asteroid.size.height * 0.3
            let driftX: CGFloat = CGFloat.random(in: -asteroid.size.width * 0.05 ... asteroid.size.width * 0.05)

            let duration: TimeInterval = 0.6
            let move  = SKAction.moveBy(x: driftX, y: driftY, duration: duration)
            let fade  = SKAction.fadeOut(withDuration: duration)
            let scale = SKAction.scale(to: 0.3, duration: duration)

            chunk.run(.sequence([.group([move, fade, scale]), .removeFromParent()]))
        }
    }
}
