//
//  VFXSystem+SpriteSheets.swift
//  SpaceGame
//
//  Created by Alexander Wagner on 14.12.25.
//

import SpriteKit

// MARK: - SpriteSheets (Explosions / Destruction)

extension VFXSystem {

    // MARK: - Sparks (Explosion)

    func spawnExplosionSparks(at position: CGPoint,
                             baseColor: SKColor = .yellow,
                             count: Int = 20,
                             zPos: CGFloat = 50) {

        guard budget.allow(count) else { return }

        for _ in 0..<count {
            let length = CGFloat.random(in: tuning.explosionSparkLength)
            let thickness = CGFloat.random(in: tuning.explosionSparkThickness)

            let spark = pool.makeSpark(color: baseColor)
            spark.size = CGSize(width: length, height: thickness)
            spark.position = position
            spark.zPosition = zPos
            spark.alpha = 1.0

            let angle = CGFloat.random(in: 0 ..< (.pi * 2))
            spark.zRotation = angle

            let distance = CGFloat.random(in: tuning.explosionSparkDistance)
            let dx = cos(angle) * distance
            let dy = sin(angle) * distance
            let duration = tuning.explosionSparkDuration

            layer.addChild(spark)

            let move = SKAction.moveBy(x: dx, y: dy, duration: duration)
            let fade = SKAction.fadeOut(withDuration: duration)
            let scale = SKAction.scaleX(to: 0.2, duration: duration)

            let recycle = SKAction.run { [weak self, weak spark] in
                guard let self, let spark = spark else { return }
                self.pool.recycleSpark(spark)
            }

            spark.run(.sequence([.group([move, fade, scale]), recycle]))
        }
    }

    // MARK: - Enemy Ship Explosion

    /// Enemy ship explosion: 2x3 sprite sheet "ExplosionEnemyShip"
    func playEnemyShipExplosion(at position: CGPoint,
                               zPosition: CGFloat,
                               desiredWidth: CGFloat,
                               sparkColor: SKColor = .cyan,
                               sparkCount: Int = 24) {

        let frames = enemyExplosionFrames()
        guard !frames.isEmpty else { return }

        let sheet = SKTexture(imageNamed: "ExplosionEnemyShip")
        let cols = 3
        let frameWidth = sheet.size().width / CGFloat(cols)
        let scale = desiredWidth / frameWidth

        let explosion = SKSpriteNode(texture: frames.first)
        explosion.setScale(scale)
        explosion.position = position
        explosion.zPosition = zPosition + 1
        explosion.alpha = 1.0
        explosion.blendMode = .add
        layer.addChild(explosion)

        triggerExplosionShockwave(at: position)

        let animate = SKAction.animate(with: frames, timePerFrame: tuning.sheetTimePerFrame)
        let fadeOut = SKAction.fadeOut(withDuration: tuning.sheetFadeOutDuration)
        explosion.run(.sequence([.group([animate, fadeOut]), .removeFromParent()]))

        spawnExplosionSparks(at: position, baseColor: sparkColor, count: sparkCount, zPos: 60)
    }

    // MARK: - Asteroid Destruction

    /// Asteroid destruction: 3x2 sprite sheet "AstroidDestroyed"
    /// Keeps drift using the passed-in velocity (capture it before physicsBody gets removed).
    func playAsteroidDestruction(on asteroid: SKSpriteNode,
                                savedVelocity: CGVector,
                                sparkColor: SKColor = SKColor(red: 0.7, green: 0.5, blue: 0.3, alpha: 1.0),
                                sparkCount: Int = 18) {

        let frames = asteroidDestroyFrames()
        guard !frames.isEmpty else {
            asteroid.run(.sequence([.fadeOut(withDuration: 0.15), .removeFromParent()]))
            return
        }

        asteroid.physicsBody = nil
        asteroid.removeAllActions()

        let animate = SKAction.animate(with: frames, timePerFrame: tuning.sheetTimePerFrame)
        let fadeOut = SKAction.fadeOut(withDuration: tuning.sheetFadeOutDuration)

        let driftDuration = tuning.asteroidDriftDuration
        let drift = SKAction.moveBy(
            x: savedVelocity.dx * driftDuration,
            y: savedVelocity.dy * driftDuration,
            duration: driftDuration
        )

        asteroid.run(.sequence([.group([animate, fadeOut, drift]), .removeFromParent()]))

        spawnExplosionSparks(
            at: asteroid.position,
            baseColor: sparkColor,
            count: sparkCount,
            zPos: asteroid.zPosition + 1
        )
    }

    // MARK: - Frame Cache

    private func enemyExplosionFrames() -> [SKTexture] {
        if let cached = cachedEnemyExplosionFrames { return cached }

        let sheet = SKTexture(imageNamed: "ExplosionEnemyShip")
        guard sheet.size() != .zero else {
            cachedEnemyExplosionFrames = []
            return []
        }

        let frames = makeFrames(from: sheet, rows: 2, cols: 3)
        cachedEnemyExplosionFrames = frames
        return frames
    }

    private func asteroidDestroyFrames() -> [SKTexture] {
        if let cached = cachedAsteroidDestroyFrames { return cached }

        let sheet = SKTexture(imageNamed: "AstroidDestroyed")
        guard sheet.size() != .zero else {
            cachedAsteroidDestroyFrames = []
            return []
        }

        let frames = makeFrames(from: sheet, rows: 3, cols: 2)
        cachedAsteroidDestroyFrames = frames
        return frames
    }
}
