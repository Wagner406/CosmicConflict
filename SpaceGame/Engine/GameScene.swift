//
//  GameScene.swift
//  SpaceGame
//
//  Created by Alexander Wagner on 29.11.25.
//

import SpriteKit

class GameScene: SKScene, SKPhysicsContactDelegate {

    // MARK: - Input

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

    // MARK: - Nodes

    var playerShip: SKSpriteNode!
    var levelNode: SKNode!

    // Background
    var spaceBackground: SKSpriteNode?

    // HUD
    let hudNode = SKNode()
    var playerHealthBar: SKSpriteNode?
    var powerUpLabel: SKLabelNode?
    var roundLabel: SKLabelNode?

    // Boss HUD
    var bossHealthBarBg: SKShapeNode?
    var bossHealthBarFill: SKShapeNode?
    var bossHealthLabel: SKLabelNode?
    var bossPhaseLabel: SKLabelNode?

    // Camera
    let cameraNode = SKCameraNode()
    let cameraZoom: CGFloat = 1.5
    let bossCameraZoom: CGFloat = 2.1

    // MARK: - Systems

    // Environment (Stars, ToxicGas, Nebula, ShootingStars)
    private let environment = EnvironmentSystem()

    // Particle (continuous)
    private let particles = ParticleSystem()

    // VFX (one-shot)
    var vfx: VFXSystem!

    // MARK: - Enemies

    /// Alle Gegner (Asteroiden + verfolgenden Schiffe)
    var enemies: [SKSpriteNode] = []

    /// Nur die verfolgenden Gegner-Schiffe (für AI, Schießen, Runden)
    var enemyShips: [SKSpriteNode] = []

    // MARK: - Movement

    var currentDirection: TankDirection?
    var lastUpdateTime: TimeInterval = 0

    let moveSpeed: CGFloat = 400
    let rotateSpeed: CGFloat = 4
    let enemyMoveSpeed: CGFloat = 90

    // Stop-Slide (nur beim Loslassen)
    private var playerSlideVelocity = CGVector(dx: 0, dy: 0)
    private let slideDamping: CGFloat = 0.86

    // Stop-Slide für Gegner-Schiffe (nur wenn sie in einem Frame nicht aktiv bewegt wurden)
    private var enemySlideVelocities: [ObjectIdentifier: CGVector] = [:]

    // MARK: - Combat / Timers

    // Gegner-Feuerrate
    let enemyFireInterval: TimeInterval = 1.5
    var lastEnemyFireTime: TimeInterval = 0

    // Zufällige Asteroiden-Spawns (fliegende Asteroiden)
    var lastAsteroidSpawnTime: TimeInterval = 0
    var nextAsteroidSpawnInterval: TimeInterval = 0
    let maxFlyingAsteroids = 4

    // MARK: - Player HP / Rounds

    var playerMaxHP: Int = 100
    var playerHP: Int = 100

    /// Aktuelle Runde (1–5 … oder passend zur Level-Config)
    var currentRound: Int = 1

    // Hit-Cooldown für den Spieler
    var playerLastHitTime: TimeInterval = 0
    let playerHitCooldown: TimeInterval = 1.0
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

    // MARK: - Rounds / Waves

    /// Letzte Zeit, zu der ein Gegner-Schiff gespawnt wurde
    var lastEnemySpawnTime: TimeInterval = 0

    /// Wie viele Gegner-Schiffe in dieser Runde bereits gespawnt wurden
    var enemiesSpawnedThisRound: Int = 0

    /// Wie viele Gegner-Schiffe in dieser Runde bereits zerstört wurden
    var enemiesKilledThisRound: Int = 0

    /// Level komplett geschafft?
    var isLevelCompleted: Bool = false

    // MARK: - Boss (Level 2)

    var boss: SKSpriteNode?
    var bossPhase: BossPhase = .phase1

    var bossShieldNode: SKShapeNode?
    var bossIsShieldActive: Bool = false

    var bossNextMoveTime: TimeInterval = 0
    var bossPauseUntil: TimeInterval = 0
    var bossNextShotTime: TimeInterval = 0

    var bossBurstShotsRemaining: Int = 0
    var bossBurstNextShotTime: TimeInterval = 0

    var bossLastPauseTriggerTime: TimeInterval = 0

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self

        if level == nil {
            level = GameLevels.level1
        }

        setupLevel()
        environment.buildForCurrentLevel(in: self)
        setupEnemies()
        setupPlayerShip()

        // --- Camera setup must happen before VFX init ---
        setupCamera()

        // IMPORTANT: Ensure SpriteKit actually uses our camera node (needed for shake/punch)
        self.camera = cameraNode

        // VFX init AFTER camera exists
        vfx = VFXSystem(scene: self, camera: cameraNode, zPosition: 900)
        vfx.setCamera(cameraNode)

