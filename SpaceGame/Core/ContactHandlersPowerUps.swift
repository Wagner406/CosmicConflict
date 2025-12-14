//
//  ContactHandlersPowerUps.swift
//  SpaceGame
//

import SpriteKit

// MARK: - PowerUp Contacts

extension GameScene {

    func handlePlayerPicksPowerUp(powerUpBody: SKPhysicsBody) {
        guard let node = powerUpBody.node as? SKSpriteNode else { return }
        handlePowerUpPickup(node)
    }
}
