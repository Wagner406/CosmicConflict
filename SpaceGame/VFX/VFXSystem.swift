//
//  VFXSystem.swift
//  SpaceGame
//
//  Created by Alexander Wagner on 14.12.25.
//

import SpriteKit

final class VFXSystem {

    // MARK: - Public API

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

        let wait = SKAction.wait(forDuration: 0.06)

        let flashOut = SKAction.run {
            enemy.color = originalColor
            enemy.colorBlendFactor = originalBlend
        }

        enemy.run(.sequence([flashIn, wait, flashOut]), withKey: "hitFlash")
    }

    func spawnHitSparks(in scene: SKScene,
                       at position: CGPoint,
                       baseColor: SKColor,
                       count: Int = 10,
                       zPos: CGFloat = 60) {
        for _ in 0..<count {
            let length = CGFloat.random(in: 18...32)
            let thickness = CGFloat.random(in: 3...5)

            let spark = SKSpriteNode(color: baseColor, size: CGSize(width: length, height: thickness))
            spark.position = position
            spark.zPosition = zPos
            spark.alpha = 0.95
            spark.blendMode = .add
            spark.anchorPoint = CGPoint(x: 0.0, y: 0.5)

            let angle = CGFloat.random(in: 0 ..< (.pi * 2))
            spark.zRotation = angle

            let distance = CGFloat.random(in: 60...120)
            let dx = cos(angle) * distance
            let dy = sin(angle) * distance

            let duration: TimeInterval = 0.18
            let move  = SKAction.moveBy(x: dx, y: dy, duration: duration)
            let fade  = SKAction.fadeOut(withDuration: duration)
            let scale = SKAction.scaleX(to: 0.2, duration: duration)

            spark.run(.sequence([.group([move, fade, scale]), .removeFromParent()]))
            scene.addChild(spark)
        }
    }

    func spawnExplosionSparks(in scene: SKScene,
                             at position: CGPoint,
                             baseColor: SKColor = .yellow,
                             count: Int = 20,
                             zPos: CGFloat = 50) {
        for _ in 0..<count {
            let length = CGFloat.random(in: 14...26)
            let thickness = CGFloat.random(in: 3...6)

            let spark = SKSpriteNode(color: baseColor, size: CGSize(width: length, height: thickness))
            spark.position = position
            spark.zPosition = zPos
            spark.alpha = 1.0
            spark.blendMode = .add
            spark.anchorPoint = CGPoint(x: 0.0, y: 0.5)

            let angle = CGFloat.random(in: 0 ..< (.pi * 2))
            spark.zRotation = angle

            let distance = CGFloat.random(in: 80...180)
            let dx = cos(angle) * distance
            let dy = sin(angle) * distance

            let duration: TimeInterval = 0.35
            let move  = SKAction.moveBy(x: dx, y: dy, duration: duration)
            let fade  = SKAction.fadeOut(withDuration: duration)
            let scale = SKAction.scaleX(to: 0.2, duration: duration)

            spark.run(.sequence([.group([move, fade, scale]), .removeFromParent()]))
            scene.addChild(spark)
        }
    }

    func triggerExplosionShockwave(in scene: SKScene,
                                  camera: SKCameraNode?,
                                  at position: CGPoint) {
        // Ring
        let ringRadius: CGFloat = 80
        let ring = SKShapeNode(circleOfRadius: ringRadius)
        ring.position = position
        ring.zPosition = 999
        ring.strokeColor = .cyan
        ring.lineWidth = 6
        ring.glowWidth = 10
        ring.fillColor = .clear
        ring.alpha = 0.9
        ring.setScale(0.2)

        scene.addChild(ring)

        let scaleUp = SKAction.scale(to: 1.4, duration: 0.18)
        let fadeOut = SKAction.fadeOut(withDuration: 0.18)
        ring.run(.sequence([.group([scaleUp, fadeOut]), .removeFromParent()]))

        // Kamera Punch + Shake
        guard let cam = camera else { return }

        let originalScale = cam.xScale
        let punchIn  = SKAction.scale(to: originalScale * 0.92, duration: 0.05)
        let punchOut = SKAction.scale(to: originalScale, duration: 0.12)
        punchIn.timingMode = .easeOut
        punchOut.timingMode = .easeIn

        let shakeAmount: CGFloat = 8
        let shakeDuration: TimeInterval = 0.16

        let moveLeft  = SKAction.moveBy(x: -shakeAmount, y: 0, duration: shakeDuration / 4)
        let moveRight = SKAction.moveBy(x:  shakeAmount * 2, y: 0, duration: shakeDuration / 4)
        let moveBack  = SKAction.moveBy(x: -shakeAmount, y: 0, duration: shakeDuration / 4)
        let moveUp    = SKAction.moveBy(x: 0, y: shakeAmount, duration: shakeDuration / 4)
        let moveDown  = SKAction.moveBy(x: 0, y: -shakeAmount, duration: shakeDuration / 4)

        cam.run(.sequence([punchIn, punchOut]))
        cam.run(.sequence([moveLeft, moveRight, moveBack, moveUp, moveDown]))
    }

    func playEnemyShipExplosion(in scene: SKScene,
                               camera: SKCameraNode?,
                               at position: CGPoint,
                               zPosition: CGFloat,
                               desiredWidth: CGFloat) {
        let sheet = SKTexture(imageNamed: "ExplosionEnemyShip")
        guard sheet.size() != .zero else { return }

        let rows = 2
        let cols = 3
        var frames: [SKTexture] = []

        for row in 0..<rows {
            for col in 0..<cols {
                let originX = CGFloat(col) / CGFloat(cols)
                let originY = 1.0 - CGFloat(row + 1) / CGFloat(rows)
                let rect = CGRect(x: originX, y: originY, width: 1.0 / CGFloat(cols), height: 1.0 / CGFloat(rows))
                frames.append(SKTexture(rect: rect, in: sheet))
            }
        }

        let frameWidth = sheet.size().width / CGFloat(cols)
        let scale = desiredWidth / frameWidth

        let explosion = SKSpriteNode(texture: frames.first)
        explosion.setScale(scale)
        explosion.position = position
        explosion.zPosition = zPosition + 1
        explosion.alpha = 1.0
        explosion.blendMode = .add
        scene.addChild(explosion)

        triggerExplosionShockwave(in: scene, camera: camera, at: position)

        let animate = SKAction.animate(with: frames, timePerFrame: 0.05)
        let fadeOut = SKAction.fadeOut(withDuration: 0.5)
        explosion.run(.sequence([.group([animate, fadeOut]), .removeFromParent()]))

        spawnExplosionSparks(in: scene, at: position, baseColor: .cyan, count: 24, zPos: 60)
    }

    func playAsteroidDestruction(in scene: SKScene,
                                asteroid: SKSpriteNode,
                                savedVelocity: CGVector) {
        let sheet = SKTexture(imageNamed: "AstroidDestroyed")

        guard sheet.size() != .zero else {
            asteroid.run(.sequence([.fadeOut(withDuration: 0.15), .removeFromParent()]))
            return
        }

        let rows = 3
        let cols = 2
        var frames: [SKTexture] = []

        for row in 0..<rows {
            for col in 0..<cols {
                let originX = CGFloat(col) / CGFloat(cols)
                let originY = 1.0 - CGFloat(row + 1) / CGFloat(rows)
                let rect = CGRect(x: originX, y: originY, width: 1.0 / CGFloat(cols), height: 1.0 / CGFloat(rows))
                frames.append(SKTexture(rect: rect, in: sheet))
            }
        }

        asteroid.physicsBody = nil
        asteroid.removeAllActions()

        let animate = SKAction.animate(with: frames, timePerFrame: 0.05)
        let fadeOut = SKAction.fadeOut(withDuration: 0.5)

        let driftDuration: TimeInterval = 0.5
        let drift = SKAction.moveBy(
            x: savedVelocity.dx * driftDuration,
            y: savedVelocity.dy * driftDuration,
            duration: driftDuration
        )

        asteroid.run(.sequence([.group([animate, fadeOut, drift]), .removeFromParent()]))

        spawnExplosionSparks(
            in: scene,
            at: asteroid.position,
            baseColor: SKColor(red: 0.7, green: 0.5, blue: 0.3, alpha: 1.0),
            count: 18,
            zPos: asteroid.zPosition + 1
        )
    }
}
