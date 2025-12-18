//
//  GameSceneGameOver.swift
//  SpaceGame
//
//  Created by Alexander Wagner on 18.12.25.
//

import SpriteKit

extension GameScene {

    func killPlayer() {
        guard !isPlayerDead else { return }
        isPlayerDead = true

        // Gameplay stoppen
        isLevelCompleted = true
        currentDirection = nil

        // Optional: alles pausieren außer HUD/Kamera (ohne Pause-Overlay)
        for child in children {
            if child === cameraNode { continue }
            child.isPaused = true
        }
        physicsWorld.speed = 0

        // Explosion + Sound
        if let ship = playerShip {
            vfx.playEnemyShipExplosion(
                at: ship.position,
                zPosition: ship.zPosition + 10,
                desiredWidth: max(ship.size.width, ship.size.height) * 1.6
            )
            SoundManager.shared.playRandomExplosion(in: self)

            ship.removeAllActions()
            ship.physicsBody = nil
            ship.run(.sequence([.fadeOut(withDuration: 0.15), .removeFromParent()]))
        }

        showGameOverBanner()

        // Nach kurzer Zeit zurück ins Menü
        run(.sequence([
            .wait(forDuration: 2.0),
            .run { [weak self] in
                guard let self else { return }
                SoundManager.shared.stopMusic()
                self.onLevelCompleted?()
            }
        ]))
    }

    private func showGameOverBanner() {
        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = "GAME OVER"
        label.fontSize = 44
        label.fontColor = .red
        label.zPosition = 999
        label.position = CGPoint(x: 0, y: 0)
        label.alpha = 0

        hudNode.addChild(label)

        label.run(.sequence([
            .fadeIn(withDuration: 0.2),
            .wait(forDuration: 1.4),
            .fadeOut(withDuration: 0.2),
            .removeFromParent()
        ]))
    }
}
