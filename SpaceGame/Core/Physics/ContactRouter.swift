//
//  ContactRouter.swift
//  SpaceGame
//

import SpriteKit

// MARK: - Physics Contact Router

extension GameScene {

    func didBegin(_ contact: SKPhysicsContact) {
        let pair = orderedBodies(contact)
        routeContact(first: pair.first, second: pair.second, contact: contact)
    }
}

// MARK: - Routing (only)

fileprivate extension GameScene {

    func routeContact(first: SKPhysicsBody, second: SKPhysicsBody, contact: SKPhysicsContact) {

        if first.categoryBitMask == PhysicsCategory.bullet,
           second.categoryBitMask == PhysicsCategory.enemy {
            handleBulletHitsEnemy(bulletBody: first, enemyBody: second, contact: contact)
            return
        }

        if first.categoryBitMask == PhysicsCategory.player,
           second.categoryBitMask == PhysicsCategory.enemyBullet {
            handleEnemyBulletHitsPlayer(enemyBulletBody: second)
            return
        }

        if first.categoryBitMask == PhysicsCategory.player,
           second.categoryBitMask == PhysicsCategory.enemy {
            handleEnemyRamsPlayer(enemyBody: second)
            return
        }

        if first.categoryBitMask == PhysicsCategory.player,
           second.categoryBitMask == PhysicsCategory.powerUp {
            handlePlayerPicksPowerUp(powerUpBody: second)
            return
        }
    }
}

// MARK: - Helpers

fileprivate extension GameScene {

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
