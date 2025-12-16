//
//  EnemySlideSystem.swift
//  SpaceGame
//
//  Created by Alexander Wagner on 14.12.25.
//

import SpriteKit

/// Applies inertia/slide to enemy ships that were NOT moved actively in the current frame.
/// Usage:
/// 1) call `beginFrame(for:)` BEFORE your AI movement
/// 2) run your AI movement (updateChaser)
/// 3) call `endFrame(for:deltaTime:)` AFTER AI movement
struct EnemySlideSystem {

    /// per-enemy slide velocities
    private(set) var velocities: [ObjectIdentifier: CGVector] = [:]

    /// pre-move positions snapshot
    private var prePositions: [ObjectIdentifier: CGPoint] = [:]

    mutating func reset() {
        velocities.removeAll()
        prePositions.removeAll()
    }

    /// Snapshot current positions (call BEFORE AI movement).
    mutating func beginFrame(for enemies: [SKSpriteNode]) {
        prePositions.removeAll(keepingCapacity: true)

        for e in enemies {
            let key = ObjectIdentifier(e)
            prePositions[key] = e.position

            // ensure velocity entry exists
            if velocities[key] == nil {
                velocities[key] = .zero
            }
        }
    }

    /// Apply slide for enemies that didn't move (call AFTER AI movement).
    mutating func endFrame(for enemies: [SKSpriteNode],
                           deltaTime: CGFloat,
                           damping: CGFloat = 0.86,
                           movedThreshold: CGFloat = 0.2,
                           stopThreshold: CGFloat = 3) {

        guard deltaTime > 0 else { return }

        let dt = max(deltaTime, 0.001)

        for e in enemies {
            let key = ObjectIdentifier(e)

            let before = prePositions[key] ?? e.position
            let after  = e.position

            let movedDx = after.x - before.x
            let movedDy = after.y - before.y
            let movedDist = hypot(movedDx, movedDy)

            if movedDist > movedThreshold {
                // AI moved it: capture velocity for inertia
                velocities[key] = CGVector(dx: movedDx / dt, dy: movedDy / dt)
                continue
            }

            // No active move -> apply inertia/slide
            var v = velocities[key] ?? .zero

            e.position.x += v.dx * deltaTime
            e.position.y += v.dy * deltaTime

            // scale damping by frame time (so it feels similar at different FPS)
            let damp = pow(damping, deltaTime * 60)
            v.dx *= damp
            v.dy *= damp

            if abs(v.dx) < stopThreshold { v.dx = 0 }
            if abs(v.dy) < stopThreshold { v.dy = 0 }

            velocities[key] = v
        }

        // cleanup entries for removed enemies (optional but nice)
        let alive = Set(enemies.map { ObjectIdentifier($0) })
        velocities = velocities.filter { alive.contains($0.key) }
    }
}
