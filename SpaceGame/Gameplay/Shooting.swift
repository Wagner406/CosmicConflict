//
//  Shooting.swift
//  SpaceGame
//

import SpriteKit

extension GameScene {

    // MARK: - Public (Input)

    /// Shoots a projectile (or 3 when Triple-Shot is active).
    func shoot() {
        guard playerShip != nil else { return }

        SoundManager.shared.playSFX(Sound.playerShot, in: self)

        if isTripleShotActive {
            spawnPlayerBullet(sideOffset: 0)
            spawnPlayerBullet(sideOffset: 20)
            spawnPlayerBullet(sideOffset: -20)
        } else {
            spawnPlayerBullet(sideOffset: 0)
        }
    }

    // MARK: - Player Bullet Spawn (Gameplay only)

    /// sideOffset: offset perpendicular to ship forward direction (in points)
    private func spawnPlayerBullet(sideOffset: CGFloat) {
        guard let ship = playerShip else { return }

        let angle = ship.zRotation

        // forward (local +Y)
        let dirX = -sin(angle)
        let dirY =  cos(angle)

        // right vector
        let rightX = cos(angle)
        let rightY = sin(angle)

        // spawn position
        let forwardOffset: CGFloat = ship.size.height / 2 + 10
        let baseX = ship.position.x + dirX * forwardOffset
        let baseY = ship.position.y + dirY * forwardOffset

        let startPos = CGPoint(
            x: baseX + rightX * sideOffset,
            y: baseY + rightY * sideOffset
        )

        // create bullet (physics only)
        let bullet = createPlayerBulletNode(shipSize: ship.size)
        bullet.position  = startPos
        bullet.zRotation = angle
        bullet.zPosition = ship.zPosition + 1

        addChild(bullet)

        // --- VFX hooks (visuals live in VFXSystem) ---
        vfx.applyPlayerBulletLook(to: bullet)
        vfx.applySpawnPop(to: bullet, from: 0.6, to: 1.0, duration: 0.06)

        let forwardAngle = atan2(dirY, dirX)
        vfx.spawnMuzzleFlash(
            at: startPos,
            directionAngle: forwardAngle,
            zPos: bullet.zPosition + 1
        )

        let playerGhostColor = SKColor(red: 0.55, green: 0.9, blue: 1.0, alpha: 1.0)
        vfx.attachGhostTrail(to: bullet, color: playerGhostColor)

        // velocity
        let bulletSpeed: CGFloat = 700
        bullet.physicsBody?.velocity = CGVector(dx: dirX * bulletSpeed, dy: dirY * bulletSpeed)

        // lifetime + cleanup
        bullet.run(.sequence([
            .wait(forDuration: 2.0),
            .run { [weak bullet] in bullet?.removeAction(forKey: "vfx.ghostTrail") },
            .removeFromParent()
        ]))
    }

    // MARK: - Enemy Shooting (Gameplay only)

    func enemyShoot(from enemy: SKSpriteNode, towards target: CGPoint) {
        SoundManager.shared.playSFX(Sound.enemyShot, in: self)

        let dx = target.x - enemy.position.x
        let dy = target.y - enemy.position.y
        let distance = sqrt(dx * dx + dy * dy)
        guard distance > 0.1 else { return }

        let dirX = dx / distance
        let dirY = dy / distance

        let bullet = createEnemyBulletNode()

        let offset: CGFloat = max(enemy.size.width, enemy.size.height) / 2 + 10
        bullet.position = CGPoint(
            x: enemy.position.x + dirX * offset,
            y: enemy.position.y + dirY * offset
        )
        bullet.zPosition = enemy.zPosition + 1

        // rotate so local +Y points in shoot direction
        bullet.zRotation = atan2(dirY, dirX) - .pi / 2

        addChild(bullet)

        // --- VFX hooks ---
        vfx.applyEnemyBulletLook(to: bullet)
        vfx.applySpawnPop(to: bullet, from: 0.7, to: 1.0, duration: 0.06)

        let enemyGhostColor = SKColor(red: 1.0, green: 0.6, blue: 0.3, alpha: 1.0)
        vfx.attachGhostTrail(to: bullet, color: enemyGhostColor)

        // velocity
        let bulletSpeed: CGFloat = 250
        bullet.physicsBody?.velocity = CGVector(dx: dirX * bulletSpeed, dy: dirY * bulletSpeed)

        // lifetime + cleanup
        bullet.run(.sequence([
            .wait(forDuration: 3.0),
            .run { [weak bullet] in bullet?.removeAction(forKey: "vfx.ghostTrail") },
            .removeFromParent()
        ]))
    }

