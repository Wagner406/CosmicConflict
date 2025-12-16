//
//  CombatAndSpawnSystem.swift
//  SpaceGame
//

import Foundation

/// Orchestrates per-frame combat & spawn logic.
/// Keeps GameScene.update() clean while GameScene still owns the actual gameplay rules.
/// (Later you can move timers/state into this system if you want.)
struct CombatAndSpawnSystem {

    mutating func reset() {
        // currently stateless
    }

    mutating func update(scene: GameScene, currentTime: TimeInterval) {
        // Combat
        scene.handleEnemyShooting(currentTime: currentTime)

        // Spawning
        scene.handleFlyingAsteroidSpawning(currentTime: currentTime)
        scene.handlePowerUpSpawning(currentTime: currentTime)

        // Durations / cooldowns
        scene.updatePowerUpDurations(currentTime: currentTime)

        // Wave or Boss logic
        if scene.level.type == .normal {
            scene.handleEnemyWaveSpawning(currentTime: currentTime)
        } else if scene.level.type == .boss {
            scene.updateBossFight(currentTime: currentTime)
        }
    }
}
