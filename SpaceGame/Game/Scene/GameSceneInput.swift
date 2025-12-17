//
//  GameScene+Input.swift
//  SpaceGame
//

import SpriteKit

extension GameScene {

    // MARK: - Touch

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        let p = t.location(in: self)

        // HUD first (Pause Button + Overlay Buttons)
        if hudHandleTap(at: p) { return }

        // Wenn pausiert: kein Gameplay
        if isGamePaused { return }

        shoot()
    }

    // MARK: - SwiftUI Controls

    func startMoving(_ direction: ShipDirection) {
        currentDirection = direction
    }

    func stopMoving(_ direction: ShipDirection) {
        if currentDirection == direction {
            currentDirection = nil
        }
    }
}
