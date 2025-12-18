//
//  GameScene+Lifecycle.swift
//  SpaceGame
//

import SpriteKit

extension GameScene {

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

        // AUDIO LISTENER
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

    override func didSimulatePhysics() {
        super.didSimulatePhysics()

        if isGamePaused { return }

        if level.type == .boss {
            bossFollowShieldIfNeeded()
        }
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        relayoutHUD()
        self.listener = cameraNode
    }

    override func willMove(from view: SKView) {
        super.willMove(from: view)
        SoundManager.shared.stopMusic()
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
        
        // Timer reset
        levelStartTime = 0
        pauseStartTime = 0
        pausedTimeAccumulated = 0
    }
}
