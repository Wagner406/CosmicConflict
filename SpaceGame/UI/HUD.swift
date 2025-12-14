//
//  HUD.swift
//  SpaceGame
//

import SpriteKit

extension GameScene {

    // MARK: - HUD Setup (Player)

    func setupHUD() {
        cameraNode.addChild(hudNode)

        let barWidth = size.width * 0.4
        let barHeight: CGFloat = 16

        let bg = SKSpriteNode(
            color: .darkGray,
            size: CGSize(width: barWidth, height: barHeight)
        )
        bg.alpha = 0.7
        bg.position = CGPoint(x: 0, y: size.height / 2 - barHeight * 5)
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

        // Round label (oben links)
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

        // PowerUp label (oben rechts)
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

    // MARK: - HUD Updates

    func updatePlayerHealthBar() {
        guard let bar = playerHealthBar else { return }

        // ✅ Schutz gegen Division by Zero
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
}
