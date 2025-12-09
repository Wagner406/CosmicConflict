//
//  GameScene.swift
//  SpaceGame
//
//  Created by Alexander Wagner on 29.11.25.
//

import SpriteKit

class GameScene: SKScene, SKPhysicsContactDelegate {

    enum TankDirection {
        case forward
        case backward
        case rotateLeft
        case rotateRight
    }

    // MARK: - Level / Callback

    /// Welches Level gespielt wird (wird von GameView gesetzt)
    var level: GameLevel!

    /// Callback, um nach Level-Ende zurück ins Menü zu springen
    var onLevelCompleted: (() -> Void)?

    // MARK: - Properties

    var playerShip: SKSpriteNode!
    var levelNode: SKNode!

    /// Alle Gegner (Asteroiden + verfolgenden Schiffe)
    var enemies: [SKSpriteNode] = []

    /// Nur die verfolgenden Gegner-Schiffe (für AI, Schießen, Runden)
    var enemyShips: [SKSpriteNode] = []

    var currentDirection: TankDirection?
    var lastUpdateTime: TimeInterval = 0

    /// Zeitstempel für Thruster-Partikel, damit wir nicht zu viele spawnen
    var lastThrusterParticleTime: TimeInterval = 0

    let moveSpeed: CGFloat = 400      // Spieler-Bewegung
    let rotateSpeed: CGFloat = 4      // Spieler-Rotation

    let enemyMoveSpeed: CGFloat = 90  // Verfolger-Geschwindigkeit

    // Kamera
    let cameraNode = SKCameraNode()
    let cameraZoom: CGFloat = 1.5

    // Gegner-Feuerrate
    let enemyFireInterval: TimeInterval = 1.5
    var lastEnemyFireTime: TimeInterval = 0

    // Zufällige Asteroiden-Spawns (fliegende Asteroiden)
    var lastAsteroidSpawnTime: TimeInterval = 0
    var nextAsteroidSpawnInterval: TimeInterval = 0
    let maxFlyingAsteroids = 4

    // Hintergrund
    var spaceBackground: SKSpriteNode?

    // Spieler-HP / Runden
    var playerMaxHP: Int = 100
    var playerHP: Int = 100

    var roundLabel: SKLabelNode?
    /// Aktuelle Runde (1–5 … oder passend zur Level-Config)
    var currentRound: Int = 1

    // HUD
    let hudNode = SKNode()
    var playerHealthBar: SKSpriteNode?
    var powerUpLabel: SKLabelNode?      // Text oben rechts

    // Hit-Cooldown für den Spieler
    var playerLastHitTime: TimeInterval = 0
    let playerHitCooldown: TimeInterval = 1.0   // Sekunden Unverwundbarkeit
    var isPlayerInvulnerable: Bool = false

    // Zeit aus update(), damit didBegin weiß, welche Zeit gilt
    var currentTimeForCollisions: TimeInterval = 0

    // MARK: - Powerups

    enum PowerUpType: CaseIterable {
        case health
        case tripleShot
        case shield
    }

    var activePowerUpNode: SKSpriteNode?
    var lastPowerUpSpawnTime: TimeInterval = 0
    let powerUpMinInterval: TimeInterval = 15.0

    // Triple-Shot
    var isTripleShotActive: Bool = false
    var tripleShotEndTime: TimeInterval = 0

    // Shield
    var isShieldActive: Bool = false
    var shieldEndTime: TimeInterval = 0
    var shieldNode: SKSpriteNode?

    // MARK: - Runden/Waves

    /// Letzte Zeit, zu der ein Gegner-Schiff gespawnt wurde
    var lastEnemySpawnTime: TimeInterval = 0

    /// Wie viele Gegner-Schiffe in dieser Runde bereits gespawnt wurden
    var enemiesSpawnedThisRound: Int = 0

    /// Wie viele Gegner-Schiffe in dieser Runde bereits zerstört wurden
    var enemiesKilledThisRound: Int = 0

    /// Level komplett geschafft?
    var isLevelCompleted: Bool = false

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self

        // Falls aus irgendeinem Grund kein Level gesetzt wurde → Fallback
        if level == nil {
            level = GameLevels.level1
        }

        setupBackground()
        setupLevel()        // nutzt jetzt LevelFactory und GameLevel
        setupEnemies()      // Start-Asteroiden, evtl. später Boss-Setup
        setupPlayerShip()
        setupCamera()       // ruft auch setupHUD() auf

        // fliegende Asteroiden
        lastAsteroidSpawnTime = 0
        nextAsteroidSpawnInterval = TimeInterval.random(in: 10...20)

        // Powerup-Timer initialisieren
        lastPowerUpSpawnTime = 0

