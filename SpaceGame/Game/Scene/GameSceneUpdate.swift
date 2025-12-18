//
//  GameScene+Update.swift
//  SpaceGame
//

import SpriteKit

extension GameScene {

    // MARK: - Game Loop

    override func update(_ currentTime: TimeInterval) {
        if isGamePaused { return }

        // Timer startet beim ersten Update-Frame
        if levelStartTime == 0 { levelStartTime = currentTime }

        if isLevelCompleted || isPlayerDead { return }

        // playerShip ist bei dir optional -> unwrap
        guard let playerShip = self.playerShip else { return }

        vfx?.beginFrame()
        currentTimeForCollisions = currentTime

        let deltaTime = computeDeltaTime(currentTime)

        handlePowerUpSpawning(currentTime: currentTime)
        updatePowerUpDurations(currentTime: currentTime)

        // Touch (Floating Joystick) hat Priorität
        if joystickVector.dx != 0 || joystickVector.dy != 0 {

            // Rotation (Ship schaut "nach oben" -> -pi/2 Offset)
            let angle = atan2(joystickVector.dy, joystickVector.dx) - .pi / 2
            playerShip.zRotation = angle

            // ✅ Speed-Limiter: Strength ist 0...1 (durch clamp im Input!)
            let speed = moveSpeed * joystickStrength

            // Bewegung
            playerShip.position.x += joystickVector.dx * speed * deltaTime
            playerShip.position.y += joystickVector.dy * speed * deltaTime

        } else {
            // Laptop / Buttons
            playerMovement.update(
                player: playerShip,
                direction: currentDirection,
                deltaTime: deltaTime,
                moveSpeed: moveSpeed,
                rotateSpeed: rotateSpeed
            )
        }

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
        particles.update(
            in: self,
            currentTime: currentTime,
            player: player,
            enemyShips: enemyShips,
            enemies: enemies,
            boss: boss
        )

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
}
