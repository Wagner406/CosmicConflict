//
//  ContactHandlersEnemy.swift
//  SpaceGame
//

import SpriteKit

// MARK: - Enemy / Bullet Contacts

extension GameScene {

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

        killEnemyNode(enemyNode, isShip: isShip)
        enemies.removeAll { $0 == enemyNode }
    }

    func handleEnemyBulletHitsPlayer(enemyBulletBody: SKPhysicsBody) {
        enemyBulletBody.node?.removeFromParent()
        applyDamageToPlayer(amount: 10)
    }

    func handleEnemyRamsPlayer(enemyBody: SKPhysicsBody) {
        // Optional: enemyBody.node?.removeFromParent() für Kamikaze
        applyDamageToPlayer(amount: 5)
    }

    // MARK: - Kill helper

    func killEnemyNode(_ enemyNode: SKSpriteNode, isShip: Bool) {
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
    }
}