    func handleEnemyShooting(currentTime: TimeInterval) {
        guard let playerShip = playerShip else { return }

        let shootRange: CGFloat = 750   // <- hier feinjustieren (600–900 meist gut)
        let shootRangeSq = shootRange * shootRange

        for enemy in enemyShips {
            if enemy.userData == nil { enemy.userData = NSMutableDictionary() }

            // Range check (schnell: squared distance)
            let dx = playerShip.position.x - enemy.position.x
            let dy = playerShip.position.y - enemy.position.y
            let distSq = dx*dx + dy*dy
            if distSq > shootRangeSq {
                // optional: nextFireTime etwas nach hinten schieben, damit sie nicht "stottern"
                enemy.userData?["nextFireTime"] = currentTime + TimeInterval.random(in: 0.4...0.9)
                continue
            }

            if enemy.userData?["nextFireTime"] == nil {
                let initialOffset = TimeInterval.random(in: 0.0...enemyFireInterval)
                enemy.userData?["nextFireTime"] = currentTime + initialOffset
            }

            let nextFire = (enemy.userData?["nextFireTime"] as? TimeInterval)
            ?? (currentTime + enemyFireInterval)

            if currentTime >= nextFire {

                // look at player just before shooting
                let desiredZ = atan2(dy, dx) - .pi / 2

                enemy.removeAction(forKey: "aimRotate")
                let rotate = SKAction.rotate(toAngle: desiredZ, duration: 0.06, shortestUnitArc: true)
                enemy.run(rotate, withKey: "aimRotate")

                enemyShoot(from: enemy, towards: playerShip.position)

                let jitter = TimeInterval.random(in: -0.25...0.35)
                let interval = max(0.35, enemyFireInterval + jitter)
                enemy.userData?["nextFireTime"] = currentTime + interval
            }
        }
    }

    // MARK: - Bullet Nodes (Physics only)

    private func createPlayerBulletNode(shipSize: CGSize) -> SKSpriteNode {
        let width  = shipSize.width * 0.22
        let height = shipSize.height * 0.45

        let bullet = SKSpriteNode(color: .clear, size: CGSize(width: width, height: height))
        bullet.alpha = 1.0
        bullet.blendMode = .add
        bullet.anchorPoint = CGPoint(x: 0.0, y: 0.5)

        let body = SKPhysicsBody(rectangleOf: bullet.size)
        body.isDynamic = true
        body.affectedByGravity = false
        body.allowsRotation = false

        // ⚡️ expensive-ish, but OK for player bullets
        body.usesPreciseCollisionDetection = true

        body.categoryBitMask = PhysicsCategory.bullet
        body.collisionBitMask = 0
        body.contactTestBitMask = PhysicsCategory.enemy
        bullet.physicsBody = body

        return bullet
    }

    private func createEnemyBulletNode() -> SKSpriteNode {
        let bulletSize = CGSize(width: 14, height: 24)

        let bullet = SKSpriteNode(color: .clear, size: bulletSize)
        bullet.alpha = 1.0
        bullet.blendMode = .add
        bullet.anchorPoint = CGPoint(x: 0.0, y: 0.5)

        let body = SKPhysicsBody(rectangleOf: bulletSize)
        body.isDynamic = true
        body.affectedByGravity = false
        body.allowsRotation = false

        // for performance: enemy bullets are slower, so precise is not needed
        body.usesPreciseCollisionDetection = false

        body.categoryBitMask = PhysicsCategory.enemyBullet
        body.collisionBitMask = 0
        body.contactTestBitMask = PhysicsCategory.player
        bullet.physicsBody = body

        return bullet
    }
}
