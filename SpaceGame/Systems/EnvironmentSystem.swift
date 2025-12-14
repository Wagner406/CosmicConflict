import SpriteKit

final class EnvironmentSystem {

    private enum Name {
        static let background = "Env.Background"   // ✅ NEU
        static let starField  = "Env.StarField"
        static let toxicGas   = "Env.ToxicGas"
        static let nebula     = "Env.Nebula"
    }

    private let nebulaParallaxFactor: CGFloat = 0.35
    private var nextShootingStarTime: TimeInterval = 0

    func buildForCurrentLevel(in scene: GameScene) {
        setupBackground(in: scene)                 // ✅ NEU (als erstes)
        spawnLevelStars(in: scene)
        setupToxicGasClouds(in: scene)
        setupParallaxNebulaLayer(in: scene)
        nextShootingStarTime = 0
    }

    func update(in scene: GameScene, currentTime: TimeInterval) {
        spawnShootingStar(in: scene, currentTime: currentTime)
        updateNebulaParallax(in: scene)
    }

    // MARK: - Background (Space + Fog of War)

    private func setupBackground(in scene: GameScene) {
        // falls beim Restart nochmal gebaut wird:
        scene.childNode(withName: Name.background)?.removeFromParent()

        let texture = SKTexture(imageNamed: "test")

        let bg: SKSpriteNode
        if texture.size() != .zero {
            bg = SKSpriteNode(texture: texture)

            let baseScale = max(scene.size.width  / texture.size().width,
                                scene.size.height / texture.size().height)
            bg.setScale(baseScale * 5.0)
        } else {
            bg = SKSpriteNode(
                color: .black,
                size: CGSize(width: scene.size.width * 3,
                             height: scene.size.height * 3)
            )
        }

        bg.name = Name.background
        bg.position = CGPoint(x: scene.size.width / 2, y: scene.size.height / 2)
        bg.zPosition = -100

        // leichter “Fog of War” / Abdunkeln
        bg.color = .black
        bg.colorBlendFactor = 0.25

        scene.addChild(bg)

        // optional: wenn du die Property in GameScene noch nutzt
        scene.spaceBackground = bg
    }

    // MARK: Stars (inside levelNode)

