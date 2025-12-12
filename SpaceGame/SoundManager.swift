//
//  SoundManager.swift
//  SpaceGame
//
//  Created by Alexander Wagner on 12.12.25.
//

import SpriteKit

enum Sound {
    static let playerShot = "PlayerShoot.wav"
    static let enemyShot  = "EnemyShoot.wav"
    static let powerup    = "PowerUp.wav"
    static let explosions = [
            "Explosion1.wav",
            "Explosion2.wav",
            "Explosion3.wav"
        ]
}

final class SoundManager {

    static let shared = SoundManager()
    private init() {}

    // globale Lautstärke (0.0 – 1.0)
    var sfxVolume: Float = 1.0

    func play(_ sound: String, on node: SKNode) {
        let action = SKAction.playSoundFileNamed(sound, waitForCompletion: false)
        node.run(action)
    }
    
    func playRandomExplosion(on node: SKNode) {
        guard let sound = Sound.explosions.randomElement() else { return }
        play(sound, on: node)
    }
}
