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

    // 🎵 Music
    static let level1Music = "Level1Music.mp3"
}

final class SoundManager {

    static let shared = SoundManager()
    private init() {}

    // 0.0 – 1.0
    var sfxVolume: Float = 0.65
    var musicVolume: Float = 0.5

    private var musicNode: SKAudioNode?

    // MARK: - MUSIC

    /// Startet Musik abhängig vom Level (damit GameScene clean bleibt)
    func startMusicIfNeeded(for levelId: Int, in scene: SKScene) {
        // nur Level 1
        guard levelId == 1 else { return }

        // nicht doppelt starten
        if musicNode != nil { return }

        playMusic(Sound.level1Music, in: scene, loop: true)
    }

    func playMusic(_ file: String, in scene: SKScene, loop: Bool = true) {
        stopMusic()

        let node = SKAudioNode(fileNamed: file)
        node.autoplayLooped = loop
        node.isPositional = false
        node.run(SKAction.changeVolume(to: musicVolume, duration: 0))

        scene.addChild(node)
        musicNode = node
    }

    func stopMusic() {
        musicNode?.removeFromParent()
        musicNode = nil
    }

    // MARK: - SFX (mit Volume)

    /// Spielt ein SFX mit echter Lautstärke-Kontrolle (über SKAudioNode).
    /// NOTE: Für sehr viele SFX kann das schwerer sein als SKAction.playSoundFileNamed,
    /// aber dafür hast du Volume-Controll.
    func play(_ sound: String, in scene: SKScene) {
        let node = SKAudioNode(fileNamed: sound)
        node.autoplayLooped = false
        node.isPositional = false
        node.run(SKAction.changeVolume(to: sfxVolume, duration: 0))

        scene.addChild(node)

        // nach kurzer Zeit entfernen (SFX sind kurz)
        node.run(.sequence([.wait(forDuration: 2.0), .removeFromParent()]))
    }

    func playRandomExplosion(in scene: SKScene) {
        guard let sound = Sound.explosions.randomElement() else { return }
        play(sound, in: scene)
    }
}
