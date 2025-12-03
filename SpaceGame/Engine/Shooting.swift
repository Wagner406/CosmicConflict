//
//  Shooting.swift
//  SpaceGame
//

import SpriteKit

extension GameScene {

    // MARK: - Schießen (Spieler)

    func shoot() {
        guard let playerShip = playerShip else { return }

        let bulletSize = CGSize(
            width: playerShip.size.width * 0.25,
            height: playerShip.size.height * 0.4
        )

        let angle = playerShip.zRotation
        let forwardOffset: CGFloat = playerShip.size.height / 2 + bulletSize.height / 2

        func spawnBullet(sideOffset: CGFloat) {
            let forwardX = -sin(angle)
            let forwardY =  cos(angle)
            let rightX   =  cos(angle)
            let rightY   =  sin(angle)

            let startX = playerShip.position.x + forwardX * forwardOffset + rightX * sideOffset
            let startY = playerShip.position.y + forwardY * forwardOffset + rightY * sideOffset

            let bullet = SKSpriteNode(color: .yellow, size: bulletSize)
            bullet.position = CGPoint(x: startX, y: startY)
            bullet.zRotation = angle
            bullet.zPosition = playerShip.zPosition + 1

            let body = SKPhysicsBody(rectangleOf: bulletSize)
            body.isDynamic = true
            body.affectedByGravity = false
            body.allowsRotation = false
            body.usesPreciseCollisionDetection = true

            body.categoryBitMask = PhysicsCategory.bullet
            body.collisionBitMask = 0
            body.contactTestBitMask = PhysicsCategory.enemy

            bullet.physicsBody = body
            addChild(bullet)

            let bulletSpeed: CGFloat = 600
            let vx = forwardX * bulletSpeed
            let vy = forwardY * bulletSpeed
            bullet.physicsBody?.velocity = CGVector(dx: vx, dy: vy)

            bullet.run(.sequence([
                .wait(forDuration: 2.0),
                .removeFromParent()
            ]))
        }

        if isTripleShotActive {
            let spacing = bulletSize.width * 1.1
            spawnBullet(sideOffset: -spacing)
            spawnBullet(sideOffset: 0)
            spawnBullet(sideOffset: spacing)
        } else {
            spawnBullet(sideOffset: 0)
        }
    }

    // MARK: - Schießen (Gegner)

    func enemyShoot(from enemy: SKSpriteNode, towards target: CGPoint) {
        let dx = target.x - enemy.position.x
        let dy = target.y - enemy.position.y
        let distance = sqrt(dx*dx + dy*dy)
        guard distance > 0.1 else { return }

        let dirX = dx / distance
        let dirY = dy / distance

        let bulletSize = CGSize(width: 12, height: 18)
        let bullet = SKSpriteNode(color: .red, size: bulletSize)
        let offset: CGFloat = max(enemy.size.width, enemy.size.height) / 2 + 10

        let startX = enemy.position.x + dirX * offset
        let startY = enemy.position.y + dirY * offset

        bullet.position = CGPoint(x: startX, y: startY)
        bullet.zPosition = enemy.zPosition + 1
        bullet.zRotation = atan2(dirY, dirX) - .pi / 2

        let body = SKPhysicsBody(rectangleOf: bulletSize)
        body.isDynamic = true
        body.affectedByGravity = false
        body.allowsRotation = false
        body.usesPreciseCollisionDetection = true

        body.categoryBitMask = PhysicsCategory.enemyBullet
        body.collisionBitMask = 0
        body.contactTestBitMask = PhysicsCategory.player

        bullet.physicsBody = body
        addChild(bullet)

        let bulletSpeed: CGFloat = 250   // langsamer
        let vx = dirX * bulletSpeed
        let vy = dirY * bulletSpeed
        bullet.physicsBody?.velocity = CGVector(dx: vx, dy: vy)

        bullet.run(.sequence([
            .wait(forDuration: 3.0),
            .removeFromParent()
        ]))
    }

    func handleEnemyShooting(currentTime: TimeInterval) {
        guard let playerShip = playerShip else { return }

        if currentTime - lastEnemyFireTime < enemyFireInterval {
            return
        }
        lastEnemyFireTime = currentTime

        // alle verfolgenden Schiffe schießen auf den Spieler
        for enemy in enemyShips {
            enemyShoot(from: enemy, towards: playerShip.position)
        }
    }
}
