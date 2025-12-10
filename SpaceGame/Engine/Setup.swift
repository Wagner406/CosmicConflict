import SpriteKit

// MARK: - Setup: Hintergrund, Level, Spieler, Kamera, Gegner, HUD

extension GameScene {

    // MARK: - Hintergrund (Space + Fog of War)

    func setupBackground() {
        let texture = SKTexture(imageNamed: "test")

        let bg: SKSpriteNode
        if texture.size() != .zero {
            bg = SKSpriteNode(texture: texture)

            let baseScale = max(size.width  / texture.size().width,
                                size.height / texture.size().height)
            bg.setScale(baseScale * 5.0)
        } else {
            bg = SKSpriteNode(color: .black,
                              size: CGSize(width: size.width * 3,
                                           height: size.height * 3))
        }

        bg.position = CGPoint(x: size.width / 2, y: size.height / 2)
        bg.zPosition = -100

        bg.color = .black
        bg.colorBlendFactor = 0.25

        addChild(bg)
        spaceBackground = bg
    }

    // MARK: - Gegner-Healthbars

    func addEnemyHealthBar(to enemy: SKSpriteNode, maxHP: Int) {
        if enemy.userData == nil {
            enemy.userData = NSMutableDictionary()
        }
        enemy.userData?["maxHP"] = maxHP
        enemy.userData?["hp"] = maxHP

        let width = enemy.size.width * 3
        let height: CGFloat = 50

        let bg = SKSpriteNode(
            color: .black,
            size: CGSize(width: width, height: height)
        )
        bg.alpha = 0.6
        bg.position = CGPoint(
            x: 0,
            y: enemy.size.height / 2 + enemy.size.height * 3
        )
        bg.zPosition = enemy.zPosition + 1
        bg.name = "hpBarBackground"

        let bar = SKSpriteNode(
            color: .green,
            size: CGSize(width: width, height: height)
        )
        bar.anchorPoint = CGPoint(x: 0, y: 0.5)
        bar.position = CGPoint(x: -width / 2, y: 0)
        bar.zPosition = bg.zPosition + 1
        bar.name = "hpBar"

        bg.addChild(bar)
        enemy.addChild(bg)
    }

    func updateEnemyHealthBar(for enemy: SKSpriteNode) {
        guard
            let userData = enemy.userData,
            let hp = userData["hp"] as? Int,
            let maxHP = userData["maxHP"] as? Int,
            let bg = enemy.childNode(withName: "hpBarBackground") as? SKSpriteNode,
            let bar = bg.childNode(withName: "hpBar") as? SKSpriteNode
        else { return }

        let fraction = max(0, min(1, CGFloat(hp) / CGFloat(maxHP)))
        bar.xScale = fraction

        if fraction > 0.6 {
            bar.color = .green
        } else if fraction > 0.3 {
            bar.color = .yellow
        } else {
            bar.color = .red
        }
    }

    // MARK: - Level

    func setupLevel() {
        let currentLevel = level ?? GameLevels.level1
        level = currentLevel

        levelNode = LevelFactory.makeLevelNode(for: currentLevel, size: size)
        addChild(levelNode)

        if levelNode != nil {
            spawnLevelStars()
        }
    }

    // MARK: - Sterne / Starfield im Level

    /// Erzeugt einen Sternen-Layer innerhalb der spielbaren Map
    func spawnLevelStars() {
        // alte Sterne entfernen
        starFieldNode?.removeFromParent()
        guard let levelNode = levelNode else { return }

        let starContainer = SKNode()
        starContainer.name = "StarField"
        // ⭐ Über dem Level-Hintergrund, aber unter Asteroiden/Ships (8/9/10)
        starContainer.zPosition = 4
        levelNode.addChild(starContainer)
        starFieldNode = starContainer

        // lokale Größe der spielbaren Map
        let levelSize = levelNode.frame.size
        let width: CGFloat  = levelSize.width
        let height: CGFloat = levelSize.height
        let halfW = width / 2
        let halfH = height / 2

        let area = width * height
        let baseDensity: CGFloat = 1.0 / 25000.0
        var starCount = Int(area * baseDensity)
        starCount = max(140, min(starCount, 360))   // etwas dichter

        for _ in 0..<starCount {
            let size = CGFloat.random(in: 3.0...6.0)

            // ⭐ Runder, leuchtender Stern
            let star = SKShapeNode(circleOfRadius: size / 2)
            star.fillColor = .white
            star.strokeColor = .clear
            star.glowWidth = size * 1.3   // weicher Glow
            star.lineWidth = 0
            star.zPosition = 0

            // ❗ lokale Position innerhalb der Map (nicht frame.minX/maxX)
            let x = CGFloat.random(in: -halfW ... halfW)
            let y = CGFloat.random(in: -halfH ... halfH)
            star.position = CGPoint(x: x, y: y)

            star.alpha = 1.0

            // ⭐ Twinkle-Effekte
            if Bool.random() {
                // weiches Pulsieren
                let minA: CGFloat = 0.4
                let pulse = SKAction.sequence([
                    .fadeAlpha(to: minA, duration: Double.random(in: 0.5...0.9)),
                    .fadeAlpha(to: 1.0, duration: Double.random(in: 0.5...0.9))
                ])
                star.run(.repeatForever(pulse))
            } else {
                // seltenes Aufblitzen
                let baseA: CGFloat = 0.15
                star.alpha = baseA
                let twinkle = SKAction.sequence([
                    .wait(forDuration: Double.random(in: 0.8...3.0)),
                    .fadeAlpha(to: 1.0, duration: 0.08),
                    .fadeAlpha(to: baseA, duration: 0.25)
                ])
                star.run(.repeatForever(twinkle))
            }

            starContainer.addChild(star)
        }
    }

