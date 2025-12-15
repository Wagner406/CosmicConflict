//
//  PowerUps.swift
//  SpaceGame
//

import SpriteKit

extension GameScene {

    // MARK: - Helpers

    private func clamp(_ value: CGFloat, _ minV: CGFloat, _ maxV: CGFloat) -> CGFloat {
        return max(minV, min(maxV, value))
    }

    /// "Welt"-Basisgröße (Level-Node), stabil über iPhone/iPad/Rotation
    private func worldBaseSize() -> CGFloat {
        guard let lvl = levelNode else { return min(size.width, size.height) }
        return min(lvl.frame.width, lvl.frame.height)
    }

    // MARK: - Spawning

    /// Wird in update(currentTime:) aufgerufen
    func handlePowerUpSpawning(currentTime: TimeInterval) {
        if activePowerUpNode != nil { return }
        if currentTime - lastPowerUpSpawnTime < powerUpMinInterval { return }

        lastPowerUpSpawnTime = currentTime
        spawnRandomPowerUp()
    }

    func spawnRandomPowerUp() {
        guard let level = levelNode else { return }

        let types: [PowerUpType] = [.health, .tripleShot, .shield]
        guard let type = types.randomElement() else { return }

        let textureName: String
        let nodeName: String

        switch type {
        case .health:
            textureName = "PowerupHealth"
            nodeName    = "powerup_health"
        case .tripleShot:
            textureName = "PowerupTriple"
            nodeName    = "powerup_triple"
        case .shield:
            textureName = "PowerupShield"
            nodeName    = "powerup_shield"
        }

        let texture = SKTexture(imageNamed: textureName)
        let sprite: SKSpriteNode

        if texture.size() != .zero {
            sprite = SKSpriteNode(texture: texture)

            // ✅ Welt-/Level-basiertes Sizing (stabil auf iPad/Landscape)
            let base = worldBaseSize()
            let desiredWidth = clamp(base * 0.06, 34, 70) // <- ggf. feinjustieren
            let scale = desiredWidth / max(1, texture.size().width)
            sprite.setScale(scale)
        } else {
            sprite = SKSpriteNode(color: .white, size: CGSize(width: 40, height: 40))
        }

        sprite.name = nodeName
        sprite.zPosition = 15

        // zufällige Position innerhalb der Map
        let margin: CGFloat = 80
        let minX = level.frame.minX + margin
        let maxX = level.frame.maxX - margin
        let minY = level.frame.minY + margin
        let maxY = level.frame.maxY - margin

        sprite.position = CGPoint(
            x: CGFloat.random(in: minX...maxX),
            y: CGFloat.random(in: minY...maxY)
        )

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

    // MARK: - Pickup

    func handlePowerUpPickup(_ node: SKSpriteNode) {
        guard let name = node.name else { return }

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

    // MARK: - Shield

    func activateShield() {
        guard let ship = playerShip else { return }

        let now = (currentTimeForCollisions > 0) ? currentTimeForCollisions : lastUpdateTime

        isShieldActive = true
        shieldEndTime = now + 10.0
        setActivePowerUpLabel("Shield")

        // 🔥 ALLES alte Shield-Zeug weg
        ship.childNode(withName: "shieldAura")?.removeFromParent()
        shieldNode?.removeAllActions()
        shieldNode?.removeFromParent()
        shieldNode = nil

        let tex = SKTexture(imageNamed: "ShieldAura")

        let aura: SKSpriteNode
        var baseScale: CGFloat = 1.0

        if tex.size() != .zero {
            aura = SKSpriteNode(texture: tex)

            let desiredDiameter = max(ship.size.width, ship.size.height) * 1.6
            let baseSize = max(tex.size().width, tex.size().height)
            baseScale = desiredDiameter / max(1, baseSize)

            aura.setScale(baseScale)
            aura.alpha = 0.85
            aura.blendMode = .add

            // ✅ Visibility-Boost (falls Textur sehr transparent ist)
            aura.color = .cyan
            aura.colorBlendFactor = 0.35
        } else {
            aura = SKSpriteNode(
                color: .cyan,
                size: CGSize(width: ship.size.width * 1.8,
                             height: ship.size.height * 1.8)
            )
            aura.alpha = 0.55
            aura.blendMode = .add
        }

        aura.name = "shieldAura"
        aura.zPosition = ship.zPosition + 50   // ✅ garantiert vor Player + Gegnern
        aura.position = ship.position
        aura.zRotation = ship.zRotation

        let pulseUp = SKAction.group([
            .scale(to: baseScale * 1.06, duration: 0.35),
            .fadeAlpha(to: 1.0, duration: 0.35)
        ])
        let pulseDown = SKAction.group([
            .scale(to: baseScale * 0.97, duration: 0.35),
            .fadeAlpha(to: 0.7, duration: 0.35)
        ])
        aura.run(.repeatForever(.sequence([pulseUp, pulseDown])), withKey: "shieldPulse")

        // ✅ NICHT als Child vom Ship, sondern in die Szene (robuster)
        addChild(aura)
        shieldNode = aura
    }

    // MARK: - Durations

    func updatePowerUpDurations(currentTime: TimeInterval) {

        // ✅ Shield folgt dem Player, solange aktiv
        if isShieldActive, let ship = playerShip, let aura = shieldNode {
            aura.position = ship.position
            aura.zRotation = ship.zRotation
            aura.zPosition = ship.zPosition + 50
        }

        if isTripleShotActive && currentTime >= tripleShotEndTime {
            isTripleShotActive = false
            setActivePowerUpLabel(isShieldActive ? "Shield" : nil)
        }

        if isShieldActive && currentTime >= shieldEndTime {
            isShieldActive = false

            if !isPlayerInvulnerable {
                playerShip.alpha = 1.0
            }

            // ✅ Cleanup: auch falls irgendwo noch ein altes Child-Shield hängt
            playerShip?.childNode(withName: "shieldAura")?.removeFromParent()

            shieldNode?.removeFromParent()
            shieldNode = nil

            setActivePowerUpLabel(isTripleShotActive ? "Triple Shot" : nil)
        }
    }
}
