//
//  PlayerMovementSystem.swift
//  SpaceGame
//

import SpriteKit

/// Handles player movement + "slide" when no input.
/// Keeps its own slide velocity state.
struct PlayerMovementSystem {

    // MARK: - State
    private(set) var slideVelocity: CGVector = .zero

    // MARK: - Tuning
    var slideDamping: CGFloat = 0.86           // 0.0..1.0 (higher = longer slide)
    var stopThreshold: CGFloat = 5             // velocity clamp to zero
    var fixedFrameRate: CGFloat = 60           // used for damping normalization

    mutating func reset() {
        slideVelocity = .zero
    }

    /// Updates player position/rotation and slide velocity.
    mutating func update(player: SKSpriteNode,
                         direction: GameScene.TankDirection?,
                         deltaTime: CGFloat,
                         moveSpeed: CGFloat,
                         rotateSpeed: CGFloat) {

        guard deltaTime >= 0 else { return }

        if let direction = direction {
            switch direction {
            case .forward:
                let angle = player.zRotation
                let dx = -sin(angle) * moveSpeed * deltaTime
                let dy =  cos(angle) * moveSpeed * deltaTime
                player.position.x += dx
                player.position.y += dy

                let dt = max(deltaTime, 0.001)
                slideVelocity = CGVector(dx: dx / dt, dy: dy / dt)

            case .backward:
                let angle = player.zRotation
                let dx =  sin(angle) * moveSpeed * deltaTime
                let dy = -cos(angle) * moveSpeed * deltaTime
                player.position.x += dx
                player.position.y += dy

                let dt = max(deltaTime, 0.001)
                slideVelocity = CGVector(dx: dx / dt, dy: dy / dt)

            case .rotateLeft:
                player.zRotation += rotateSpeed * deltaTime

            case .rotateRight:
                player.zRotation -= rotateSpeed * deltaTime
            }

        } else {
            // Slide when no input
            player.position.x += slideVelocity.dx * deltaTime
            player.position.y += slideVelocity.dy * deltaTime

            // Normalize damping to 60fps feel
            let damp = pow(slideDamping, deltaTime * fixedFrameRate)
            slideVelocity.dx *= damp
            slideVelocity.dy *= damp

            if abs(slideVelocity.dx) < stopThreshold { slideVelocity.dx = 0 }
            if abs(slideVelocity.dy) < stopThreshold { slideVelocity.dy = 0 }
        }
    }
}
