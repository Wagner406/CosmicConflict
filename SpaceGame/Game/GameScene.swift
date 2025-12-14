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

    // Player Movement
    private var playerMovement = PlayerMovementSystem()

    // Enemy Slide
    private var enemySlideSystem = EnemySlideSystem()
    private let enemySlideDamping: CGFloat = 0.86

    // Combat + Spawning
    private var combatAndSpawning = CombatAndSpawnSystem()







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

    var lastEnemySpawnTime: TimeInterval = 0
    var enemiesSpawnedThisRound: Int = 0
    var enemiesKilledThisRound: Int = 0
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

        SoundManager.shared.startMusicIfNeeded(for: level.id, in: self)

        // Wave start
        if level.type == .normal && (level.config.rounds?.isEmpty == false) {
            startRound(1)
            showRoundAnnouncement(forRound: 1)
        }

        // Boss setup
        if level.type == .boss {
            setupBossIfNeeded()
            setupBossHUD()
            updateBossHUD()

            cameraNode.setScale(bossCameraZoom)
            vfx.setCamera(cameraNode)
        }
    }

    private func configurePhysics() {
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self
    }

    private func resetRuntimeState() {



        // Player movement system state
        playerMovement.reset()

        // Enemy slide system state
        enemySlideSystem.reset()

        // Combat & spawning system state
        combatAndSpawning.reset()




        // flying asteroid timers
        lastAsteroidSpawnTime = 0
        nextAsteroidSpawnInterval = TimeInterval.random(in: 10...20)

        // powerups
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
    // `didBegin(_:)` is implemented in ContactRouter.swift (extension GameScene).
    // Keep ONLY ONE didBegin implementation in the project.

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

        // Player movement handled by system
        playerMovement.update(
            player: playerShip,
            direction: currentDirection,
            deltaTime: deltaTime,
            moveSpeed: moveSpeed,
            rotateSpeed: rotateSpeed
        )

        clampPlayerToLevelBounds(playerShip)

        updateContinuousSystems(currentTime: currentTime, player: playerShip)

        updateEnemyMovementAndSlide(deltaTime: deltaTime)

        // Camera follows player
        cameraNode.position = playerShip.position

        // Combat + spawning handled by system
        combatAndSpawning.update(scene: self, currentTime: currentTime)
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

    // MARK: - Update: Enemy AI + Slide System

    private func updateEnemyMovementAndSlide(deltaTime: CGFloat) {
        // 1) snapshot BEFORE AI
        enemySlideSystem.beginFrame(for: enemyShips)

        // 2) AI movement (your AI.swift)
        updateChaser(deltaTime: deltaTime)

        // 3) apply slide AFTER AI
        enemySlideSystem.endFrame(
            for: enemyShips,
            deltaTime: deltaTime,
            damping: enemySlideDamping
        )
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