    // MARK: - Shooting Stars

    /// Helle, diagonale Shooting Stars, die über die spielbare Map fliegen
    func spawnShootingStar(currentTime: TimeInterval) {
        guard let levelNode = levelNode,
              let starContainer = starFieldNode else { return }

        // Zeitbasiert: nur alle paar Sekunden
        if currentTime < lastShootingStarTime {
            return
        }

        // nächster Spawn irgendwo zwischen 5 und 10 Sekunden
        lastShootingStarTime = currentTime + TimeInterval.random(in: 3.0...10.0)

        // LOKALE Größe des Levelbereichs
        let levelSize = levelNode.frame.size
        let width  = levelSize.width
        let height = levelSize.height
        let halfW = width / 2
        let halfH = height / 2

        // Größe des Strichs
        let length    = CGFloat.random(in: 40...80)
        let thickness = CGFloat.random(in: 2...4)

        let star = SKSpriteNode(
            color: .white,
            size: CGSize(width: length, height: thickness)
        )
        star.alpha = 1.0
        star.blendMode = .add
        star.colorBlendFactor = 1.0
        // über den normalen Sternen (0), unter Gameplay (8/9/10)
        star.zPosition = 1

        // Start: links oder rechts außerhalb des Levelbereichs (lokale Koords)
        let fromLeft = Bool.random()
        let startX = fromLeft ? -halfW - 150 : halfW + 150
        let startY = CGFloat.random(in: 0 ... halfH)
        let startPos = CGPoint(x: startX, y: startY)

        // Ziel: andere Seite, eher nach unten
        let endX = fromLeft ? halfW + 250 : -halfW - 250
        let endY = CGFloat.random(in: -halfH ... 0)
        let endPos = CGPoint(x: endX, y: endY)

        star.position = startPos

        // Rotation an Flugrichtung
        let dirX = endX - startX
        let dirY = endY - startY
        star.zRotation = atan2(dirY, dirX)

        let distance = hypot(dirX, dirY)
        let speed: CGFloat = 1300
        let duration = TimeInterval(distance / speed)

        let move = SKAction.move(to: endPos, duration: duration)
        let fade = SKAction.fadeOut(withDuration: duration)
        let group = SKAction.group([move, fade])

        // ❗ jetzt im Star-Container, nicht direkt im LevelNode
        starContainer.addChild(star)
        star.run(.sequence([group, .removeFromParent()]))
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

    // MARK: - HUD (Spieler-Lebensbalken + Runde + Powerups)

    func setupHUD() {
        cameraNode.addChild(hudNode)

        let barWidth = size.width * 0.4
        let barHeight: CGFloat = 16

        let bg = SKSpriteNode(
            color: .darkGray,
            size: CGSize(width: barWidth, height: barHeight)
        )
        bg.alpha = 0.7
        bg.position = CGPoint(
            x: 0,
            y: size.height / 2 - barHeight * 5
        )
        bg.zPosition = 200
        bg.name = "playerHPBackground"

        let bar = SKSpriteNode(
            color: .green,
            size: CGSize(width: barWidth, height: barHeight)
        )
        bar.anchorPoint = CGPoint(x: 0, y: 0.5)
        bar.position = CGPoint(x: -barWidth / 2, y: 0)
        bar.zPosition = bg.zPosition + 1
        bar.name = "playerHPBar"

        bg.addChild(bar)
        hudNode.addChild(bg)

        playerHealthBar = bar
        updatePlayerHealthBar()

        // Runden-Anzeige oben links
        let round = SKLabelNode(fontNamed: "AvenirNext-Bold")
        round.fontSize = 20
        round.fontColor = .white
        round.horizontalAlignmentMode = .left
        round.verticalAlignmentMode = .center

        let margin: CGFloat = 20
        round.position = CGPoint(
            x: -size.width / 2 + margin,
            y: bg.position.y
        )
        round.zPosition = 210
        round.text = "Round \(currentRound)"

        hudNode.addChild(round)
        roundLabel = round

        // Powerup-Label oben rechts
        let powerLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        powerLabel.fontSize = 20
        powerLabel.fontColor = .cyan
        powerLabel.horizontalAlignmentMode = .right
        powerLabel.verticalAlignmentMode = .center

        powerLabel.position = CGPoint(
            x: size.width / 2 - margin,
            y: bg.position.y
        )
        powerLabel.zPosition = 210
        powerLabel.text = ""
        powerLabel.isHidden = true

        hudNode.addChild(powerLabel)
        powerUpLabel = powerLabel
    }

    func updatePlayerHealthBar() {
        guard let bar = playerHealthBar else { return }

        let fraction = max(0, min(1, CGFloat(playerHP) / CGFloat(playerMaxHP)))
        bar.xScale = fraction

        if fraction > 0.6 {
            bar.color = .green
        } else if fraction > 0.3 {
            bar.color = .yellow
        } else {
            bar.color = .red
        }
    }

    func updateRoundLabel() {
        roundLabel?.text = "Round \(currentRound)"
    }

    func setActivePowerUpLabel(_ text: String?) {
        guard let label = powerUpLabel else { return }

        if let text = text, !text.isEmpty {
            label.text = text
            label.isHidden = false
        } else {
            label.text = ""
            label.isHidden = true
        }
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
