//
//  SetupEnemies.swift
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

    // MARK: - Setup

    func setupEnemies() {
        // ❗️Nur bei normalen Wave-Levels feste Start-Asteroiden
        guard level.type == .normal else { return }
        guard let lvl = levelNode else { return }

        let asteroidPositions: [CGPoint] = [
            CGPoint(x: lvl.frame.midX + 300, y: lvl.frame.midY),
            CGPoint(x: lvl.frame.midX - 250, y: lvl.frame.midY + 200),
            CGPoint(x: lvl.frame.midX,       y: lvl.frame.midY - 250)
        ]

        for pos in asteroidPositions {
            let asteroid = makeAsteroid()
            asteroid.position = pos
            addChild(asteroid)
            enemies.append(asteroid)
        }
    }

    // MARK: - Factories

    func makeAsteroid() -> SKSpriteNode {
        let sheet = SKTexture(imageNamed: "Asteroid")
        let node: SKSpriteNode

        if sheet.size() != .zero {
            let rows = 2
            let cols = 2

            let frameWidth = sheet.size().width / CGFloat(cols)

            var frames: [SKTexture] = []
            frames.reserveCapacity(rows * cols)

            for row in 0..<rows {
                for col in 0..<cols {
                    let rect = CGRect(
                        x: CGFloat(col) / CGFloat(cols),
                        y: CGFloat(row) / CGFloat(rows),
                        width: 1.0 / CGFloat(cols),
                        height: 1.0 / CGFloat(rows)
                    )
                    frames.append(SKTexture(rect: rect, in: sheet))
                }
            }

            node = SKSpriteNode(texture: frames.first)

            // ✅ Asteroid-Größe: basiert auf Level-Map
            // Feinjustierung hier:
            // factor kleiner -> alles kleiner
            let scale = scaleForSheetFrame(frameWidth: frameWidth,
                                           factor: 0.055,
                                           minPx: 55,
                                           maxPx: 120)
            node.setScale(scale)

            node.run(.repeatForever(.animate(with: frames, timePerFrame: 0.12)))
        } else {
            node = SKSpriteNode(color: .brown, size: CGSize(width: 70, height: 70))
        }

        node.zPosition = 8

        let radius = max(node.size.width, node.size.height) / 2 * 0.8
        let body = SKPhysicsBody(circleOfRadius: radius)
        body.isDynamic = false
        body.affectedByGravity = false
        body.categoryBitMask = PhysicsCategory.enemy
        body.collisionBitMask = PhysicsCategory.player | PhysicsCategory.enemy
        body.contactTestBitMask = PhysicsCategory.bullet | PhysicsCategory.player
        node.physicsBody = body

        addEnemyHealthBar(to: node, maxHP: 5)
        return node
    }

    func makeChaserShip() -> SKSpriteNode {
        let sheet = SKTexture(imageNamed: "EnemyShip")
        let node: SKSpriteNode

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

            node = SKSpriteNode(texture: frames.first)
            node.anchorPoint = CGPoint(x: 0.5, y: 0.6)

            // ✅ EnemyShip-Größe: basiert auf Level-Map
            // Feinjustierung hier:
            let scale = scaleForSheetFrame(frameWidth: frameWidth,
                                           factor: 0.040,
                                           minPx: 36,
                                           maxPx: 80)
            node.setScale(scale)

            node.run(.repeatForever(.animate(with: frames, timePerFrame: 0.12)))
        } else {
            node = SKSpriteNode(color: .blue, size: CGSize(width: 60, height: 80))
        }

        node.zPosition = 9

        let hitboxSize = CGSize(width: node.size.width * 0.7,
                                height: node.size.height * 0.7)
        let body = SKPhysicsBody(rectangleOf: hitboxSize)
        body.isDynamic = true
        body.affectedByGravity = false
        body.allowsRotation = true
        body.categoryBitMask = PhysicsCategory.enemy
        body.collisionBitMask = PhysicsCategory.wall | PhysicsCategory.player | PhysicsCategory.enemy
        body.contactTestBitMask = PhysicsCategory.bullet | PhysicsCategory.player
        node.physicsBody = body

        let maxHP = enemyMaxHPForCurrentRound()
        addEnemyHealthBar(to: node, maxHP: maxHP)

        return node
    }
}
