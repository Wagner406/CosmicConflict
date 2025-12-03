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

    // MARK: - Properties

    var playerShip: SKSpriteNode!
    var levelNode: SKNode!

    /// Alle Gegner (Asteroiden + verfolgenden Schiffe)
    var enemies: [SKSpriteNode] = []

    /// Nur die verfolgenden Gegner-Schiffe (für AI, Schießen, Runden)
    var enemyShips: [SKSpriteNode] = []

    /// Callback, um nach Level-Ende zurück ins Menü zu springen
    var onLevelCompleted: (() -> Void)?

    var currentDirection: TankDirection?
    var lastUpdateTime: TimeInterval = 0

    let moveSpeed: CGFloat = 400      // Spieler-Bewegung
    let rotateSpeed: CGFloat = 4    // Spieler-Rotation

    let enemyMoveSpeed: CGFloat = 90  // Verfolger-Geschwindigkeit

    // Kamera
    let cameraNode = SKCameraNode()
    let cameraZoom: CGFloat = 1.5     // < 1 = näher dran

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
    /// Aktuelle Runde (1–5)
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

        setupBackground()
        setupLevel()
        setupEnemies()      // nur Start-Asteroiden, keine Schiffe mehr hier
        setupPlayerShip()
        setupCamera()       // ruft auch setupHUD() auf

        // fliegende Asteroiden
        lastAsteroidSpawnTime = 0
        nextAsteroidSpawnInterval = TimeInterval.random(in: 10...20)

        // Powerup-Timer initialisieren
        lastPowerUpSpawnTime = 0

        // Runde 1 starten + Banner anzeigen
        startRound(1)
        showRoundAnnouncement(forRound: 1)
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

            // Kugel entfernen
            first.node?.removeFromParent()

            guard let enemyNode = second.node as? SKSpriteNode else { return }

            // HP-Daten aus userData lesen (oder Defaults)
            if enemyNode.userData == nil {
                enemyNode.userData = NSMutableDictionary()
            }
            let currentHP = (enemyNode.userData?["hp"] as? Int) ?? 1
            let newHP     = max(0, currentHP - 1)

            enemyNode.userData?["hp"] = newHP
            updateEnemyHealthBar(for: enemyNode)

            if newHP <= 0 {
                // Wenn es ein verfolgenden Gegner-Schiff ist → Rundenfortschritt
                if enemyShips.contains(enemyNode) {
                    registerEnemyShipKilled(enemyNode)
                }

                // Gegner entfernen
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
            print("Player wurde von Enemy-Bullet getroffen! HP: \(playerHP)")
        }

        // Enemy (Asteroid oder Gegner-Schiff) rammt den Spieler
        if first.categoryBitMask == PhysicsCategory.player &&
           second.categoryBitMask == PhysicsCategory.enemy {

            applyDamageToPlayer(amount: 5)
            print("Player wurde von Enemy/Asteroid gerammt! HP: \(playerHP)")
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
        if let level = levelNode {
            let marginX = playerShip.size.width / 2
            let marginY = playerShip.size.height / 2

            let minX = level.frame.minX + marginX
            let maxX = level.frame.maxX - marginX
            let minY = level.frame.minY + marginY
            let maxY = level.frame.maxY - marginY

            let clampedX = max(minX, min(maxX, playerShip.position.x))
            let clampedY = max(minY, min(maxY, playerShip.position.y))
            playerShip.position = CGPoint(x: clampedX, y: clampedY)
        }

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
        handleEnemyWaveSpawning(currentTime: currentTime)
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