        // Nur bei Wave-Levels Runden starten
        if level.type == .normal && (level.config.rounds?.isEmpty == false) {
            startRound(1)
            showRoundAnnouncement(forRound: 1)
        }
    }

    // MARK: - Touch → Spieler schießt

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        shoot()
    }

    // MARK: - Kollisionen

    func didBegin(_ contact: SKPhysicsContact) {
        let (first, second): (SKPhysicsBody, SKPhysicsBody)
        if contact.bodyA.categoryBitMask < contact.bodyB.categoryBitMask {
            first = contact.bodyA
            second = contact.bodyB
        } else {
            first = contact.bodyB
            second = contact.bodyA
        }

        // Spieler-Bullet trifft Enemy (Asteroid oder Gegner-Schiff)
        if first.categoryBitMask == PhysicsCategory.bullet &&
           second.categoryBitMask == PhysicsCategory.enemy {

            first.node?.removeFromParent()

            guard let enemyNode = second.node as? SKSpriteNode else { return }

            if enemyNode.userData == nil {
                enemyNode.userData = NSMutableDictionary()
            }
            let currentHP = (enemyNode.userData?["hp"] as? Int) ?? 1
            let newHP     = max(0, currentHP - 1)

            enemyNode.userData?["hp"] = newHP
            updateEnemyHealthBar(for: enemyNode)

            if newHP <= 0 {
                // Ist es ein verfolgenden Gegner-Schiff? → Runde updaten
                if enemyShips.contains(enemyNode) {
                    registerEnemyShipKilled(enemyNode)
                }

                let fade = SKAction.fadeOut(withDuration: 0.1)
                let remove = SKAction.removeFromParent()
                enemyNode.run(.sequence([fade, remove]))
                enemies.removeAll { $0 == enemyNode }
            }
        }

        // Enemy-Bullet trifft Spieler-Schiff
        if first.categoryBitMask == PhysicsCategory.player &&
           second.categoryBitMask == PhysicsCategory.enemyBullet {

            second.node?.removeFromParent()
            applyDamageToPlayer(amount: 10)
        }

        // Enemy (Asteroid oder Gegner-Schiff) rammt den Spieler
        if first.categoryBitMask == PhysicsCategory.player &&
           second.categoryBitMask == PhysicsCategory.enemy {

            applyDamageToPlayer(amount: 5)
        }

        // Spieler sammelt Powerup ein
        if first.categoryBitMask == PhysicsCategory.player &&
           second.categoryBitMask == PhysicsCategory.powerUp {

            if let node = second.node as? SKSpriteNode {
                handlePowerUpPickup(node)
            }
        }
    }

    // MARK: - Steuerung via SwiftUI Buttons

    func startMoving(_ direction: TankDirection) {
        currentDirection = direction
    }

    func stopMoving(_ direction: TankDirection) {
        if currentDirection == direction {
            currentDirection = nil
        }
    }

    // MARK: - Game Loop

    override func update(_ currentTime: TimeInterval) {
        guard let playerShip = playerShip, !isLevelCompleted else { return }

        currentTimeForCollisions = currentTime

        let deltaTime: CGFloat
        if lastUpdateTime == 0 {
            deltaTime = 0
        } else {
            deltaTime = CGFloat(currentTime - lastUpdateTime)
        }
        lastUpdateTime = currentTime

        // Spieler-Bewegung
        if let direction = currentDirection {
            switch direction {
            case .forward:
                let angle = playerShip.zRotation
                let dx = -sin(angle) * moveSpeed * deltaTime
                let dy =  cos(angle) * moveSpeed * deltaTime
                playerShip.position.x += dx
                playerShip.position.y += dy

            case .backward:
                let angle = playerShip.zRotation
                let dx =  sin(angle) * moveSpeed * deltaTime
                let dy = -cos(angle) * moveSpeed * deltaTime
                playerShip.position.x += dx
                playerShip.position.y += dy

            case .rotateLeft:
                playerShip.zRotation += rotateSpeed * deltaTime

            case .rotateRight:
                playerShip.zRotation -= rotateSpeed * deltaTime
            }
        }

        // Spieler innerhalb der Map halten
        if let levelNode = levelNode {
            let marginX = playerShip.size.width / 2
            let marginY = playerShip.size.height / 2

            let minX = levelNode.frame.minX + marginX
            let maxX = levelNode.frame.maxX - marginX
            let minY = levelNode.frame.minY + marginY
            let maxY = levelNode.frame.maxY - marginY

            let clampedX = max(minX, min(maxX, playerShip.position.x))
            let clampedY = max(minY, min(maxY, playerShip.position.y))
            playerShip.position = CGPoint(x: clampedX, y: clampedY)
        }

        // Thruster-Partikel hinter dem Schiff spawnen
        spawnThrusterParticle(currentTime: currentTime)

        // Verfolger-AI für ALLE Gegner-Schiffe
        updateChaser(deltaTime: deltaTime)

        // Kamera folgt dem Spieler
        cameraNode.position = playerShip.position

        // Gegner schießen
        handleEnemyShooting(currentTime: currentTime)

        // zufällige fliegende Asteroiden spawnen
        handleFlyingAsteroidSpawning(currentTime: currentTime)

        // Powerup-Spawns steuern
        handlePowerUpSpawning(currentTime: currentTime)

        // Powerup-Dauer (Triple Shot / Shield) überprüfen
        updatePowerUpDurations(currentTime: currentTime)

        // Gegner-Waves für aktuelle Runde spawnen
        if level.type == .normal {
            handleEnemyWaveSpawning(currentTime: currentTime)
        }
        // Boss-Logik könntest du später hier ergänzen (level.type == .boss)
    }

    /// Spawnt einen einzelnen gelben „Thruster-Partikel“ hinter dem Schiff
    func spawnThrusterParticle(currentTime: TimeInterval) {
        guard let ship = playerShip else { return }

        // Max. ~30 Partikel pro Sekunde
        if currentTime - lastThrusterParticleTime < 0.03 {
            return
        }
        lastThrusterParticleTime = currentTime

        let angle = ship.zRotation

        // Vorwärts-Richtung (-sin, cos) → nach hinten drehen
        let backX = sin(angle)
        let backY = -cos(angle)

        // Basis-Punkt direkt hinter dem Schiff
        let distanceBehind: CGFloat = ship.size.height * 0.6
        let baseX = ship.position.x + backX * distanceBehind
        let baseY = ship.position.y + backY * distanceBehind

        // zufälliger Offset, damit es nicht zu „sauber“ ist
        let jitterX = CGFloat.random(in: -6...6)
        let jitterY = CGFloat.random(in: -3...3)

        let particleSize = ship.size.width * 0.18
        let particle = SKSpriteNode(
            color: .yellow,
            size: CGSize(width: particleSize, height: particleSize)
        )

        particle.position = CGPoint(x: baseX + jitterX, y: baseY + jitterY)
        particle.zPosition = ship.zPosition - 1
        particle.alpha = 0.9
        particle.blendMode = .add   // Neon-Glow

        addChild(particle)

        // Partikel driftet noch weiter nach hinten
        let driftDistance: CGFloat = ship.size.height * 0.3
        let move = SKAction.moveBy(
            x: backX * driftDistance,
            y: backY * driftDistance,
            duration: 0.35
        )

        let fade  = SKAction.fadeOut(withDuration: 0.35)
        let scale = SKAction.scale(to: 0.1, duration: 0.35)

        let group  = SKAction.group([move, fade, scale])
        let finish = SKAction.removeFromParent()

        particle.run(.sequence([group, finish]))
    }

    // MARK: - Schaden am Spieler

    func applyDamageToPlayer(amount: Int) {
        // 1) Schild aktiv? → gar kein Schaden
        if isShieldActive {
            return
        }

        // 2) Normaler Hit-Cooldown (kurze Unverwundbarkeit mit Blinken)
        if isPlayerInvulnerable &&
            (currentTimeForCollisions - playerLastHitTime) < playerHitCooldown {
            return
        }

        playerLastHitTime = currentTimeForCollisions
        isPlayerInvulnerable = true

        playerHP = max(0, playerHP - amount)
        updatePlayerHealthBar()

        startPlayerInvulnerabilityBlink()
    }

    func startPlayerInvulnerabilityBlink() {
        guard let ship = playerShip else { return }

        ship.removeAction(forKey: "invulnBlink")

        let fadeOut = SKAction.fadeAlpha(to: 0.3, duration: 0.1)
        let fadeIn  = SKAction.fadeAlpha(to: 1.0, duration: 0.1)
        let blink   = SKAction.sequence([fadeOut, fadeIn])
        let repeatBlink = SKAction.repeat(blink, count: 5)

        let end = SKAction.run { [weak self] in
            self?.isPlayerInvulnerable = false
            self?.playerShip.alpha = 1.0
        }

        let sequence = SKAction.sequence([repeatBlink, end])
        ship.run(sequence, withKey: "invulnBlink")
    }

    // MARK: - Powerup-Verwaltung (Dauer etc.)

    func updatePowerUpDurations(currentTime: TimeInterval) {
        // Triple Shot endet?
        if isTripleShotActive && currentTime >= tripleShotEndTime {
            isTripleShotActive = false
            if !isShieldActive {
                setActivePowerUpLabel(nil)
            } else {
                setActivePowerUpLabel("Shield")
            }
        }

        // Shield endet?
        if isShieldActive && currentTime >= shieldEndTime {
            isShieldActive = false
            if !isPlayerInvulnerable {
                playerShip.alpha = 1.0
            }
            shieldNode?.removeFromParent()
            shieldNode = nil

            if !isTripleShotActive {
                setActivePowerUpLabel(nil)
            } else {
                setActivePowerUpLabel("Triple Shot")
            }
        }
    }

    // MARK: - Gegner-HP-Konfiguration nach Runde

    func enemyMaxHPForCurrentRound() -> Int {
        // Für Boss-Level könntest du hier später anders skalieren, z.B. über level.config.bossMaxHP
        switch currentRound {
        case 1, 2:
            return 1     // Runde 1–2: 1 Treffer
        case 3, 4:
            return 2     // Runde 3–4: 2 Treffer
        default:
            return 3     // Runde 5+: 3 Treffer
        }
    }
}
