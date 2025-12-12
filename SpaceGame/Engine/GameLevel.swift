//
//  GameLevel.swift
//  SpaceGame
//

import SpriteKit

// Welcher Typ von Level?
enum LevelType {
    case normal   // Waves etc.
    case boss     // Bossfight
}

// Konfiguration einer Runde (für Wave-Level)
struct RoundConfig {
    let spawnInterval: TimeInterval
    let enemyCount: Int
}

// Alle Einstellungen, die ein Level beschreibt
struct LevelConfig {
    let backgroundTextureName: String
    let worldScale: CGFloat

    // Musik (optional, damit nicht jedes Level Musik haben muss)
    let musicFileName: String?
    
    // Waves / Runden
    let wavesEnabled: Bool
    let rounds: [RoundConfig]?

    // Boss
    let bossName: String?
    let bossMaxHP: Int?
    let bossTextureName: String?
}

// Ein konkretes Level
struct GameLevel {
    let id: Int
    let name: String
    let type: LevelType
    let config: LevelConfig
}

// Sammlung deiner Levels
enum GameLevels {

    // Level 1 – dein aktuelles „normales“ Level mit Waves
    static let level1 = GameLevel(
        id: 1,
        name: "Sector Alpha",
        type: .normal,
        config: LevelConfig(
            backgroundTextureName: "space1",   // aktuelles Map-Bild
            worldScale: 2.0,
            musicFileName: "Level1Music.mp3",
            wavesEnabled: true,
            rounds: [
                RoundConfig(spawnInterval: 5.0, enemyCount: 5),
                RoundConfig(spawnInterval: 4.0, enemyCount: 10),
                RoundConfig(spawnInterval: 3.0, enemyCount: 15),
                RoundConfig(spawnInterval: 2.0, enemyCount: 15),
                RoundConfig(spawnInterval: 1.0, enemyCount: 15)
            ],
            bossName: nil,
            bossMaxHP: nil,
            bossTextureName: nil
        )
    )

    // Level 2 – Bossfight (Config erstmal vorbereitet)
    static let level2 = GameLevel(
        id: 2,
        name: "Mothership",
        type: .boss,
        config: LevelConfig(
            backgroundTextureName: "space2", // anderes Hintergrundbild
            worldScale: 2.0,
            musicFileName: nil,
            wavesEnabled: false,
            rounds: nil,
            bossName: "Overlord-X9",
            bossMaxHP: 500,
            bossTextureName: "BossOverlord"
        )
    )

    static let all: [GameLevel] = [level1, level2]
}
