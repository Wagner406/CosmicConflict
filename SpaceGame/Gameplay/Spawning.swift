//
//  Spawning.swift
//  SpaceGame
//

import SpriteKit

extension GameScene {

    // MARK: - Helpers

    private func clamp(_ value: CGFloat, _ minV: CGFloat, _ maxV: CGFloat) -> CGFloat {
        max(minV, min(maxV, value))
    }

    /// "Welt"-Basisgröße (Level-Node), stabil über iPhone/iPad/Rotation
    private func worldBaseSize() -> CGFloat {
        guard let lvl = levelNode else { return min(size.width, size.height) }
        return min(lvl.frame.width, lvl.frame.height)
    }

    // MARK: - Flying Asteroids

    /// Wird in update() aufgerufen
    func handleFlyingAsteroidSpawning(currentTime: TimeInterval) {
        guard levelNode != nil else { return }

        let currentFlying = children.filter { $0.name == "flyingAsteroid" }.count
        if currentFlying >= maxFlyingAsteroids { return }

        if currentTime - lastAsteroidSpawnTime < nextAsteroidSpawnInterval { return }

        lastAsteroidSpawnTime = currentTime
        nextAsteroidSpawnInterval = TimeInterval.random(in: 5...12)

        spawnFlyingAsteroid()
    }

    func spawnFlyingAsteroid() {
        guard let level = levelNode else { return }

        let sheet = SKTexture(imageNamed: "Asteroid")
        let asteroid: SKSpriteNode

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

            asteroid = SKSpriteNode(texture: frames.first)

            // ✅ Welt-/Level-basiertes Sizing (stabil auf iPad/Landscape)
            // Feinjustierung hier:
            let base = worldBaseSize()
            let baseDesiredWidth = clamp(base * 0.060, 28, 70)     // <- kleiner & stabil
            let sizeFactor = CGFloat.random(in: 0.85...1.15)       // <- weniger Extrem als vorher
            let desiredWidth = baseDesiredWidth * sizeFactor

            let scale = desiredWidth / max(1, frameWidth)
            asteroid.setScale(scale)

            asteroid.run(.repeatForever(.animate(with: frames, timePerFrame: 0.12)))
        } else {
            asteroid = SKSpriteNode(color: .brown, size: CGSize(width: 50, height: 50))
        }

        asteroid.zPosition = 8
        asteroid.name = "flyingAsteroid"

        let radius = max(asteroid.size.width, asteroid.size.height) / 2 * 0.8
        let body = SKPhysicsBody(circleOfRadius: radius)
        body.isDynamic = true
        body.affectedByGravity = false
        body.categoryBitMask = PhysicsCategory.enemy
        body.collisionBitMask = PhysicsCategory.player
        body.contactTestBitMask = PhysicsCategory.bullet
        asteroid.physicsBody = body

        // Fliegender Asteroid: 5 HP
        addEnemyHealthBar(to: asteroid, maxHP: 5)

        // --- Start / End (außerhalb Level)
        let margin: CGFloat = radius * 2

        let minX = level.frame.minX
        let maxX = level.frame.maxX
        let minY = level.frame.minY
        let maxY = level.frame.maxY

        func randomPoint(on side: Int) -> CGPoint {
            switch side {
            case 0: // links
                return CGPoint(x: minX - margin, y: CGFloat.random(in: minY...maxY))
            case 1: // rechts
                return CGPoint(x: maxX + margin, y: CGFloat.random(in: minY...maxY))
            case 2: // unten
                return CGPoint(x: CGFloat.random(in: minX...maxX), y: minY - margin)
            default: // oben
                return CGPoint(x: CGFloat.random(in: minX...maxX), y: maxY + margin)
            }
        }

        let startSide = Int.random(in: 0..<4)
        var endSide = Int.random(in: 0..<4)
        while endSide == startSide { endSide = Int.random(in: 0..<4) }

        let start = randomPoint(on: startSide)
        let end = randomPoint(on: endSide)

        asteroid.position = start
        addChild(asteroid)
        enemies.append(asteroid)

        // --- Bewegung
        let distance = hypot(end.x - start.x, end.y - start.y)
        let speed = CGFloat.random(in: 140...260)
        let duration = TimeInterval(distance / speed)

        let move = SKAction.move(to: end, duration: duration)
        let cleanup = SKAction.run { [weak self, weak asteroid] in
            if let asteroid = asteroid {
                self?.enemies.removeAll { $0 == asteroid }
            }
        }

        asteroid.run(.sequence([move, cleanup, .removeFromParent()]))
    }
}
