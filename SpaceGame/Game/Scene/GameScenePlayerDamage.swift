//
//  GameScene+PlayerDamage.swift
//  SpaceGame
//

import SpriteKit

extension GameScene {

    // MARK: - Player Damage

    func applyDamageToPlayer(amount: Int) {
        if isShieldActive { return }

        if isPlayerInvulnerable &&
            (currentTimeForCollisions - playerLastHitTime) < playerHitCooldown {
            return
        }

        playerLastHitTime = currentTimeForCollisions
        isPlayerInvulnerable = true

        playerHP = max(0, playerHP - amount)
        updatePlayerHealthBar()
        
        // GodMode: kein Sterben
        if isGodModeEnabled {
            return
        }

        if playerHP <= 0 {
            killPlayer()
            return
        }
        
        startPlayerInvulnerabilityBlink()
    }

    func startPlayerInvulnerabilityBlink() {
        guard let ship = playerShip else { return }

        ship.removeAction(forKey: "invulnBlink")

        let fadeOut = SKAction.fadeAlpha(to: 0.3, duration: 0.1)
        let fadeIn  = SKAction.fadeAlpha(to: 1.0, duration: 0.1)
        let blink   = SKAction.sequence([fadeOut, fadeIn])
        let repeatBlink = SKAction.repeat(blink, count: 5)

        let end = SKAction.run { [weak self] in
            self?.isPlayerInvulnerable = false
            self?.playerShip.alpha = 1.0
        }

        ship.run(.sequence([repeatBlink, end]), withKey: "invulnBlink")
    }
}
