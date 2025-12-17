//
//  GameScene+Update.swift
//  SpaceGame
//

import SpriteKit

extension GameScene {

    // MARK: - Game Loop

    override func update(_ currentTime: TimeInterval) {
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
}