        // Slide-Init
        playerSlideVelocity = .zero
        enemySlideVelocities.removeAll()

        // fliegende Asteroiden
        lastAsteroidSpawnTime = 0
        nextAsteroidSpawnInterval = TimeInterval.random(in: 10...20)

        // Powerup-Timer initialisieren
        lastPowerUpSpawnTime = 0

        particles.reset()

        // Musik erst starten, nachdem die Kamera existiert
        SoundManager.shared.startMusicIfNeeded(for: level.id, in: self)

        // Nur bei Wave-Levels Runden starten
        if level.type == .normal && (level.config.rounds?.isEmpty == false) {
            startRound(1)
            showRoundAnnouncement(forRound: 1)
        }

        // Boss-Setup
        if level.type == .boss {
            setupBossIfNeeded()
            setupBossHUD()
            updateBossHUD()

            cameraNode.setScale(bossCameraZoom)

            // Robust: make sure VFX always points to the active camera
            vfx.setCamera(cameraNode)
        }
    }

    // MARK: - Touch

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        shoot()
    }

    // MARK: - Physics Contacts

    func didBegin(_ contact: SKPhysicsContact) {
        let (first, second): (SKPhysicsBody, SKPhysicsBody)
        if contact.bodyA.categoryBitMask < contact.bodyB.categoryBitMask {
            first = contact.bodyA
            second = contact.bodyB
        } else {
            first = contact.bodyB
            second = contact.bodyA
        }

        // Player bullet hits enemy
        if first.categoryBitMask == PhysicsCategory.bullet &&
            second.categoryBitMask == PhysicsCategory.enemy {

            first.node?.removeFromParent()
            guard let enemyNode = second.node as? SKSpriteNode else { return }

            // Boss special case
            if let b = boss, enemyNode == b {
                vfx.spawnHitSparks(
                    at: contact.contactPoint,
                    baseColor: .cyan,
                    count: 14,
                    zPos: b.zPosition + 3
                )

                applyDamageToBoss(b, amount: 1)
                return
            }

            let isShip = enemyShips.contains(enemyNode)

            // Flash + Hit sparks
            vfx.playHitImpact(
                on: enemyNode,
                isShip: isShip,
                at: contact.contactPoint,
                zPos: enemyNode.zPosition + 2,
                sparkCount: isShip ? 12 : 9
            )

            // HP logic
            if enemyNode.userData == nil { enemyNode.userData = NSMutableDictionary() }
            let currentHP = (enemyNode.userData?["hp"] as? Int) ?? 1
            let newHP = max(0, currentHP - 1)

            enemyNode.userData?["hp"] = newHP
            updateEnemyHealthBar(for: enemyNode)

            if newHP <= 0 {
                if enemyShips.contains(enemyNode) {
                    registerEnemyShipKilled(enemyNode)

                    SoundManager.shared.playRandomExplosion(in: self)

                    vfx.playEnemyShipExplosion(
                        at: enemyNode.position,
                        zPosition: enemyNode.zPosition,
                        desiredWidth: size.width * 0.3
                    )

                    enemyNode.removeAllActions()
                    enemyNode.physicsBody = nil
                    enemyNode.removeFromParent()
                } else {
                    // Asteroid
                    SoundManager.shared.playRandomExplosion(in: self)
                    let savedVelocity = enemyNode.physicsBody?.velocity ?? .zero
                    vfx.playAsteroidDestruction(on: enemyNode, savedVelocity: savedVelocity)
                }

                enemies.removeAll { $0 == enemyNode }
            }
        }

        // Enemy bullet hits player
        if first.categoryBitMask == PhysicsCategory.player &&
            second.categoryBitMask == PhysicsCategory.enemyBullet {

            second.node?.removeFromParent()
            applyDamageToPlayer(amount: 10)
        }

        // Enemy rams player
        if first.categoryBitMask == PhysicsCategory.player &&
            second.categoryBitMask == PhysicsCategory.enemy {

            applyDamageToPlayer(amount: 5)
        }

        // Player picks up powerup
        if first.categoryBitMask == PhysicsCategory.player &&
            second.categoryBitMask == PhysicsCategory.powerUp {

            if let node = second.node as? SKSpriteNode {
                handlePowerUpPickup(node)
            }
        }
    }

    // MARK: - SwiftUI Controls

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

        // Begin VFX budget frame (safe even if you ever make vfx optional later)
        vfx?.beginFrame()

        currentTimeForCollisions = currentTime

        let deltaTime: CGFloat
        if lastUpdateTime == 0 {
            deltaTime = 0
        } else {
            deltaTime = CGFloat(currentTime - lastUpdateTime)
        }
        lastUpdateTime = currentTime

        // =========================
        // Player movement + slide
        // =========================
        if let direction = currentDirection {
            switch direction {
            case .forward:
                let angle = playerShip.zRotation
                let dx = -sin(angle) * moveSpeed * deltaTime
                let dy =  cos(angle) * moveSpeed * deltaTime
                playerShip.position.x += dx
                playerShip.position.y += dy

                let dt = max(deltaTime, 0.001)
                playerSlideVelocity = CGVector(dx: dx / dt, dy: dy / dt)

            case .backward:
                let angle = playerShip.zRotation
                let dx =  sin(angle) * moveSpeed * deltaTime
                let dy = -cos(angle) * moveSpeed * deltaTime
                playerShip.position.x += dx
                playerShip.position.y += dy

                let dt = max(deltaTime, 0.001)
                playerSlideVelocity = CGVector(dx: dx / dt, dy: dy / dt)

            case .rotateLeft:
                playerShip.zRotation += rotateSpeed * deltaTime

            case .rotateRight:
                playerShip.zRotation -= rotateSpeed * deltaTime
            }
        } else {
            playerShip.position.x += playerSlideVelocity.dx * deltaTime
            playerShip.position.y += playerSlideVelocity.dy * deltaTime

            let damp = pow(slideDamping, deltaTime * 60)
            playerSlideVelocity.dx *= damp
            playerSlideVelocity.dy *= damp

            if abs(playerSlideVelocity.dx) < 5 { playerSlideVelocity.dx = 0 }
            if abs(playerSlideVelocity.dy) < 5 { playerSlideVelocity.dy = 0 }
        }

        // Player in bounds
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

        // Continuous particles
        particles.update(in: self,
                         currentTime: currentTime,
                         player: playerShip,
                         enemyShips: enemyShips,
                         enemies: enemies,
                         boss: boss)

        // Environment
        environment.update(in: self, currentTime: currentTime)

        // =========================
        // Enemy slide if not moved
        // =========================
        var enemyPrePos: [ObjectIdentifier: CGPoint] = [:]
        for e in enemyShips {
            enemyPrePos[ObjectIdentifier(e)] = e.position
            if enemySlideVelocities[ObjectIdentifier(e)] == nil {
                enemySlideVelocities[ObjectIdentifier(e)] = .zero
            }
        }

        updateChaser(deltaTime: deltaTime)

        let dtE = max(deltaTime, 0.001)
        for e in enemyShips {
            let key = ObjectIdentifier(e)
            let before = enemyPrePos[key] ?? e.position
            let after = e.position

            let movedDx = after.x - before.x
            let movedDy = after.y - before.y
            let movedDist = hypot(movedDx, movedDy)

            if movedDist > 0.2 {
                enemySlideVelocities[key] = CGVector(dx: movedDx / dtE, dy: movedDy / dtE)
            } else {
                var v = enemySlideVelocities[key] ?? .zero

                e.position.x += v.dx * deltaTime
                e.position.y += v.dy * deltaTime

                let damp = pow(slideDamping, deltaTime * 60)
                v.dx *= damp
                v.dy *= damp

                if abs(v.dx) < 3 { v.dx = 0 }
                if abs(v.dy) < 3 { v.dy = 0 }

                enemySlideVelocities[key] = v
            }
        }

        // Camera follows player
        cameraNode.position = playerShip.position

        // Combat + spawns
        handleEnemyShooting(currentTime: currentTime)
        handleFlyingAsteroidSpawning(currentTime: currentTime)
        handlePowerUpSpawning(currentTime: currentTime)
        updatePowerUpDurations(currentTime: currentTime)

        if level.type == .normal {
            handleEnemyWaveSpawning(currentTime: currentTime)
        } else if level.type == .boss {
            updateBossFight(currentTime: currentTime)
        }
    }

    // MARK: - Player Damage

    func applyDamageToPlayer(amount: Int) {
        if isShieldActive { return }

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

        ship.run(.sequence([repeatBlink, end]), withKey: "invulnBlink")
    }

    // MARK: - Powerup Durations

    func updatePowerUpDurations(currentTime: TimeInterval) {
        if isTripleShotActive && currentTime >= tripleShotEndTime {
            isTripleShotActive = false
            setActivePowerUpLabel(isShieldActive ? "Shield" : nil)
        }

        if isShieldActive && currentTime >= shieldEndTime {
            isShieldActive = false
            if !isPlayerInvulnerable {
                playerShip.alpha = 1.0
            }
            shieldNode?.removeFromParent()
            shieldNode = nil

            setActivePowerUpLabel(isTripleShotActive ? "Triple Shot" : nil)
        }
    }

    // MARK: - Post-Physics

    override func didSimulatePhysics() {
        super.didSimulatePhysics()

        if level.type == .boss {
            bossFollowShieldIfNeeded()
        }
    }

    // MARK: - Enemy HP Scaling

    func enemyMaxHPForCurrentRound() -> Int {
        switch currentRound {
        case 1, 2:
            return 1
        case 3, 4:
            return 2
        default:
            return 3
        }
    }
}
