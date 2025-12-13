import SpriteKit
import AVFoundation

enum Sound {
    static let playerShot = "PlayerShoot.wav"
    static let enemyShot  = "EnemyShoot.wav"
    static let powerup    = "PowerUp.wav"

    static let explosions = [
        "Explosion1.wav",
        "Explosion2.wav",
        "Explosion3.wav"
    ]

    // Music
    static let level1Music = "Level1Music.mp3"
}

final class SoundManager: NSObject {

    static let shared = SoundManager()
    private override init() { super.init() }

    // 0.0 – 1.0
    var sfxVolume: Float = 0.2
    var musicVolume: Float = 0.5

    // MARK: - MUSIC (SpriteKit)
    private var musicNode: SKAudioNode?

    func startMusicIfNeeded(for levelId: Int, in scene: SKScene) {
        guard levelId == 1 else { return }
        if musicNode != nil { return }
        playMusic(Sound.level1Music, in: scene, loop: true)
    }

    func playMusic(_ file: String, in scene: SKScene, loop: Bool = true) {
        stopMusic()

        let node = SKAudioNode(fileNamed: file)
        node.autoplayLooped = loop
        node.isPositional = false
        node.run(SKAction.changeVolume(to: musicVolume, duration: 0))

        // an Kamera hängen, wenn vorhanden
        if let cam = scene.camera {
            cam.addChild(node)
        } else {
            scene.addChild(node)
        }

        musicNode = node
    }

    func stopMusic() {
        musicNode?.removeFromParent()
        musicNode = nil
    }

    // MARK: - SFX (AVAudioPlayer)
    private var activePlayers: [AVAudioPlayer] = []

    /// Plays a SFX (global / non-positional). `scene` is optional, only here for API compatibility.
    func playSFX(_ file: String, in scene: SKScene? = nil) {
        guard let url = Bundle.main.url(forResource: file, withExtension: nil) else {
            print("SFX not found in bundle:", file)
            return
        }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = sfxVolume
            player.delegate = self
            player.prepareToPlay()

            activePlayers.append(player)
            player.play()

        } catch {
            print("Failed to play SFX:", file, error)
        }
    }

    /// Convenience for your GameScene fix: SoundManager.shared.playRandomExplosion(in: self)
    func playRandomExplosion(in scene: SKScene? = nil) {
        guard let sound = Sound.explosions.randomElement() else { return }
        playSFX(sound, in: scene)
    }
}

extension SoundManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        activePlayers.removeAll { $0 === player }
    }
}
