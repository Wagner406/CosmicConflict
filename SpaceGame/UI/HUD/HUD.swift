//
//  HUD.swift
//  SpaceGame
//

import SpriteKit

extension GameScene {

    // MARK: - HUD Setup (Player)

    func setupHUD() {
        cameraNode.addChild(hudNode)

        // Falls HUD schon existiert -> aufräumen
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
        round.fontColor = .white   // <- Farbe hier ändern
        round.alpha = 0.85
        round.horizontalAlignmentMode = .center
        round.verticalAlignmentMode = .center
        round.zPosition = bg.zPosition + 5

        // als Child der BG-Bar -> bleibt bei Resize/Rotation korrekt
        round.position = .zero
        round.text = "ROUND \(currentRound)"
        bg.addChild(round)
        roundLabel = round

        // --- Pause Button (oben links, gleiche Höhe wie HP-Bar) ---
        let pause = SKLabelNode(fontNamed: "AvenirNext-Bold")
        pause.name = "pauseButton"
        pause.text = "⏸"
        pause.fontSize = 18
        pause.fontColor = .white
        pause.alpha = 0.85
        pause.horizontalAlignmentMode = .center
        pause.verticalAlignmentMode = .center
        pause.zPosition = 220

        let pauseX = -size.width / 2 + 26
        pause.position = CGPoint(x: pauseX, y: topY)

        hudNode.addChild(pause)

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

        // Pause Button mitziehen
        if let pause = hudNode.childNode(withName: "pauseButton") {
            pause.position = CGPoint(x: -size.width / 2 + 26, y: topY)
        }

        // Boss HUD folgt mit (falls aktiv)
        relayoutBossHUD()
    }
    
    // MARK: - Pause Overlay (UI)

    func hud_buildPauseOverlayIfNeeded() {
        if pauseOverlayDim != nil { return }

        // Dim background (full screen, camera-space)
        let dim = SKSpriteNode(color: .black, size: CGSize(width: size.width, height: size.height))
        dim.alpha = 0.55
        dim.zPosition = 980
        dim.name = "pauseOverlayDim"
        dim.position = .zero
        dim.isHidden = true
        hudNode.addChild(dim)
        pauseOverlayDim = dim

        // Panel
        let panelW: CGFloat = min(size.width * 0.72, 340)
        let panelH: CGFloat = min(size.height * 0.34, 240)

        let panel = SKShapeNode(rectOf: CGSize(width: panelW, height: panelH), cornerRadius: 18)
        panel.fillColor = SKColor(white: 0.05, alpha: 0.92)
        panel.strokeColor = SKColor(white: 1.0, alpha: 0.12)
        panel.lineWidth = 2
        panel.zPosition = 981
        panel.position = .zero
        panel.name = "pauseOverlayPanel"
        panel.isHidden = true
        hudNode.addChild(panel)
        pauseOverlayPanel = panel

        // Title
        let title = SKLabelNode(fontNamed: "AvenirNext-Bold")
        title.text = "PAUSED"
        title.fontSize = 18
        title.fontColor = .white
        title.alpha = 0.95
        title.horizontalAlignmentMode = .center
        title.verticalAlignmentMode = .center
        title.position = CGPoint(x: 0, y: panelH/2 - 42)
        title.zPosition = 982
        title.name = "pauseTitle"
        panel.addChild(title)

        func makeButton(name: String, text: String, y: CGFloat) -> SKShapeNode {
            let bw: CGFloat = min(panelW * 0.78, 260)
            let bh: CGFloat = 40

            let btn = SKShapeNode(rectOf: CGSize(width: bw, height: bh), cornerRadius: 14)
            btn.name = name
            btn.fillColor = SKColor(white: 1.0, alpha: 0.10)
            btn.strokeColor = SKColor(white: 1.0, alpha: 0.16)
            btn.lineWidth = 2
            btn.zPosition = 982
            btn.position = CGPoint(x: 0, y: y)

            let lbl = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
            lbl.text = text
            lbl.fontSize = 14
            lbl.fontColor = .white
            lbl.alpha = 0.95
            lbl.horizontalAlignmentMode = .center
            lbl.verticalAlignmentMode = .center
            lbl.position = .zero
            lbl.zPosition = 983
            lbl.name = "\(name)_label"
            btn.addChild(lbl)

            return btn
        }

        let resumeBtn = makeButton(name: "pauseResumeButton", text: "Resume", y: 10)
        let menuBtn   = makeButton(name: "pauseMenuButton", text: "Main Menu", y: -46)

        panel.addChild(resumeBtn)
        panel.addChild(menuBtn)

        pauseResumeButton = resumeBtn
        pauseMenuButton = menuBtn
    }

    func hud_showPauseOverlay() {
        hud_buildPauseOverlayIfNeeded()

        pauseOverlayDim?.isHidden = false
        pauseOverlayPanel?.isHidden = false

        pauseOverlayPanel?.removeAllActions()
        pauseOverlayPanel?.setScale(0.98)
        pauseOverlayPanel?.alpha = 0.0
        pauseOverlayPanel?.run(.group([
            .fadeIn(withDuration: 0.12),
            .scale(to: 1.0, duration: 0.12)
        ]))
    }

    func hud_hidePauseOverlay() {
        pauseOverlayDim?.isHidden = true
        pauseOverlayPanel?.isHidden = true
    }

    // ✅ HUD tap routing (Pause + Overlay Buttons)
    func hudHandleTap(at scenePoint: CGPoint) -> Bool {

        // Pause button (⏸)
        if let pauseBtn = hudNode.childNode(withName: "pauseButton") {
            let pHud = convert(scenePoint, to: hudNode)
            if pauseBtn.contains(pHud) {
                pauseGame()
                return true
            }
        }

        // Overlay only if visible
        guard isGamePaused else { return false }

        // Tap in panel space
        if let panel = pauseOverlayPanel, panel.isHidden == false {
            let pInPanel = convert(scenePoint, to: panel)

            if let resume = pauseResumeButton, resume.contains(pInPanel) {
                resumeGame()
                return true
            }

            if let menu = pauseMenuButton, menu.contains(pInPanel) {
                exitToMainMenu()
                return true
            }
        }

        // Tap outside (dim) => resume
        if let dim = pauseOverlayDim, dim.isHidden == false {
            let pHud = convert(scenePoint, to: hudNode)
            if dim.contains(pHud) {
                resumeGame()
                return true
            }
        }

        return false
    }
}
