//
//  SetupPlayer.swift
//  SpaceGame
//

import SpriteKit

extension GameScene {

    // MARK: - Helpers

    private func clamp(_ value: CGFloat, _ minV: CGFloat, _ maxV: CGFloat) -> CGFloat {
        max(minV, min(maxV, value))
    }

    /// Einheitliche World-Referenz: basiert auf Level-Map (nicht Screen, nicht Camera)
    private func worldBase() -> CGFloat {
        guard let lvl = levelNode else { return min(size.width, size.height) }
        return min(lvl.frame.width, lvl.frame.height)
    }

    /// Skaliert ein Sprite anhand einer Frame-Breite aus einem SpriteSheet
    private func scaleForSheetFrame(frameWidth: CGFloat, factor: CGFloat, minPx: CGFloat, maxPx: CGFloat) -> CGFloat {
        let desiredWidth = clamp(worldBase() * factor, minPx, maxPx)
        return desiredWidth / max(1, frameWidth)
    }

    // MARK: - Player

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

            // ✅ Player-Größe: basiert auf Level-Map (stabil auf allen Devices)
            // Feinjustierung hier:
            let scale = scaleForSheetFrame(frameWidth: frameWidth,
                                           factor: 0.040,
                                           minPx: 36,
                                           maxPx: 85)
            playerShip.setScale(scale)

            playerShip.run(.repeatForever(.animate(with: frames, timePerFrame: 0.12)))
        } else {
            playerShip = SKSpriteNode(color: .green, size: CGSize(width: 60, height: 80))
        }

        // ✅ Spawn in Level-Mitte (nicht Screen-Mitte)
        if let lvl = levelNode {
            playerShip.position = CGPoint(x: lvl.frame.midX, y: lvl.frame.midY)
        } else {
            playerShip.position = CGPoint(x: 0, y: 0)
        }

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
