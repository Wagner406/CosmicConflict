//
//  PlayerDamageSystem.swift
//  SpaceGame
//

import SpriteKit

/// Handles player damage rules: shield check, hit cooldown, invulnerability blink.
struct PlayerDamageSystem {

    private(set) var isInvulnerable: Bool = false
    private(set) var lastHitTime: TimeInterval = 0

    mutating func reset() {
        isInvulnerable = false
        lastHitTime = 0
    }

    /// Applies damage if allowed. Updates HP and triggers blink.
    ///
    /// - Parameters:
    ///   - ship: player sprite
    ///   - amount: damage amount
    ///   - currentTime: currentTime from update()
    ///   - cooldown: hit cooldown in seconds
    ///   - isShieldActive: if true, damage is ignored
    ///   - playerHP: inout HP value to reduce
    ///   - onHPChanged: called after HP changes (e.g. update healthbar)
    mutating func applyDamage(
        to ship: SKSpriteNode,
        amount: Int,
        currentTime: TimeInterval,
        cooldown: TimeInterval,
        isShieldActive: Bool,
        playerHP: inout Int,
        onHPChanged: () -> Void
    ) {
        guard !isShieldActive else { return }

        if isInvulnerable && (currentTime - lastHitTime) < cooldown {
            return
        }

        lastHitTime = currentTime
        isInvulnerable = true

        playerHP = max(0, playerHP - amount)
        onHPChanged()

        startInvulnerabilityBlink(on: ship)
    }

    /// Ends invulnerability immediately (optional helper).
    mutating func clearInvulnerability(on ship: SKSpriteNode) {
        isInvulnerable = false
        ship.removeAction(forKey: "invulnBlink")
        ship.alpha = 1.0
    }

    // MARK: - Blink

    private func startInvulnerabilityBlink(on ship: SKSpriteNode) {
        ship.removeAction(forKey: "invulnBlink")

        let fadeOut = SKAction.fadeAlpha(to: 0.3, duration: 0.1)
        let fadeIn  = SKAction.fadeAlpha(to: 1.0, duration: 0.1)
        let blink   = SKAction.sequence([fadeOut, fadeIn])
        let repeatBlink = SKAction.repeat(blink, count: 5)

        // We don't capture `self` here (struct). We just finish visuals.
        let end = SKAction.run {
            ship.alpha = 1.0
        }

        ship.run(.sequence([repeatBlink, end]), withKey: "invulnBlink")
    }
}
