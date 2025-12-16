//
//  BossHUD.swift
//  SpaceGame
//

import SpriteKit

extension GameScene {

    // MARK: - Boss HUD

    func setupBossHUD() {
        teardownBossHUD()

        // --- Layout: orientiert sich an Player HP Bar ---
        let playerHPBg = hudNode.childNode(withName: "playerHPBackground") as? SKSpriteNode

        // Fallback etwas unterhalb Screen-Top
        let topYFallback = size.height / 2 - 70
        let baseTopY = playerHPBg?.position.y ?? topYFallback

        // Boss HUD sitzt UNTER Player HP
        let bossBarY = baseTopY - 26

        // ✅ Klein + elegant, device-stabil
        let isPortrait = size.height > size.width
        let barWidth: CGFloat = min(size.width * (isPortrait ? 0.52 : 0.42), 260)  // kompakt
        let barHeight: CGFloat = isPortrait ? 10 : 8
        let corner: CGFloat = barHeight / 2

        let xLeft = -barWidth / 2
        let yTop  = bossBarY

        // --- Background Bar ---
        let bg = SKShapeNode(rect: CGRect(x: xLeft, y: yTop, width: barWidth, height: barHeight), cornerRadius: corner)
        bg.fillColor = SKColor(white: 0.0, alpha: 0.28)
        bg.strokeColor = SKColor(white: 1.0, alpha: 0.16)
        bg.lineWidth = 1.5
        bg.zPosition = 240

        // --- Fill Bar ---
        let fill = SKShapeNode(rect: CGRect(x: xLeft, y: yTop, width: barWidth, height: barHeight), cornerRadius: corner)
        fill.fillColor = .red
        fill.strokeColor = .clear
        fill.zPosition = 241

        // ✅ Boss Name IN der Bar
        let name = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        name.text = level.config.bossName ?? "BOSS"
        name.fontColor = SKColor(white: 1.0, alpha: 0.88)
        name.fontSize = isPortrait ? 11 : 10
        name.horizontalAlignmentMode = .center
        name.verticalAlignmentMode = .center
        name.position = CGPoint(x: 0, y: yTop + barHeight / 2)
        name.zPosition = 242

        // --- Phase Tag (unter der Bar, Capsule) ---
        let phase = SKLabelNode(fontNamed: "AvenirNext-Bold")
        phase.text = "PHASE 1"
        phase.fontSize = isPortrait ? 13 : 12
        phase.fontColor = .yellow
        phase.horizontalAlignmentMode = .center
        phase.verticalAlignmentMode = .center
        phase.zPosition = 242

        let phaseBgSize = CGSize(width: isPortrait ? 128 : 120, height: isPortrait ? 26 : 24)
        let phaseBg = SKShapeNode(rectOf: phaseBgSize, cornerRadius: phaseBgSize.height / 2)
        phaseBg.name = "bossPhaseBg"
        phaseBg.fillColor = SKColor(white: 0.0, alpha: 0.40)
        phaseBg.strokeColor = SKColor(white: 1.0, alpha: 0.12)
        phaseBg.lineWidth = 1.5
        phaseBg.zPosition = 241

        let phaseY = yTop - (isPortrait ? 18 : 16)
        phase.position = CGPoint(x: 0, y: phaseY)
        phaseBg.position = phase.position

        // Add to HUD
        hudNode.addChild(bg)
        hudNode.addChild(fill)
        hudNode.addChild(name)
        hudNode.addChild(phaseBg)
        hudNode.addChild(phase)

        bossHealthBarBg = bg
        bossHealthBarFill = fill
        bossHealthLabel = name          // <- Name sitzt jetzt in der Bar
        bossPhaseLabel = phase

        updateBossHUD()
    }

    func updateBossHUD() {
        guard let b = boss,
              let hp = b.userData?["bossHP"] as? Int,
              let maxHP = b.userData?["bossMaxHP"] as? Int,
              let fill = bossHealthBarFill,
              let bg = bossHealthBarBg
        else { return }

        let pct = max(0, min(1, CGFloat(hp) / CGFloat(maxHP)))

        let bounds = bg.path?.boundingBox ?? CGRect(x: -130, y: 0, width: 260, height: 8)
        let barWidth = bounds.width
        let barHeight = bounds.height
        let xLeft = bounds.minX
        let yTop = bounds.minY
        let corner: CGFloat = barHeight / 2

        fill.path = CGPath(
            roundedRect: CGRect(x: xLeft, y: yTop, width: barWidth * pct, height: barHeight),
            cornerWidth: corner,
            cornerHeight: corner,
            transform: nil
        )

        if let phaseLabel = bossPhaseLabel {
            switch bossPhase {
            case .phase1: phaseLabel.text = "PHASE 1"
            case .phase2: phaseLabel.text = "PHASE 2"
            case .phase3: phaseLabel.text = "PHASE 3"
            case .dead:   phaseLabel.text = "DEFEATED"
            }
        }
    }

    func teardownBossHUD() {
        bossHealthBarBg?.removeFromParent()
        bossHealthBarFill?.removeFromParent()
        bossHealthLabel?.removeFromParent()
        bossPhaseLabel?.removeFromParent()
        hudNode.childNode(withName: "bossPhaseBg")?.removeFromParent()

        bossHealthBarBg = nil
        bossHealthBarFill = nil
        bossHealthLabel = nil
        bossPhaseLabel = nil
    }

    func relayoutBossHUD() {
        guard boss != nil else { return }

        // Falls HUD fehlt -> neu aufbauen
        if bossHealthBarBg == nil || bossHealthBarFill == nil || bossHealthLabel == nil || bossPhaseLabel == nil {
            setupBossHUD()
            return
        }

        guard let playerHPBg = hudNode.childNode(withName: "playerHPBackground") as? SKSpriteNode,
              let bg = bossHealthBarBg,
              let fill = bossHealthBarFill,
              let name = bossHealthLabel,
              let phase = bossPhaseLabel,
              let phaseBg = hudNode.childNode(withName: "bossPhaseBg") as? SKShapeNode
        else { return }

        let baseTopY = playerHPBg.position.y
        let bossBarY = baseTopY - 26

        let isPortrait = size.height > size.width
        let barWidth: CGFloat = min(size.width * (isPortrait ? 0.52 : 0.42), 260)
        let barHeight: CGFloat = isPortrait ? 10 : 8
        let corner: CGFloat = barHeight / 2

        let xLeft = -barWidth / 2
        let yTop  = bossBarY

        bg.path = CGPath(
            roundedRect: CGRect(x: xLeft, y: yTop, width: barWidth, height: barHeight),
            cornerWidth: corner,
            cornerHeight: corner,
            transform: nil
        )

        // Fill wird gleich in updateBossHUD() korrekt auf pct gesetzt
        fill.path = CGPath(
            roundedRect: CGRect(x: xLeft, y: yTop, width: barWidth, height: barHeight),
            cornerWidth: corner,
            cornerHeight: corner,
            transform: nil
        )

        // ✅ Name sitzt IN der Bar
        name.fontSize = isPortrait ? 11 : 10
        name.position = CGPoint(x: 0, y: yTop + barHeight / 2)

        // Phase Capsule
        phase.fontSize = isPortrait ? 13 : 12
        let phaseY = yTop - (isPortrait ? 18 : 16)
        phase.position = CGPoint(x: 0, y: phaseY)
        phaseBg.position = phase.position

        updateBossHUD()
    }
}
