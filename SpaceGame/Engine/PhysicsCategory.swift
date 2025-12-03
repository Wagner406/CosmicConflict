//
//  PhysicsCategory.swift
//  SpaceGame
//
//  Created by Alexander Wagner on 30.11.25.
//

import SpriteKit

// MARK: - Physik-Kategorien

struct PhysicsCategory {
    static let player:      UInt32 = 0x1 << 0   // Spieler-Raumschiff
    static let bullet:      UInt32 = 0x1 << 1   // Schüsse des Spielers
    static let wall:        UInt32 = 0x1 << 2
    static let enemy:       UInt32 = 0x1 << 3   // Asteroiden + Gegner-Schiff
    static let enemyBullet: UInt32 = 0x1 << 4   // Schüsse der Gegner
    static let powerUp:     UInt32 = 0x1 << 5
    static let shield: UInt32      = 0x1 << 6
}
