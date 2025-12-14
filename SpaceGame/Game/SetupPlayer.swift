//
//  SetupPlayer.swift
//  SpaceGame
//

import SpriteKit

extension GameScene {

    func setupPlayerShip() {
        let sheet = SKTexture(imageNamed: "PlayerShip")

        if sheet.size() != .zero {
            let rows = 2
            let cols = 2

            let frameWidth = sheet.size().width / CGFloat(cols)

            var frames: [SKTexture] = []
            frames.reserveCapacity(rows * cols)

            for row in 0..<rows {
                for col in 0..<cols {
                    let originX = CGFloat(col) / CGFloat(cols)
                    let originY = 1.0 - CGFloat(row + 1) / CGFloat(rows)

                    let rect = CGRect(
                        x: originX,
                        y: originY,
                        width: 1.0 / CGFloat(cols),
                        height: 1.0 / CGFloat(rows)
                    )

                    frames.append(SKTexture(rect: rect, in: sheet))
                }
            }

            playerShip = SKSpriteNode(texture: frames.first)
            playerShip.anchorPoint = CGPoint(x: 0.5, y: 0.6)

            let desiredWidth = size.width * 0.12
            let scale = desiredWidth / frameWidth
            playerShip.setScale(scale)

            playerShip.run(.repeatForever(.animate(with: frames, timePerFrame: 0.12)))
        } else {
            playerShip = SKSpriteNode(color: .green, size: CGSize(width: 60, height: 80))
        }

        playerShip.position = CGPoint(x: size.width / 2, y: size.height / 2)
        playerShip.zPosition = 10
        playerShip.zRotation = 0

        let hitboxSize = CGSize(width: playerShip.size.width * 0.7,
                                height: playerShip.size.height * 0.7)
        playerShip.physicsBody = SKPhysicsBody(rectangleOf: hitboxSize)
        playerShip.physicsBody?.isDynamic = true
        playerShip.physicsBody?.allowsRotation = true
        playerShip.physicsBody?.affectedByGravity = false

        playerShip.physicsBody?.categoryBitMask = PhysicsCategory.player
        playerShip.physicsBody?.collisionBitMask = PhysicsCategory.wall | PhysicsCategory.enemy
        playerShip.physicsBody?.contactTestBitMask =
            PhysicsCategory.enemyBullet | PhysicsCategory.enemy | PhysicsCategory.powerUp

        addChild(playerShip)
    }
}
