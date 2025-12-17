//
//  GameScene+Pause.swift
//  SpaceGame
//

import SpriteKit

extension GameScene {

    // MARK: - Pause Logic

    func pauseGame() {
        guard !isGamePaused else { return }
        isGamePaused = true

        hud_showPauseOverlay()

        // Pause ALLES außer HUD/Kamera
        for child in children {
            if child === cameraNode { continue }
            child.isPaused = true
        }

        physicsWorld.speed = 0
    }

    func resumeGame() {
        guard isGamePaused else { return }
        isGamePaused = false

        hud_hidePauseOverlay()

        for child in children {
            if child === cameraNode { continue }
            child.isPaused = false
        }

        physicsWorld.speed = 1

        // verhindert DeltaTime-Spike nach Pause
        lastUpdateTime = 0
    }

    func exitToMainMenu() {
        SoundManager.shared.stopMusic()

        isGamePaused = false
        physicsWorld.speed = 1
        hud_hidePauseOverlay()

        onLevelCompleted?()
    }
}