    private func spawnLevelStars(in scene: GameScene) {
        guard let levelNode = scene.levelNode else { return }

        levelNode.childNode(withName: Name.starField)?.removeFromParent()

        let starContainer = SKNode()
        starContainer.name = Name.starField
        starContainer.zPosition = 4
        levelNode.addChild(starContainer)

        let levelSize = levelNode.frame.size
        let width  = levelSize.width
        let height = levelSize.height
        let halfW = width / 2
        let halfH = height / 2

        let area = width * height
        let baseDensity: CGFloat = 1.0 / 25000.0
        var starCount = Int(area * baseDensity)
        starCount = max(140, min(starCount, 360))

        for _ in 0..<starCount {
            let size = CGFloat.random(in: 3.0...6.0)

            let star = SKShapeNode(circleOfRadius: size / 2)
            star.fillColor = .white
            star.strokeColor = .clear
            star.glowWidth = size * 1.3
            star.lineWidth = 0

            let x = CGFloat.random(in: -halfW ... halfW)
            let y = CGFloat.random(in: -halfH ... halfH)
            star.position = CGPoint(x: x, y: y)

            if Bool.random() {
                let minA: CGFloat = 0.4
                let pulse = SKAction.sequence([
                    .fadeAlpha(to: minA, duration: Double.random(in: 0.5...0.9)),
                    .fadeAlpha(to: 1.0, duration: Double.random(in: 0.5...0.9))
                ])
                star.run(.repeatForever(pulse))
            } else {
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

    private func spawnShootingStar(in scene: GameScene, currentTime: TimeInterval) {
        guard let levelNode = scene.levelNode,
              let starContainer = levelNode.childNode(withName: Name.starField)
        else { return }

        if currentTime < nextShootingStarTime { return }
        nextShootingStarTime = currentTime + TimeInterval.random(in: 3.0...10.0)

        let levelSize = levelNode.frame.size
        let halfW = levelSize.width / 2
        let halfH = levelSize.height / 2

        let length    = CGFloat.random(in: 40...80)
        let thickness = CGFloat.random(in: 2...4)

        let star = SKSpriteNode(color: .white, size: CGSize(width: length, height: thickness))
        star.alpha = 1.0
        star.blendMode = .add
        star.zPosition = 1

        let fromLeft = Bool.random()
        let startX = fromLeft ? -halfW - 150 : halfW + 150
        let startY = CGFloat.random(in: 0 ... halfH)
        let endX   = fromLeft ?  halfW + 250 : -halfW - 250
        let endY   = CGFloat.random(in: -halfH ... 0)

        let startPos = CGPoint(x: startX, y: startY)
        let endPos   = CGPoint(x: endX, y: endY)
        star.position = startPos
        star.zRotation = atan2(endY - startY, endX - startX)

        let distance = hypot(endX - startX, endY - startY)
        let speed: CGFloat = 1300
        let duration = TimeInterval(distance / speed)

        starContainer.addChild(star)
        star.run(.sequence([
            .group([.move(to: endPos, duration: duration), .fadeOut(withDuration: duration)]),
            .removeFromParent()
        ]))
    }

    // MARK: Toxic Gas (scene space)

    private func setupToxicGasClouds(in scene: GameScene) {
        guard let levelNode = scene.levelNode else { return }

        scene.childNode(withName: Name.toxicGas)?.removeFromParent()

        let gasContainer = SKNode()
        gasContainer.name = Name.toxicGas
        gasContainer.zPosition = 2
        scene.addChild(gasContainer)

        let levelFrame = levelNode.frame

        let margin: CGFloat = 100
        let extraSpread: CGFloat = 50
        let rowCount = 3
        let rowSpacing: CGFloat = 200

        let textures: [SKTexture] = [
            SKTexture(imageNamed: "ToxicCloud1"),
            SKTexture(imageNamed: "ToxicCloud2"),
            SKTexture(imageNamed: "ToxicCloud3")
        ].filter { $0.size() != .zero }
        if textures.isEmpty { return }

        func addCloud(at position: CGPoint, bigger: Bool = false) {
            guard let tex = textures.randomElement() else { return }
            let cloud = SKSpriteNode(texture: tex)

            let base = min(levelFrame.width, levelFrame.height)
            let baseFactor: ClosedRange<CGFloat> = bigger ? 0.45...0.60 : 0.32...0.45
            let desiredWidth = base * CGFloat.random(in: baseFactor)
            cloud.setScale(desiredWidth / tex.size().width)

            cloud.position = position
            cloud.alpha = 0.85
            cloud.color = SKColor(red: 0.1, green: 1.0, blue: 0.3, alpha: 1.0)
            cloud.colorBlendFactor = 0.9
            cloud.blendMode = .screen

            let breathe = SKAction.sequence([
                .group([.fadeAlpha(to: 0.6, duration: 1.2),
                        .scale(to: CGFloat.random(in: 0.96...1.04), duration: 1.2)]),
                .group([.fadeAlpha(to: 0.9, duration: 1.2),
                        .scale(to: 1.0, duration: 1.2)])
            ])
            cloud.run(.repeatForever(breathe))

            let maxDrift: CGFloat = 18
            let dx = CGFloat.random(in: -maxDrift...maxDrift)
            cloud.run(.repeatForever(.sequence([
                .moveBy(x: dx, y: 0, duration: 3.0),
                .moveBy(x: -dx, y: 0, duration: 3.0)
            ])))

            gasContainer.addChild(cloud)
        }

        let cloudsPerSide = 25

        for row in 0..<rowCount {
            let y = levelFrame.maxY + margin + CGFloat(row) * rowSpacing
            for i in 0..<cloudsPerSide {
                let t = (CGFloat(i) + 0.5) / CGFloat(cloudsPerSide)
                let x = levelFrame.minX + t * levelFrame.width
                addCloud(at: CGPoint(x: x, y: y + CGFloat.random(in: 0...extraSpread)))
            }
        }

        for row in 0..<rowCount {
            let y = levelFrame.minY - margin - CGFloat(row) * rowSpacing
            for i in 0..<cloudsPerSide {
                let t = (CGFloat(i) + 0.5) / CGFloat(cloudsPerSide)
                let x = levelFrame.minX + t * levelFrame.width
                addCloud(at: CGPoint(x: x, y: y - CGFloat.random(in: 0...extraSpread)))
            }
        }

        for row in 0..<rowCount {
            let x = levelFrame.minX - margin - CGFloat(row) * rowSpacing
            for i in 0..<cloudsPerSide {
                let t = (CGFloat(i) + 0.5) / CGFloat(cloudsPerSide)
                let y = levelFrame.minY + t * levelFrame.height
                addCloud(at: CGPoint(x: x - CGFloat.random(in: 0...extraSpread), y: y))
            }
        }

        for row in 0..<rowCount {
            let x = levelFrame.maxX + margin + CGFloat(row) * rowSpacing
            for i in 0..<cloudsPerSide {
                let t = (CGFloat(i) + 0.5) / CGFloat(cloudsPerSide)
                let y = levelFrame.minY + t * levelFrame.height
                addCloud(at: CGPoint(x: x + CGFloat.random(in: 0...extraSpread), y: y))
            }
        }

        let cornerOffset = margin + CGFloat(rowCount) * rowSpacing + extraSpread
        addCloud(at: CGPoint(x: levelFrame.minX - cornerOffset, y: levelFrame.maxY + cornerOffset), bigger: true)
        addCloud(at: CGPoint(x: levelFrame.maxX + cornerOffset, y: levelFrame.maxY + cornerOffset), bigger: true)
        addCloud(at: CGPoint(x: levelFrame.minX - cornerOffset, y: levelFrame.minY - cornerOffset), bigger: true)
        addCloud(at: CGPoint(x: levelFrame.maxX + cornerOffset, y: levelFrame.minY - cornerOffset), bigger: true)

        let cornerLayers = 3
        let cornerSpacing: CGFloat = 90

        func addCornerCluster(baseX: CGFloat, baseY: CGFloat) {
            for layer in 0..<cornerLayers {
                let offset = CGFloat(layer) * cornerSpacing
                let jitterX = CGFloat.random(in: -40...40)
                let jitterY = CGFloat.random(in: -40...40)

                addCloud(at: CGPoint(x: baseX + jitterX + offset, y: baseY + jitterY + offset))
                addCloud(at: CGPoint(x: baseX + jitterX - offset, y: baseY + jitterY + offset))
                addCloud(at: CGPoint(x: baseX + jitterX + offset, y: baseY + jitterY - offset))
                addCloud(at: CGPoint(x: baseX + jitterX - offset, y: baseY + jitterY - offset))
            }
        }

        addCornerCluster(baseX: levelFrame.minX - margin - extraSpread, baseY: levelFrame.maxY + margin + extraSpread)
        addCornerCluster(baseX: levelFrame.maxX + margin + extraSpread, baseY: levelFrame.maxY + margin + extraSpread)
        addCornerCluster(baseX: levelFrame.minX - margin - extraSpread, baseY: levelFrame.minY - margin - extraSpread)
        addCornerCluster(baseX: levelFrame.maxX + margin + extraSpread, baseY: levelFrame.minY - margin - extraSpread)
    }

    // MARK: Nebula

    private func setupParallaxNebulaLayer(in scene: GameScene) {
        scene.childNode(withName: Name.nebula)?.removeFromParent()
        guard let levelNode = scene.levelNode else { return }

        let container = SKNode()
        container.name = Name.nebula
        container.zPosition = 3
        scene.addChild(container)

        let levelFrame = levelNode.frame
        let baseArea = levelFrame.width * levelFrame.height

        let textures: [SKTexture] = [
            SKTexture(imageNamed: "ToxicCloud1"),
            SKTexture(imageNamed: "ToxicCloud2"),
            SKTexture(imageNamed: "ToxicCloud3")
        ].filter { $0.size() != .zero }
        if textures.isEmpty { return }

        let density: CGFloat = 1.0 / 350000.0
        var count = Int(baseArea * density)
        count = max(5, min(count, 10))

        let baseSize = min(levelFrame.width, levelFrame.height)

        for _ in 0..<count {
            guard let tex = textures.randomElement() else { continue }
            let nebula = SKSpriteNode(texture: tex)

            let desiredWidth = baseSize * CGFloat.random(in: 0.6...0.9)
            let scale = desiredWidth / tex.size().width
            nebula.setScale(scale)

            nebula.position = CGPoint(
                x: CGFloat.random(in: levelFrame.minX ... levelFrame.maxX),
                y: CGFloat.random(in: levelFrame.minY ... levelFrame.maxY)
            )

            nebula.color = SKColor(
                red: CGFloat.random(in: 0.3...0.5),
                green: CGFloat.random(in: 0.5...0.8),
                blue: 1.0,
                alpha: 1.0
            )
            nebula.colorBlendFactor = 0.85
            nebula.alpha = 0.28
            nebula.blendMode = .add

            let pulse = SKAction.sequence([
                .group([.fadeAlpha(to: 0.20, duration: 3.0),
                        .scale(to: scale * CGFloat.random(in: 0.97...1.03), duration: 3.0)]),
                .group([.fadeAlpha(to: 0.32, duration: 3.0),
                        .scale(to: scale, duration: 3.0)])
            ])
            nebula.run(.repeatForever(pulse))

            let rotAngle = CGFloat.random(in: -0.15...0.15)
            let rotDur   = TimeInterval.random(in: 20.0...35.0)
            nebula.run(.repeatForever(.rotate(byAngle: rotAngle, duration: rotDur)))

            container.addChild(nebula)
        }
    }

    private func updateNebulaParallax(in scene: GameScene) {
        guard let cam = scene.camera,
              let nebulaLayer = scene.childNode(withName: Name.nebula)
        else { return }

        let center = CGPoint(x: scene.size.width / 2, y: scene.size.height / 2)
        let dx = cam.position.x - center.x
        let dy = cam.position.y - center.y

        let compensation: CGFloat = 1.0 - nebulaParallaxFactor
        nebulaLayer.position = CGPoint(x: -dx * compensation, y: -dy * compensation)
    }
}
