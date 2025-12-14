//
//  ContactRouter.swift
//  SpaceGame
//

import SpriteKit

// MARK: - Physics Contact Router

extension GameScene {

    func didBegin(_ contact: SKPhysicsContact) {
        let pair = orderedBodies(contact)

        // Router: genau 1 Entry-Point
        routeContact(first: pair.first, second: pair.second, contact: contact)
    }
}

// MARK: - Routing

private extension GameScene {

    func routeContact(first: SKPhysicsBody, second: SKPhysicsBody, contact: SKPhysicsContact) {

        // Player bullet hits enemy
        if first.categoryBitMask == PhysicsCategory.bullet &&
            second.categoryBitMask == PhysicsCategory.enemy {
            handleBulletHitsEnemy(bulletBody: first, enemyBody: second, contact: contact)
            return
        }

        // Enemy bullet hits player
        if first.categoryBitMask == PhysicsCategory.player &&
            second.categoryBitMask == PhysicsCategory.enemyBullet {
            handleEnemyBulletHitsPlayer(enemyBulletBody: second)
            return
        }

        // Enemy rams player
        if first.categoryBitMask == PhysicsCategory.player &&
            second.categoryBitMask == PhysicsCategory.enemy {
            handleEnemyRamsPlayer(enemyBody: second)
            return
        }

        // Player picks up powerup
        if first.categoryBitMask == PhysicsCategory.player &&
            second.categoryBitMask == PhysicsCategory.powerUp {
            handlePlayerPicksPowerUp(powerUpBody: second)
            return
        }
    }
}

// MARK: - Handlers (Gameplay rules)

private extension GameScene {

    func handleBulletHitsEnemy(bulletBody: SKPhysicsBody,
                              enemyBody: SKPhysicsBody,
                              contact: SKPhysicsContact) {

        bulletBody.node?.removeFromParent()

        guard let enemyNode = enemyBody.node as? SKSpriteNode else { return }

        // Boss special case
        if let b = boss, enemyNode == b {
            vfx.spawnHitSparks(
                at: contact.contactPoint,
                baseColor: .cyan,
                count: 14,
                zPos: b.zPosition + 3
            )
            applyDamageToBoss(b, amount: 1)
            return
        }

        let isShip = enemyShips.contains(enemyNode)

        // Hit VFX
        vfx.playHitImpact(
            on: enemyNode,
            isShip: isShip,
            at: contact.contactPoint,
            zPos: enemyNode.zPosition + 2,
            sparkCount: isShip ? 12 : 9
        )

        // HP logic
        if enemyNode.userData == nil { enemyNode.userData = NSMutableDictionary() }
        let currentHP = (enemyNode.userData?["hp"] as? Int) ?? 1
        let newHP = max(0, currentHP - 1)
        enemyNode.userData?["hp"] = newHP

        updateEnemyHealthBar(for: enemyNode)

        guard newHP <= 0 else { return }

        // Kill
        if isShip {
            registerEnemyShipKilled(enemyNode)

            SoundManager.shared.playRandomExplosion(in: self)

            vfx.playEnemyShipExplosion(
                at: enemyNode.position,
                zPosition: enemyNode.zPosition,
                desiredWidth: size.width * 0.3
            )

            enemyNode.removeAllActions()
            enemyNode.physicsBody = nil
            enemyNode.removeFromParent()
        } else {
            // Asteroid
            SoundManager.shared.playRandomExplosion(in: self)
            let savedVelocity = enemyNode.physicsBody?.velocity ?? .zero
            vfx.playAsteroidDestruction(on: enemyNode, savedVelocity: savedVelocity)
        }

        enemies.removeAll { $0 == enemyNode }
    }

    func handleEnemyBulletHitsPlayer(enemyBulletBody: SKPhysicsBody) {
        enemyBulletBody.node?.removeFromParent()
        applyDamageToPlayer(amount: 10)
    }

    func handleEnemyRamsPlayer(enemyBody: SKPhysicsBody) {
        // optional: enemyBody.node?.removeFromParent() wenn du “Kamikaze” willst
        applyDamageToPlayer(amount: 5)
    }

    func handlePlayerPicksPowerUp(powerUpBody: SKPhysicsBody) {
        guard let node = powerUpBody.node as? SKSpriteNode else { return }
        handlePowerUpPickup(node)
    }
}

// MARK: - Helpers

private extension GameScene {

    struct BodyPair {
        let first: SKPhysicsBody
        let second: SKPhysicsBody
    }

    func orderedBodies(_ contact: SKPhysicsContact) -> BodyPair {
        if contact.bodyA.categoryBitMask < contact.bodyB.categoryBitMask {
            return BodyPair(first: contact.bodyA, second: contact.bodyB)
        } else {
            return BodyPair(first: contact.bodyB, second: contact.bodyA)
        }
    }
}
