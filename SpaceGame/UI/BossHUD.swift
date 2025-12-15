//
//  BossHUD.swift
//  SpaceGame
//

import SpriteKit

extension GameScene {

    // MARK: - Boss HUD

    func setupBossHUD() {
        // HUD vorher entfernt?
        teardownBossHUD()

        // --- Layout: orientiert sich an Player HP Bar ---
        // Player HP Background liegt in hudNode und heißt "playerHPBackground"
        let playerHPBg = hudNode.childNode(withName: "playerHPBackground") as? SKSpriteNode

        // Falls nicht gefunden: Fallback etwas unterhalb Screen-Top
        let topYFallback = size.height / 2 - 90
        let baseTopY = playerHPBg?.position.y ?? topYFallback

        // Boss HUD soll UNTER der Player HP Bar sitzen
        // (so bleibt Player HP immer an der besten Stelle)
        let bossBarY = baseTopY - 55

        // Dynamische Größen
        let barWidth: CGFloat = min(size.width * 0.62, 520)
        let barHeight: CGFloat = 16
        let corner: CGFloat = 6

        let xLeft = -barWidth / 2
        let yTop  = bossBarY

        // --- Background Bar ---
        let bg = SKShapeNode(rect: CGRect(x: xLeft, y: yTop, width: barWidth, height: barHeight), cornerRadius: corner)
        bg.fillColor = SKColor(white: 0.0, alpha: 0.35)
        bg.strokeColor = SKColor(white: 1.0, alpha: 0.20)
        bg.lineWidth = 2
        bg.zPosition = 240

        // --- Fill Bar ---
        let fill = SKShapeNode(rect: CGRect(x: xLeft, y: yTop, width: barWidth, height: barHeight), cornerRadius: corner)
        fill.fillColor = .red
        fill.strokeColor = .clear
        fill.zPosition = 241

        // --- Boss Name (über der Bar) ---
        let name = SKLabelNode(fontNamed: "AvenirNext-Bold")
        name.text = level.config.bossName ?? "BOSS"
        name.fontSize = 16
        name.fontColor = .white
        name.horizontalAlignmentMode = .center
        name.verticalAlignmentMode = .center
        name.position = CGPoint(x: 0, y: yTop + barHeight + 16)
        name.zPosition = 242

        // --- Phase Tag (unter der Bar, Capsule) ---
        let phase = SKLabelNode(fontNamed: "AvenirNext-Bold")
        phase.text = "PHASE 1"
        phase.fontSize = 20
        phase.fontColor = .yellow
        phase.horizontalAlignmentMode = .center
        phase.verticalAlignmentMode = .center
        phase.position = CGPoint(x: 0, y: yTop - 26)
        phase.zPosition = 242

        let phaseBgSize = CGSize(width: 170, height: 36)
        let phaseBg = SKShapeNode(rectOf: phaseBgSize, cornerRadius: 12)
        phaseBg.name = "bossPhaseBg"
        phaseBg.fillColor = SKColor(white: 0.0, alpha: 0.45)
        phaseBg.strokeColor = SKColor(white: 1.0, alpha: 0.14)
        phaseBg.lineWidth = 2
        phaseBg.position = phase.position
        phaseBg.zPosition = 241

        // Add to HUD
        hudNode.addChild(bg)
        hudNode.addChild(fill)
        hudNode.addChild(name)
        hudNode.addChild(phaseBg)
        hudNode.addChild(phase)

        bossHealthBarBg = bg
        bossHealthBarFill = fill
        bossHealthLabel = name
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

        // Bar-Geometrie aus BG ableiten (damit width immer korrekt ist)
        let bounds = bg.path?.boundingBox ?? CGRect(x: -180, y: 0, width: 360, height: 16)
        let barWidth = bounds.width
        let barHeight = bounds.height
        let xLeft = bounds.minX
        let yTop = bounds.minY
        let corner: CGFloat = 6

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
        guard boss != nil else { return } // nur wenn Boss-Level aktiv

        // Wenn BossHUD noch nicht existiert -> aufbauen
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
        let bossBarY = baseTopY - 55

        let barWidth: CGFloat = min(size.width * 0.62, 520)
        let barHeight: CGFloat = 16
        let corner: CGFloat = 6

        let xLeft = -barWidth / 2
        let yTop  = bossBarY

        bg.path = CGPath(roundedRect: CGRect(x: xLeft, y: yTop, width: barWidth, height: barHeight),
                         cornerWidth: corner, cornerHeight: corner, transform: nil)

        // Fill wird in updateBossHUD() korrekt auf pct gesetzt – wir setzen hier erstmal volle Breite,
        // dann updateBossHUD() aufrufen.
        fill.path = CGPath(roundedRect: CGRect(x: xLeft, y: yTop, width: barWidth, height: barHeight),
                           cornerWidth: corner, cornerHeight: corner, transform: nil)

        name.position = CGPoint(x: 0, y: yTop + barHeight + 16)
        phase.position = CGPoint(x: 0, y: yTop - 26)
        phaseBg.position = phase.position

        updateBossHUD()
    }
}
