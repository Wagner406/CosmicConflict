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

    var level: GameLevel!
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

    let environment = EnvironmentSystem()
    let particles = ParticleSystem()
    var vfx: VFXSystem!

    var playerMovement = PlayerMovementSystem()
    var enemySlideSystem = EnemySlideSystem()
    let enemySlideDamping: CGFloat = 0.86

    var combatAndSpawning = CombatAndSpawnSystem()

    // MARK: - Pause State

    var isGamePaused: Bool = false

    // MARK: - Enemies

    var enemies: [SKSpriteNode] = []
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
    
    // MARK: - Timer / Score

    var levelStartTime: TimeInterval = 0
    var pauseStartTime: TimeInterval = 0
    var pausedTimeAccumulated: TimeInterval = 0

    // MARK: - Small Helpers (keep here)

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
