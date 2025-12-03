//
//  PowerUps.swift
//  SpaceGame
//

import SpriteKit

extension GameScene {

    // Wird in update(currentTime:) aufgerufen
    func handlePowerUpSpawning(currentTime: TimeInterval) {
        // Schon ein Powerup aktiv auf der Map? Dann kein neues
        if activePowerUpNode != nil { return }

        // Noch nicht genug Zeit vergangen?
        if currentTime - lastPowerUpSpawnTime < powerUpMinInterval {
            return
        }

        lastPowerUpSpawnTime = currentTime
        spawnRandomPowerUp()
    }

    func spawnRandomPowerUp() {
        guard let level = levelNode else { return }

        // Zufälliger Typ
        let types: [PowerUpType] = [.health, .tripleShot, .shield]
        guard let type = types.randomElement() else { return }

        // 🎨 Sprite pro Typ – HIER deine Asset-Namen eintragen!
        let textureName: String
        let nodeName: String

        switch type {
        case .health:
            textureName = "PowerupHealth"   // <- Asset-Name im xcassets
            nodeName    = "powerup_health"

        case .tripleShot:
            textureName = "PowerupTriple"   // <- Asset-Name im xcassets
            nodeName    = "powerup_triple"

        case .shield:
            textureName = "PowerupShield"   // <- Asset-Name im xcassets
            nodeName    = "powerup_shield"
        }

        let texture = SKTexture(imageNamed: textureName)
        let sprite: SKSpriteNode

        if texture.size() != .zero {
            sprite = SKSpriteNode(texture: texture)

            // Zielbreite ~15% der Bildschirmbreite
            let desiredWidth = size.width * 0.15
            let scale = desiredWidth / texture.size().width
            sprite.setScale(scale)
        } else {
            // Fallback, falls Asset fehlt
            let sizeBox = CGSize(width: 40, height: 40)
            sprite = SKSpriteNode(color: .white, size: sizeBox)
        }

        sprite.name = nodeName
        sprite.zPosition = 15

        // zufällige Position innerhalb der Map
        let margin: CGFloat = 80

        let minX = level.frame.minX + margin
        let maxX = level.frame.maxX - margin
        let minY = level.frame.minY + margin
        let maxY = level.frame.maxY - margin

        let x = CGFloat.random(in: minX...maxX)
        let y = CGFloat.random(in: minY...maxY)
        sprite.position = CGPoint(x: x, y: y)

        // Physik (nach dem Skalieren!)
        let body = SKPhysicsBody(rectangleOf: sprite.size)
        body.isDynamic = false
        body.affectedByGravity = false
        body.categoryBitMask = PhysicsCategory.powerUp
        body.collisionBitMask = 0
        body.contactTestBitMask = PhysicsCategory.player
        sprite.physicsBody = body

        addChild(sprite)
        activePowerUpNode = sprite
    }

    func handlePowerUpPickup(_ node: SKSpriteNode) {
        guard let name = node.name else { return }

        // Powerup entfernen
        node.removeFromParent()
        if activePowerUpNode == node {
            activePowerUpNode = nil
        }

        if name == "powerup_health" {
            playerHP = playerMaxHP
            updatePlayerHealthBar()

        } else if name == "powerup_triple" {
            isTripleShotActive = true
            tripleShotEndTime = currentTimeForCollisions + 10.0
            setActivePowerUpLabel("Triple Shot")

        } else if name == "powerup_shield" {
            activateShield()
        }
    }

    // MARK: - Schild aktivieren

    func activateShield() {
        guard let ship = playerShip else { return }

        isShieldActive = true
        shieldEndTime = currentTimeForCollisions + 10.0
        setActivePowerUpLabel("Shield")

        // alte Aura entfernen, falls noch vorhanden
        shieldNode?.removeFromParent()
        shieldNode = nil

        // 🔵 Schild-Aura – HIER den Asset-Namen für dein Schildbild eintragen
        let shieldTexture = SKTexture(imageNamed: "ShieldAura") // <-- dein Schild-Asset

        let aura: SKSpriteNode
        if shieldTexture.size() != .zero {
            aura = SKSpriteNode(texture: shieldTexture)

            // Schild etwas größer als das Schiff
            let desiredDiameter = max(ship.size.width, ship.size.height) * 15
            let baseSize = max(shieldTexture.size().width, shieldTexture.size().height)
            let scale = desiredDiameter / baseSize
            aura.setScale(scale)
            aura.alpha = 0.85
        } else {
            // Fallback, falls das Bild fehlt
            aura = SKSpriteNode(
                color: .cyan,
                size: CGSize(width: ship.size.width * 1.8,
                             height: ship.size.height * 1.8)
            )
            aura.alpha = 0.35
        }

        aura.zPosition = ship.zPosition - 1
        aura.position = .zero          // als Kind vom Schiff → zentriert
        aura.name = "shieldAura"

        ship.addChild(aura)
        shieldNode = aura
    }
}
