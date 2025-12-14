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
            setupToxicGasClouds()
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
    
    // MARK: - Giftige Gaswolken um die spielbare Map

    func setupToxicGasClouds() {
        guard let levelNode = levelNode else { return }

        // Alte Gas-Nodes entfernen
        childNode(withName: "ToxicGas")?.removeFromParent()

        let gasContainer = SKNode()
        gasContainer.name = "ToxicGas"
        gasContainer.zPosition = 2      // über Background, unter Gameplay
        addChild(gasContainer)

        let levelFrame = levelNode.frame

        // ➜ Abstand & Spread wie von dir gewählt
        let margin: CGFloat     = 100      // Abstand zur spielbaren Map
        let extraSpread: CGFloat = 50      // wie weit die Wolken nach außen streuen dürfen

        // NEU: wie viele Reihen & Abstände zwischen den Reihen
        let rowCount = 3
        let rowSpacing: CGFloat = 200

        // Texturen laden
        var textures: [SKTexture] = [
            SKTexture(imageNamed: "ToxicCloud1"),
            SKTexture(imageNamed: "ToxicCloud2"),
            SKTexture(imageNamed: "ToxicCloud3")
        ].filter { $0.size() != .zero }

        if textures.isEmpty { return }

        func addCloud(at position: CGPoint, bigger: Bool = false) {
            let tex = textures.randomElement()!
            let cloud = SKSpriteNode(texture: tex)

            // Größe
            let base = min(levelFrame.width, levelFrame.height)
            let baseFactor: ClosedRange<CGFloat> = bigger ? 0.45...0.60 : 0.32...0.45
            let desiredWidth = base * CGFloat.random(in: baseFactor)
            let scale = desiredWidth / tex.size().width
            cloud.setScale(scale)

            cloud.position = position
            cloud.zPosition = 0
            cloud.alpha = 0.85

            // giftgrün einfärben + leichtes Glow
            cloud.color = SKColor(red: 0.1, green: 1.0, blue: 0.3, alpha: 1.0)
            cloud.colorBlendFactor = 0.9
            cloud.blendMode = .screen   // stärkeres Leuchten

            // leichtes „Atmen“ der Wolke (Puls)
            let breathe = SKAction.sequence([
                SKAction.group([
                    SKAction.fadeAlpha(to: 0.6, duration: 1.2),
                    SKAction.scale(to: CGFloat.random(in: 0.96...1.04), duration: 1.2)
                ]),
                SKAction.group([
                    SKAction.fadeAlpha(to: 0.9, duration: 1.2),
                    SKAction.scale(to: 1.0, duration: 1.2)
                ])
            ])
            cloud.run(.repeatForever(breathe))

            // ➜ seitliches Driften OHNE Gesamtverschiebung:
            let maxDrift: CGFloat = 18
            let dx = CGFloat.random(in: -maxDrift...maxDrift)
            let drift = SKAction.sequence([
                SKAction.moveBy(x: dx, y: 0, duration: 3.0),
                SKAction.moveBy(x: -dx, y: 0, duration: 3.0)
            ])
            cloud.run(.repeatForever(drift))

            gasContainer.addChild(cloud)
        }

        let cloudsPerSide = 25

        // TOP – 3 Reihen oberhalb der Map
        for row in 0..<rowCount {
            let baseY = levelFrame.maxY + margin + CGFloat(row) * rowSpacing
            for i in 0..<cloudsPerSide {
                let t = (CGFloat(i) + 0.5) / CGFloat(cloudsPerSide)
                let x = levelFrame.minX + t * levelFrame.width
                let y = baseY + CGFloat.random(in: 0...extraSpread)
                addCloud(at: CGPoint(x: x, y: y))
            }
        }

        // BOTTOM – 3 Reihen unterhalb der Map
        for row in 0..<rowCount {
            let baseY = levelFrame.minY - margin - CGFloat(row) * rowSpacing
            for i in 0..<cloudsPerSide {
                let t = (CGFloat(i) + 0.5) / CGFloat(cloudsPerSide)
                let x = levelFrame.minX + t * levelFrame.width
                let y = baseY - CGFloat.random(in: 0...extraSpread)
                addCloud(at: CGPoint(x: x, y: y))
            }
        }

        // LEFT – 3 Reihen links von der Map
        for row in 0..<rowCount {
            let baseX = levelFrame.minX - margin - CGFloat(row) * rowSpacing
            for i in 0..<cloudsPerSide {
                let t = (CGFloat(i) + 0.5) / CGFloat(cloudsPerSide)
                let y = levelFrame.minY + t * levelFrame.height
                let x = baseX - CGFloat.random(in: 0...extraSpread)
                addCloud(at: CGPoint(x: x, y: y))
            }
        }

        // RIGHT – 3 Reihen rechts von der Map
        for row in 0..<rowCount {
            let baseX = levelFrame.maxX + margin + CGFloat(row) * rowSpacing
            for i in 0..<cloudsPerSide {
                let t = (CGFloat(i) + 0.5) / CGFloat(cloudsPerSide)
                let y = levelFrame.minY + t * levelFrame.height
                let x = baseX + CGFloat.random(in: 0...extraSpread)
                addCloud(at: CGPoint(x: x, y: y))
            }
        }

        // Große Wolken weit in den Ecken (außerhalb der äußersten Reihe)
        let cornerOffset = margin + CGFloat(rowCount) * rowSpacing + extraSpread
        addCloud(at: CGPoint(x: levelFrame.minX - cornerOffset,
                             y: levelFrame.maxY + cornerOffset),
                 bigger: true)
        addCloud(at: CGPoint(x: levelFrame.maxX + cornerOffset,
                             y: levelFrame.maxY + cornerOffset),
                 bigger: true)
        addCloud(at: CGPoint(x: levelFrame.minX - cornerOffset,
                             y: levelFrame.minY - cornerOffset),
                 bigger: true)
        addCloud(at: CGPoint(x: levelFrame.maxX + cornerOffset,
                             y: levelFrame.minY - cornerOffset),
                 bigger: true)
        
        // --- Extra: 3 Reihen pro Ecke für mehr Dichte ---

        let cornerLayers = 3
        let cornerSpacing: CGFloat = 90  // Abstand zwischen den Reihen

        func addCornerCluster(baseX: CGFloat, baseY: CGFloat) {
            for layer in 0..<cornerLayers {
                let offset = CGFloat(layer) * cornerSpacing

                // kleine zufällige Variation pro Wolke
                let jitterX = CGFloat.random(in: -40...40)
                let jitterY = CGFloat.random(in: -40...40)

                addCloud(at: CGPoint(
                    x: baseX + jitterX + offset,
                    y: baseY + jitterY + offset
                ))

                addCloud(at: CGPoint(
                    x: baseX + jitterX - offset,
                    y: baseY + jitterY + offset
                ))

                addCloud(at: CGPoint(
                    x: baseX + jitterX + offset,
                    y: baseY + jitterY - offset
                ))

                addCloud(at: CGPoint(
                    x: baseX + jitterX - offset,
                    y: baseY + jitterY - offset
                ))
            }
        }

        // jetzt die 4 Ecken "verdicken"
        addCornerCluster(
            baseX: levelFrame.minX - margin - extraSpread,
            baseY: levelFrame.maxY + margin + extraSpread
        )

        addCornerCluster(
            baseX: levelFrame.maxX + margin + extraSpread,
            baseY: levelFrame.maxY + margin + extraSpread
        )

        addCornerCluster(
            baseX: levelFrame.minX - margin - extraSpread,
            baseY: levelFrame.minY - margin - extraSpread
        )

        addCornerCluster(
            baseX: levelFrame.maxX + margin + extraSpread,
            baseY: levelFrame.minY - margin - extraSpread
        )
    }
    
    // MARK: - Tiefen-Parallax-Nebula

    /// Große, weiche Nebelwolken im Hintergrund, die per Parallax verschoben werden
    func setupParallaxNebulaLayer() {
        nebulaLayer?.removeFromParent()
        guard let levelNode = levelNode else { return }

        let container = SKNode()
        container.name = "ParallaxNebula"
        // über Background (-100), aber unter Level/Stars/Gameplay
        container.zPosition = 3
        addChild(container)
        nebulaLayer = container

        let levelFrame = levelNode.frame
        let width  = levelFrame.width
        let height = levelFrame.height

        // vorhandene ToxicCloud-Assets als Nebeltexturen benutzen
        var textures: [SKTexture] = [
            SKTexture(imageNamed: "ToxicCloud1"),
            SKTexture(imageNamed: "ToxicCloud2"),
            SKTexture(imageNamed: "ToxicCloud3")
        ].filter { $0.size() != .zero }

        if textures.isEmpty { return }

        // Anzahl Nebel-Flecken
        let baseArea = width * height
        let density: CGFloat = 1.0 / 350000.0
        var count = Int(baseArea * density)
        count = max(5, min(count, 10))

        let baseSize = min(width, height)

        for _ in 0..<count {
            guard let tex = textures.randomElement() else { continue }

            let nebula = SKSpriteNode(texture: tex)

            // Groß & weich
            let desiredWidth = baseSize * CGFloat.random(in: 0.6...0.9)
            let scale = desiredWidth / tex.size().width
            nebula.setScale(scale)

            // Position irgendwo in der spielbaren Fläche
            let x = CGFloat.random(in: levelFrame.minX ... levelFrame.maxX)
            let y = CGFloat.random(in: levelFrame.minY ... levelFrame.maxY)
            nebula.position = CGPoint(x: x, y: y)

            // Blau/Violett, sehr weich, transparenter als Toxic-Gas am Rand
            nebula.color = SKColor(red: CGFloat.random(in: 0.3...0.5),
                                   green: CGFloat.random(in: 0.5...0.8),
                                   blue: 1.0,
                                   alpha: 1.0)
            nebula.colorBlendFactor = 0.85
            nebula.alpha = 0.28
            nebula.blendMode = .add
            nebula.zPosition = 0

            // langsames „Atmen“
            let pulse = SKAction.sequence([
                SKAction.group([
                    SKAction.fadeAlpha(to: 0.20, duration: 3.0),
                    SKAction.scale(to: scale * CGFloat.random(in: 0.97...1.03), duration: 3.0)
                ]),
                SKAction.group([
                    SKAction.fadeAlpha(to: 0.32, duration: 3.0),
                    SKAction.scale(to: scale, duration: 3.0)
                ])
            ])
            nebula.run(.repeatForever(pulse))

            // ganz langsame Eigenrotation
            let rotAngle = CGFloat.random(in: -0.15...0.15)
            let rotDur   = TimeInterval.random(in: 20.0...35.0)
            let rotate   = SKAction.rotate(byAngle: rotAngle, duration: rotDur)
            nebula.run(.repeatForever(rotate))

            container.addChild(nebula)
        }

        // Startposition: neutral in der Mitte
        container.position = .zero
    }
    
    /// Verschiebt den Nebel etwas langsamer als die Kamera → Parallax-Effekt
    func updateNebulaParallax() {
        guard let cam = camera, let nebulaLayer = nebulaLayer else { return }

        // Szenen-Mitte als Referenz
        let center = CGPoint(x: size.width / 2, y: size.height / 2)

        let dx = cam.position.x - center.x
        let dy = cam.position.y - center.y

        // (1 - factor): wie stark der Nebel entgegenläuft
        let compensation: CGFloat = 1.0 - nebulaParallaxFactor

        nebulaLayer.position = CGPoint(
            x: -dx * compensation,
            y: -dy * compensation
        )
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
