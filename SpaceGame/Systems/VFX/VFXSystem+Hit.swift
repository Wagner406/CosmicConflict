//
//  VFXSystem+Hit.swift
//  SpaceGame
//
//  Created by Alexander Wagner on 14.12.25.
//

import SpriteKit

// MARK: - Hit (Flash + Hit Sparks)

extension VFXSystem {

    /// Typical bullet hit impact:
    /// - flash (on enemy)
    /// - small sparks
    func playHitImpact(on enemy: SKSpriteNode,
                       isShip: Bool,
                       at position: CGPoint,
                       zPos: CGFloat? = nil,
                       sparkCount: Int? = nil) {

        flashEnemy(enemy, isShip: isShip)

        let color: SKColor = isShip
            ? SKColor(red: 0.4, green: 0.9, blue: 1.0, alpha: 1.0)
            : SKColor(red: 1.0, green: 0.85, blue: 0.45, alpha: 1.0)

        spawnHitSparks(
            at: position,
            baseColor: color,
            count: sparkCount ?? (isShip ? 12 : 9),
            zPos: zPos ?? (enemy.zPosition + 2)
        )
    }

    func flashEnemy(_ enemy: SKSpriteNode, isShip: Bool) {
        let originalColor = enemy.color
        let originalBlend = enemy.colorBlendFactor

        let flashColor: SKColor = isShip
            ? SKColor(red: 0.6, green: 0.95, blue: 1.0, alpha: 1.0)
            : .white

        let flashIn = SKAction.run {
            enemy.color = flashColor
            enemy.colorBlendFactor = 1.0
        }

        let wait = SKAction.wait(forDuration: tuning.hitFlashDuration)

        let flashOut = SKAction.run {
            enemy.color = originalColor
            enemy.colorBlendFactor = originalBlend
        }

        enemy.run(.sequence([flashIn, wait, flashOut]), withKey: "hitFlash")
    }

    func spawnHitSparks(at position: CGPoint,
                        baseColor: SKColor,
                        count: Int = 10,
                        zPos: CGFloat = 60) {

        guard budget.allow(count) else { return }

        for _ in 0..<count {
            let length = CGFloat.random(in: tuning.hitSparkLength)
            let thickness = CGFloat.random(in: tuning.hitSparkThickness)

            let spark = pool.makeSpark(color: baseColor)
            spark.size = CGSize(width: length, height: thickness)
            spark.position = position
            spark.zPosition = zPos
            spark.alpha = 0.95

            let angle = CGFloat.random(in: 0 ..< (.pi * 2))
            spark.zRotation = angle

            let distance = CGFloat.random(in: tuning.hitSparkDistance)
            let dx = cos(angle) * distance
            let dy = sin(angle) * distance
            let duration = tuning.hitSparkDuration

            layer.addChild(spark)

            let move = SKAction.moveBy(x: dx, y: dy, duration: duration)
            let fade = SKAction.fadeOut(withDuration: duration)
            let scale = SKAction.scaleX(to: 0.2, duration: duration)

            // back into pool
            let recycle = SKAction.run { [weak self, weak spark] in
                guard let self, let spark = spark else { return }
                self.pool.recycleSpark(spark)
            }

            spark.run(.sequence([.group([move, fade, scale]), recycle]))
        }
    }
}
