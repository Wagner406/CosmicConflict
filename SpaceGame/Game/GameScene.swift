//
//  GameScene.swift
//  SpaceGame
//
//  Created by Alexander Wagner on 29.11.25.
//

import SpriteKit

final class GameScene: SKScene, SKPhysicsContactDelegate {

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

    // Player Movement System
    private var playerMovement = PlayerMovementSystem()

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

    // Stop-Slide für Gegner-Schiffe (nur wenn sie in einem Frame nicht aktiv bewegt wurden)
    private var enemySlideVelocities: [ObjectIdentifier: CGVector] = [:]

    // Keep this here for now (later becomes EnemySlideSystem)
    private let enemySlideDamping: CGFloat = 0.86

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
        configurePhysics()

        if level == nil {
            level = GameLevels.level1
        }

        setupLevel()
        environment.buildForCurrentLevel(in: self)
        setupEnemies()
        setupPlayerShip()

        // Camera must exist before VFX init
        setupCamera()
        self.camera = cameraNode

        // VFX init AFTER camera exists
        vfx = VFXSystem(scene: self, camera: cameraNode, zPosition: 900)
        vfx.setCamera(cameraNode)

        resetRuntimeState()

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

    private func configurePhysics() {
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self
    }

    private func resetRuntimeState() {
        // Player movement state
        playerMovement.reset()

        // Enemy slide state
        enemySlideVelocities.removeAll()

        // fliegende Asteroiden
        lastAsteroidSpawnTime = 0
        nextAsteroidSpawnInterval = TimeInterval.random(in: 10...20)

        // Powerup-Timer initialisieren
        lastPowerUpSpawnTime = 0

        particles.reset()
    }

    // MARK: - Touch

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        shoot()
    }

    // MARK: - Physics Contacts
    //
    // IMPORTANT:
    // `didBegin(_:)` has been moved into ContactRouter.swift (extension GameScene).
    // Keep ONLY ONE didBegin implementation in the project to avoid redeclaration issues.

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

        vfx?.beginFrame()
        currentTimeForCollisions = currentTime

        let deltaTime = computeDeltaTime(currentTime)

        // Player movement handled by system now
        playerMovement.update(
            player: playerShip,
            direction: currentDirection,
            deltaTime: deltaTime,
            moveSpeed: moveSpeed,
            rotateSpeed: rotateSpeed
        )

        clampPlayerToLevelBounds(playerShip)

        updateContinuousSystems(currentTime: currentTime, player: playerShip)

        updateEnemySlideAndChaser(deltaTime: deltaTime)

        // Camera follows player
        cameraNode.position = playerShip.position

        updateCombatAndSpawning(currentTime: currentTime)
    }

    private func computeDeltaTime(_ currentTime: TimeInterval) -> CGFloat {
        let deltaTime: CGFloat
        if lastUpdateTime == 0 {
            deltaTime = 0
        } else {
            deltaTime = CGFloat(currentTime - lastUpdateTime)
        }
        lastUpdateTime = currentTime
        return deltaTime
    }

    private func clampPlayerToLevelBounds(_ playerShip: SKSpriteNode) {
        guard let levelNode = levelNode else { return }

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

    // MARK: - Update: Continuous Systems

    private func updateContinuousSystems(currentTime: TimeInterval, player: SKSpriteNode) {
        particles.update(in: self,
                         currentTime: currentTime,
                         player: player,
                         enemyShips: enemyShips,
                         enemies: enemies,
                         boss: boss)

        environment.update(in: self, currentTime: currentTime)
    }

    // MARK: - Update: Enemy Slide + AI

    private func updateEnemySlideAndChaser(deltaTime: CGFloat) {
        // Snapshot positions before AI movement
        var enemyPrePos: [ObjectIdentifier: CGPoint] = [:]
        for e in enemyShips {
            enemyPrePos[ObjectIdentifier(e)] = e.position
            if enemySlideVelocities[ObjectIdentifier(e)] == nil {
                enemySlideVelocities[ObjectIdentifier(e)] = .zero
            }
        }

        // AI movement (your AI.swift)
        updateChaser(deltaTime: deltaTime)

        // Slide for ships that didn't move this frame
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

                let damp = pow(enemySlideDamping, deltaTime * 60)
                v.dx *= damp
                v.dy *= damp

                if abs(v.dx) < 3 { v.dx = 0 }
                if abs(v.dy) < 3 { v.dy = 0 }

                enemySlideVelocities[key] = v
            }
        }
    }

    // MARK: - Update: Combat + Spawning

    private func updateCombatAndSpawning(currentTime: TimeInterval) {
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
