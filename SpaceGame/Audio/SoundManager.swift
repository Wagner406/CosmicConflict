import SpriteKit
import AVFoundation

enum Sound {
    static let playerShot = "PlayerShoot.wav"
    static let enemyShot  = "EnemyShoot.wav"
    static let powerup    = "PowerUp.wav"
    static let shotGun    = "ShotGun.wav"
    static let multiShot  = "MultiShoot.wav"
    static let shieldOn   = "ShieldOn.wav"
    static let shieldOff  = "ShieldOff.wav"
    
    static let explosions = [
        "Explosion1.wav",
        "Explosion2.wav",
        "Explosion3.wav"
    ]
    
    static let hits = [
        "Hit1.wav",
        "Hit2.wav"
    ]

    // Music
    static let level1Music = "Level1Music.mp3"
    static let level2Music = "Level2Music.mp3"
}

final class SoundManager: NSObject {

    static let shared = SoundManager()
    private override init() { super.init() }

    // 0.0 – 1.0
    var sfxVolume: Float = 0.08
    var musicVolume: Float = 0.08

    // MARK: - MUSIC (SpriteKit)
    private var musicNode: SKAudioNode?

    func startMusicIfNeeded(for levelId: Int, in scene: SKScene) {

        let file: String?
        switch levelId {
        case 1: file = Sound.level1Music
        case 2: file = Sound.level2Music
        default: file = nil
        }

        guard let musicFile = file else { return }

        if let node = musicNode {
            let isInThisScene = (node.scene === scene)
            let isInThisCamera = (scene.camera != nil && node.parent === scene.camera)

            if isInThisScene && isInThisCamera {
                return
            } else {
                stopMusic()
            }
        }

        playMusic(musicFile, in: scene, loop: true)
    }

    func playMusic(_ file: String, in scene: SKScene, loop: Bool = true) {
        stopMusic()

        let node = SKAudioNode(fileNamed: file)
        node.autoplayLooped = loop

        // SAFETY: Musik ist NIE positional
        node.isPositional = false

        // Immer bei (0,0) relativ zur Kamera
        node.position = .zero

        node.run(.changeVolume(to: musicVolume, duration: 0))

        // Wenn Kamera existiert: IMMER an Kamera hängen
        if let cam = scene.camera {
            cam.addChild(node)
        } else {
            scene.addChild(node)   // fallback
        }

        musicNode = node
    }

    func stopMusic() {
        musicNode?.removeAllActions()
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
    
    func playRandomBossHit(in scene: SKScene? = nil) {
        guard let sound = Sound.hits.randomElement() else { return }
        playSFX(sound, in: scene)
    }
}

extension SoundManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        activePlayers.removeAll { $0 === player }
    }
}
