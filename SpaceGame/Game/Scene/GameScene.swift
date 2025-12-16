//
//  GameScene.swift
//  SpaceGame
//
//  Created by Alexander Wagner on 29.11.25.
//

import SpriteKit

final class GameScene: SKScene, SKPhysicsContactDelegate {

    // MARK: - Input

    enum ShipDirection {
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

    // Pause Overlay
    var pauseOverlayDim: SKSpriteNode?
    var pauseOverlayPanel: SKShapeNode?
    var pauseResumeButton: SKShapeNode?
    var pauseMenuButton: SKShapeNode?

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

    // MARK: - Pause State
    var isGamePaused: Bool = false

    // Combat + Spawning
    private var combatAndSpawning = CombatAndSpawnSystem()

    // MARK: - Enemies

    /// Alle Gegner (Asteroiden + verfolgenden Schiffe)
    var enemies: [SKSpriteNode] = []

    /// Nur die verfolgenden Gegner-Schiffe (für AI, Schießen, Runden)
    var enemyShips: [SKSpriteNode] = []

    // MARK: - Movement

    var currentDirection: ShipDirection?
    var lastUpdateTime: TimeInterval = 0

    let moveSpeed: CGFloat = 400
    let rotateSpeed: CGFloat = 4
    let enemyMoveSpeed: CGFloat = 90

    // MARK: - Combat / Timers

    let enemyFireInterval: TimeInterval = 1.5
    var lastEnemyFireTime: TimeInterval = 0

    var lastAsteroidSpawnTime: TimeInterval = 0
    var nextAsteroidSpawnInterval: TimeInterval = 0
    let maxFlyingAsteroids = 4

    // MARK: - Player HP / Rounds

    var playerMaxHP: Int = 100
    var playerHP: Int = 100
    var currentRound: Int = 1

    var playerLastHitTime: TimeInterval = 0
    let playerHitCooldown: TimeInterval = 1.0
    var isPlayerInvulnerable: Bool = false

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

    var isTripleShotActive: Bool = false
    var tripleShotEndTime: TimeInterval = 0

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
    var bossNextShieldPauseTime: TimeInterval = 0
    var bossDidSpawnMinionsThisPause: Bool = false

    // MARK: - Boss (Phase 3 extra state)
    var bossPhase3UseShotgunNext: Bool = true
    var bossNextMinionSpawnTime: TimeInterval = 0

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

        setupCamera()
        self.camera = cameraNode

        // ✅ AUDIO LISTENER
        self.listener = cameraNode

        vfx = VFXSystem(scene: self, camera: cameraNode, zPosition: 900)
        vfx.setCamera(cameraNode)

        resetRuntimeState()

        SoundManager.shared.startMusicIfNeeded(for: level.id, in: self)

        if level.type == .normal && (level.config.rounds?.isEmpty == false) {
            startRound(1)
            showRoundAnnouncement(forRound: 1)
        }

        if level.type == .boss {
            setupBossIfNeeded()
            setupBossHUD()
            updateBossHUD()

            cameraNode.setScale(bossCameraZoom)
            vfx.setCamera(cameraNode)

            self.listener = cameraNode
        }
    }

    private func configurePhysics() {
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self
    }

    private func resetRuntimeState() {
        playerMovement.reset()
        enemySlideSystem.reset()
        combatAndSpawning.reset()

        lastAsteroidSpawnTime = 0
        nextAsteroidSpawnInterval = TimeInterval.random(in: 10...20)

        lastPowerUpSpawnTime = 0

        particles.reset()
    }

    // MARK: - Pause Logic

    func pauseGame() {
        guard !isGamePaused else { return }
        isGamePaused = true

        hud_showPauseOverlay()

        // Pause ALLES außer HUD/Kamera
        for child in children {
            if child === cameraNode { continue }   // HUD bleibt klickbar
            child.isPaused = true
        }

        physicsWorld.speed = 0
    }

    func resumeGame() {
        guard isGamePaused else { return }
        isGamePaused = false

        hud_hidePauseOverlay()

        for child in children {
            if child === cameraNode { continue }
            child.isPaused = false
        }

        physicsWorld.speed = 1

        // ✅ verhindert DeltaTime-Spike nach Pause
        lastUpdateTime = 0
    }

    func exitToMainMenu() {
        SoundManager.shared.stopMusic()

        isGamePaused = false
        physicsWorld.speed = 1
        hud_hidePauseOverlay()

        onLevelCompleted?()
    }

    // MARK: - Touch

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        let p = t.location(in: self)

        // HUD first (Pause Button + Overlay Buttons)
        if hudHandleTap(at: p) { return }

        // Wenn pausiert: kein Gameplay
        if isGamePaused { return }

        shoot()
    }

    // MARK: - SwiftUI Controls

    func startMoving(_ direction: ShipDirection) {
        currentDirection = direction
    }

    func stopMoving(_ direction: ShipDirection) {
        if currentDirection == direction {
            currentDirection = nil
        }
    }

    // MARK: - Game Loop

    override func update(_ currentTime: TimeInterval) {
        // ✅ WICHTIG: stoppt AI/Combat/Spawn/etc. (EnemyShips bewegen sich sonst weiter)
        if isGamePaused { return }

        guard let playerShip = playerShip, !isLevelCompleted else { return }

        vfx?.beginFrame()
        currentTimeForCollisions = currentTime

        let deltaTime = computeDeltaTime(currentTime)

        handlePowerUpSpawning(currentTime: currentTime)
        updatePowerUpDurations(currentTime: currentTime)

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

        cameraNode.position = playerShip.position

        if self.listener !== cameraNode {
            self.listener = cameraNode
        }

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

    private func updateContinuousSystems(currentTime: TimeInterval, player: SKSpriteNode) {
        particles.update(in: self,
                         currentTime: currentTime,
                         player: player,
                         enemyShips: enemyShips,
                         enemies: enemies,
                         boss: boss)

        environment.update(in: self, currentTime: currentTime)
    }

    private func updateEnemyMovementAndSlide(deltaTime: CGFloat) {
        enemySlideSystem.beginFrame(for: enemyShips)
        updateChaser(deltaTime: deltaTime)
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

    // MARK: - Post-Physics

    override func didSimulatePhysics() {
        super.didSimulatePhysics()

        // ✅ auch hier: nichts updaten wenn pausiert
        if isGamePaused { return }

        if level.type == .boss {
            bossFollowShieldIfNeeded()
        }
    }

    // MARK: - Dynamic Layout (Rotation / Resize)

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        relayoutHUD()
        self.listener = cameraNode
    }

    override func willMove(from view: SKView) {
        super.willMove(from: view)
        SoundManager.shared.stopMusic()
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
