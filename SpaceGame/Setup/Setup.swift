import SpriteKit

// MARK: - Setup: Hintergrund, Level, Spieler, Kamera, Gegner, HUD

extension GameScene {

    // MARK: - Level

    func setupLevel() {
        let currentLevel = level ?? GameLevels.level1
        level = currentLevel

        levelNode = LevelFactory.makeLevelNode(for: currentLevel, size: size)
        addChild(levelNode)
    }

    // MARK: - Spieler-Schiff

    func setupPlayerShip() {
        let sheet = SKTexture(imageNamed: "PlayerShip")

        if sheet.size() != .zero {
            let rows = 2
            let cols = 2

            let frameWidth  = sheet.size().width  / CGFloat(cols)
            _ = sheet.size().height / CGFloat(rows)

            var frames: [SKTexture] = []

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

                    let frame = SKTexture(rect: rect, in: sheet)
                    frames.append(frame)
                }
            }

            playerShip = SKSpriteNode(texture: frames.first)
            playerShip.anchorPoint = CGPoint(x: 0.5, y: 0.6)

            let desiredWidth = size.width * 0.12
            let scale = desiredWidth / frameWidth
            playerShip.setScale(scale)

            let animation = SKAction.animate(with: frames, timePerFrame: 0.12)
            playerShip.run(.repeatForever(animation))

        } else {
            playerShip = SKSpriteNode(color: .green,
                                      size: CGSize(width: 60, height: 80))
        }

        playerShip.position = CGPoint(x: size.width/2, y: size.height/2)
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

    // MARK: - Kamera

    func setupCamera() {
        camera = cameraNode
        addChild(cameraNode)

        cameraNode.position = playerShip.position
        cameraNode.setScale(cameraZoom)
        
        setupHUD()
    }

    // MARK: - Gegner / Asteroiden + (Schiffe nur per Waves)

    func setupEnemies() {
        // ❗️Nur bei normalen Wave-Levels (z.B. Level 1) feste Start-Asteroiden
        guard level.type == .normal else { return }

        let asteroidPositions: [CGPoint] = [
            CGPoint(x: size.width/2 + 300, y: size.height/2),
            CGPoint(x: size.width/2 - 250, y: size.height/2 + 200),
            CGPoint(x: size.width/2,       y: size.height/2 - 250)
        ]

        for pos in asteroidPositions {
            let asteroid = makeAsteroid()
            asteroid.position = pos
            addChild(asteroid)
            enemies.append(asteroid)
        }
    }

    // MARK: - Hilfsfunktionen zum Erstellen von Gegnern

    func makeAsteroid() -> SKSpriteNode {
        let sheet = SKTexture(imageNamed: "Asteroid")
        let node: SKSpriteNode

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

            node = SKSpriteNode(texture: frames.first)

            let desiredWidth = size.width * 0.18
            let scale = desiredWidth / frameWidth
            node.setScale(scale)

            let animation = SKAction.animate(with: frames, timePerFrame: 0.12)
            node.run(.repeatForever(animation))
        } else {
            node = SKSpriteNode(color: .brown,
                                size: CGSize(width: 70, height: 70))
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

        // Asteroid: 5 Treffer
        addEnemyHealthBar(to: node, maxHP: 5)

        return node
    }

    /// Verfolgenden Gegner (EnemyShip) erzeugen
    func makeChaserShip() -> SKSpriteNode {
        let sheet = SKTexture(imageNamed: "EnemyShip")
        let node: SKSpriteNode

        if sheet.size() != .zero {
            let rows = 2
            let cols = 2

            let frameWidth  = sheet.size().width  / CGFloat(cols)
            _ = sheet.size().height / CGFloat(rows)

            var frames: [SKTexture] = []

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
                    let frame = SKTexture(rect: rect, in: sheet)
                    frames.append(frame)
                }
            }

            node = SKSpriteNode(texture: frames.first)
            node.anchorPoint = CGPoint(x: 0.5, y: 0.6)

            let desiredWidth = size.width * 0.12
            let scale = desiredWidth / frameWidth
            node.setScale(scale)

            let animation = SKAction.animate(with: frames, timePerFrame: 0.12)
            node.run(.repeatForever(animation))
        } else {
            node = SKSpriteNode(color: .blue,
                                size: CGSize(width: 60, height: 80))
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

        // EnemyShip: HP nach Runde
        let maxHP = enemyMaxHPForCurrentRound()
        addEnemyHealthBar(to: node, maxHP: maxHP)

        return node
    }
}
