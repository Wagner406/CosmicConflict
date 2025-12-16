//
//  HUD.swift
//  SpaceGame
//

import SpriteKit

extension GameScene {

    // MARK: - HUD Setup (Player)

    func setupHUD() {
        cameraNode.addChild(hudNode)

        // Falls HUD schon existiert -> aufräumen (optional, aber sauber)
        hudNode.removeAllChildren()
        playerHealthBar = nil
        powerUpLabel = nil
        roundLabel = nil

        // --- Layout ---
        let isLandscape = size.width > size.height

        // SafeArea (wichtig für Notch / Dynamic Island)
        let safeTop = view?.safeAreaInsets.top ?? 0

        // Top-Abstand: Landscape etwas näher an den Rand
        let topPadding: CGFloat = (isLandscape ? 18 : 28) + safeTop

        // Eleganter: schmaler, dünner, aber mit Clamp
        let barWidth: CGFloat  = min(size.width * (isLandscape ? 0.42 : 0.48), 420)
        let barHeight: CGFloat = 10

        let topY = size.height / 2 - topPadding

        // --- HP Background ---
        let bg = SKSpriteNode(
            color: SKColor(white: 0.0, alpha: 1.0),
            size: CGSize(width: barWidth, height: barHeight)
        )
        bg.alpha = 0.28
        bg.position = CGPoint(x: 0, y: topY)
        bg.zPosition = 200
        bg.name = "playerHPBackground"

        // --- HP Fill ---
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

        // ROUND LABEL (zentral IN der HP-Bar)
        let round = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        round.name = "roundLabel"
        round.fontSize = 10
        round.fontColor = .yellow
        round.alpha = 0.85
        round.horizontalAlignmentMode = .center
        round.verticalAlignmentMode = .center
        round.zPosition = bg.zPosition + 5

        // als Child der BG-Bar -> bleibt bei Resize/Rotation korrekt
        round.position = .zero
        round.text = "ROUND \(currentRound)"
        bg.addChild(round)
        roundLabel = round

        // --- PowerUp label (rechts oben, aligned zur Bar) ---
        let powerLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        powerLabel.fontSize = 18
        powerLabel.fontColor = .cyan
        powerLabel.horizontalAlignmentMode = .right
        powerLabel.verticalAlignmentMode = .center

        let margin: CGFloat = 18
        powerLabel.position = CGPoint(
            x: size.width / 2 - margin,
            y: topY
        )
        powerLabel.zPosition = 210
        powerLabel.text = ""
        powerLabel.isHidden = true
        hudNode.addChild(powerLabel)
        powerUpLabel = powerLabel
    }

    // MARK: - HUD Updates

    func updatePlayerHealthBar() {
        guard let bar = playerHealthBar else { return }

        let maxHP = max(1, playerMaxHP)
        let fraction = max(0, min(1, CGFloat(playerHP) / CGFloat(maxHP)))
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
        roundLabel?.text = "ROUND \(currentRound)"
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

    func showLevelCompleteBanner() {
        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = "LEVEL COMPLETE"
        label.fontSize = 32
        label.fontColor = .yellow
        label.zPosition = 300
        label.position = CGPoint(x: 0, y: 0)
        label.alpha = 0

        hudNode.addChild(label)

        let fadeIn  = SKAction.fadeIn(withDuration: 0.3)
        let wait    = SKAction.wait(forDuration: 1.2)
        let fadeOut = SKAction.fadeOut(withDuration: 0.3)
        let remove  = SKAction.removeFromParent()

        label.run(.sequence([fadeIn, wait, fadeOut, remove]))
    }

    // MARK: - Dynamic Relayout (Rotation / Resize)

    func relayoutHUD() {
        guard let playerBg = hudNode.childNode(withName: "playerHPBackground") as? SKSpriteNode,
              let playerBar = playerBg.childNode(withName: "playerHPBar") as? SKSpriteNode
        else { return }

        let isLandscape = size.width > size.height
        let safeTop = view?.safeAreaInsets.top ?? 0
        let topPadding: CGFloat = (isLandscape ? 18 : 28) + safeTop

        let barWidth: CGFloat  = min(size.width * (isLandscape ? 0.42 : 0.48), 420)
        let barHeight: CGFloat = 10

        let topY = size.height / 2 - topPadding

        playerBg.size = CGSize(width: barWidth, height: barHeight)
        playerBg.position = CGPoint(x: 0, y: topY)

        playerBar.size = CGSize(width: barWidth, height: barHeight)
        playerBar.position = CGPoint(x: -barWidth / 2, y: 0)

        let margin: CGFloat = 18
        powerUpLabel?.position = CGPoint(x: size.width / 2 - margin, y: topY)

        // Boss HUD folgt mit (falls aktiv)
        relayoutBossHUD()
    }
}
