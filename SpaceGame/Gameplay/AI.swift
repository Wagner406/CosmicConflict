//
//  AI.swift
//  SpaceGame
//

import SpriteKit

// MARK: - Verfolger-AI

extension GameScene {

    func updateChaser(deltaTime: CGFloat) {
        guard !enemyShips.isEmpty,
              let level = levelNode,
              let playerShip = playerShip else { return }

        for chaser in enemyShips {

            let dx = playerShip.position.x - chaser.position.x
            let dy = playerShip.position.y - chaser.position.y
            let distance = sqrt(dx*dx + dy*dy)

            // Wenn zu nah, nicht weiter reinfahren
            if distance < 150 { continue }

            // Richtung zum Spieler
            let desiredAngle = atan2(dy, dx) - .pi / 2
            chaser.zRotation = desiredAngle

            let dirX = -sin(chaser.zRotation)
            let dirY =  cos(chaser.zRotation)

            let step = enemyMoveSpeed * deltaTime
            var newPos = CGPoint(
                x: chaser.position.x + dirX * step,
                y: chaser.position.y + dirY * step
            )

            let marginX = chaser.size.width / 2
            let marginY = chaser.size.height / 2

            let minX = level.frame.minX + marginX
            let maxX = level.frame.maxX - marginX
            let minY = level.frame.minY + marginY
            let maxY = level.frame.maxY - marginY

            newPos.x = max(minX, min(maxX, newPos.x))
            newPos.y = max(minY, min(maxY, newPos.y))

            chaser.position = newPos
        }
    }
}
