//
//  Spawning.swift
//  SpaceGame
//
//  Created by Alexander Wagner on 30.11.25.
//

import SpriteKit

extension GameScene {

    // Wird in update() aufgerufen
    func handleFlyingAsteroidSpawning(currentTime: TimeInterval) {
        guard levelNode != nil else { return }

        // Wie viele fliegende Asteroiden sind schon aktiv?
        let currentFlying = children.filter { $0.name == "flyingAsteroid" }.count
        if currentFlying >= maxFlyingAsteroids {
            return   // schon genug unterwegs
        }

        // noch nicht Zeit? -> nichts tun
        if currentTime - lastAsteroidSpawnTime < nextAsteroidSpawnInterval {
            return
        }

        // Zeitpunkt merken und neues Intervall würfeln
        lastAsteroidSpawnTime = currentTime
        nextAsteroidSpawnInterval = TimeInterval.random(in: 5...12)

        spawnFlyingAsteroid()
    }

    // Ein einzelner fliegender Asteroid
    func spawnFlyingAsteroid() {
        guard let level = levelNode else { return }

        // --- 1) Asteroiden-Sprite wie bei den statischen ---

        let sheet = SKTexture(imageNamed: "Asteroid")
        let asteroid: SKSpriteNode

        if sheet.size() != .zero {
            let rows = 2
            let cols = 2

            let frameWidth  = sheet.size().width  / CGFloat(cols)
            _ = sheet.size().height / CGFloat(rows)

            var frames: [SKTexture] = []

            for row in 0..<rows {
                for col in 0..<cols {
                    let rect = CGRect(
                        x: CGFloat(col) / CGFloat(cols),
                        y: CGFloat(row) / CGFloat(rows),
                        width: 1.0 / CGFloat(cols),
                        height: 1.0 / CGFloat(rows)
                    )
                    let frame = SKTexture(rect: rect, in: sheet)
                    frames.append(frame)
                }
            }

            asteroid = SKSpriteNode(texture: frames.first)

            let baseDesiredWidth = size.width * 0.15
            let sizeFactor = CGFloat.random(in: 0.7...1.4)
            let desiredWidth = baseDesiredWidth * sizeFactor

            let scale = desiredWidth / frameWidth
            asteroid.setScale(scale)

            let animation = SKAction.animate(with: frames, timePerFrame: 0.12)
            asteroid.run(.repeatForever(animation))

        } else {
            asteroid = SKSpriteNode(color: .brown,
                                    size: CGSize(width: 60, height: 60))
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

        // 🔥 Fliegender Asteroid: 5 HP
        addEnemyHealthBar(to: asteroid, maxHP: 5)

        // --- 2) Start- & Zielposition (inkl. Diagonalen) ---

        let margin: CGFloat = radius * 2

        let minX = level.frame.minX
        let maxX = level.frame.maxX
        let minY = level.frame.minY
        let maxY = level.frame.maxY

        func randomPoint(on side: Int) -> CGPoint {
            switch side {
            case 0: // links
                let y = CGFloat.random(in: minY...maxY)
                return CGPoint(x: minX - margin, y: y)
            case 1: // rechts
                let y = CGFloat.random(in: minY...maxY)
                return CGPoint(x: maxX + margin, y: y)
            case 2: // unten
                let x = CGFloat.random(in: minX...maxX)
                return CGPoint(x: x, y: minY - margin)
            default: // oben
                let x = CGFloat.random(in: minX...maxX)
                return CGPoint(x: x, y: maxY + margin)
            }
        }

        let startSide = Int.random(in: 0..<4)
        var endSide = Int.random(in: 0..<4)
        while endSide == startSide {
            endSide = Int.random(in: 0..<4)
        }

        let start = randomPoint(on: startSide)
        let end   = randomPoint(on: endSide)

        asteroid.position = start
        addChild(asteroid)
        enemies.append(asteroid)

        // --- 3) Gerade Bewegung mit zufälliger Geschwindigkeit ---

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
