//
//  VFXSystem+Projectiles.swift
//  SpaceGame
//
//  Created by Alexander Wagner on 14.12.25.
//

import SpriteKit

// MARK: - Projectiles / Weapons (Bullet Look, Muzzle Flash, Ghost Trail, Spawn Pop)

extension VFXSystem {

    // MARK: - Bullet Look (Nice glow, still cheap enough)

    /// Player bullet look: 2 shape nodes (core + glow).
    /// Looks like your original, but keeps everything inside VFX.
    func applyPlayerBulletLook(to bullet: SKSpriteNode) {
        bullet.removeAllChildren()

        let w = bullet.size.width
        let h = bullet.size.height

        let coreSize = CGSize(width: w * 0.55, height: h * 0.85)
        let radius = coreSize.width / 2

        // Core
        let core = SKShapeNode(rectOf: coreSize, cornerRadius: radius)
        core.fillColor = SKColor(red: 0.8, green: 0.95, blue: 1.0, alpha: 1.0)
        core.strokeColor = .clear
        core.glowWidth = coreSize.height * 0.9
        core.alpha = 0.95
        core.blendMode = .add
        core.zPosition = 0
        bullet.addChild(core)

        // Outer glow
        let outer = SKShapeNode(rectOf: coreSize, cornerRadius: radius)
        outer.fillColor = SKColor(red: 0.2, green: 0.6, blue: 1.0, alpha: 1.0)
        outer.strokeColor = .clear
        outer.glowWidth = coreSize.height * 1.3
        outer.alpha = 0.9
        outer.blendMode = .add
        outer.zPosition = -1
        bullet.addChild(outer)
    }

    /// Enemy bullet look: 2 shape nodes (core + glow).
    func applyEnemyBulletLook(to bullet: SKSpriteNode) {
        bullet.removeAllChildren()

        let w = bullet.size.width
        let h = bullet.size.height

        let coreSize = CGSize(width: w * 0.6, height: h * 0.9)
        let radius = coreSize.width / 2

        let core = SKShapeNode(rectOf: coreSize, cornerRadius: radius)
        core.fillColor = SKColor(red: 1.0, green: 0.85, blue: 0.7, alpha: 1.0)
        core.strokeColor = .clear
        core.glowWidth = coreSize.height * 1.0
        core.alpha = 0.95
        core.blendMode = .add
        core.zPosition = 0
        bullet.addChild(core)

        let outer = SKShapeNode(rectOf: coreSize, cornerRadius: radius)
        outer.fillColor = SKColor(red: 1.0, green: 0.25, blue: 0.15, alpha: 1.0)
        outer.strokeColor = .clear
        outer.glowWidth = coreSize.height * 1.4
        outer.alpha = 0.9
        outer.blendMode = .add
        outer.zPosition = -1
        bullet.addChild(outer)
    }

    // MARK: - Spawn Pop

    func applySpawnPop(to node: SKNode,
                       from startScale: CGFloat = 0.6,
                       to endScale: CGFloat = 1.0,
                       duration: TimeInterval = 0.06) {
        node.setScale(startScale)
        let pop = SKAction.scale(to: endScale, duration: duration)
        pop.timingMode = .easeOut
        node.run(pop, withKey: "vfx.spawnPop")
    }

    // MARK: - Ghost Trail (pooled)

    func attachGhostTrail(to bullet: SKSpriteNode,
                          color: SKColor,
                          spawnInterval: TimeInterval = 0.028,
                          dotSize: ClosedRange<CGFloat> = 3...6,
                          alpha: CGFloat = 0.55,
                          lifetime: TimeInterval = 0.16,
                          scaleTo: CGFloat = 0.2,
                          zOffset: CGFloat = -1) {

        bullet.removeAction(forKey: "vfx.ghostTrail")

        let spawnGhost = SKAction.run { [weak self, weak bullet] in
            guard let self, let bullet else { return }
            guard self.budget.allow(1) else { return }

            let angle = bullet.zRotation
            let dist  = bullet.size.height * 0.4

            let backX = sin(angle) * dist
            let backY = -cos(angle) * dist

            let pos = CGPoint(
                x: bullet.position.x + backX,
                y: bullet.position.y + backY
            )

            let s = CGFloat.random(in: dotSize)
            let dot = self.pool.makeSpark(color: color)
            dot.size = CGSize(width: s, height: s)
            dot.position = pos
            dot.zPosition = bullet.zPosition + zOffset
            dot.alpha = alpha
            dot.zRotation = 0

            self.layer.addChild(dot)

            let fade  = SKAction.fadeOut(withDuration: lifetime)
            let scale = SKAction.scale(to: scaleTo, duration: lifetime)

            let recycle = SKAction.run { [weak self, weak dot] in
                guard let self, let dot else { return }
                self.pool.recycleSpark(dot)
            }

            dot.run(.sequence([.group([fade, scale]), recycle]))
        }

        let seq = SKAction.sequence([
            .wait(forDuration: spawnInterval),
            spawnGhost
        ])

        bullet.run(.repeatForever(seq), withKey: "vfx.ghostTrail")
    }

    // MARK: - Muzzle Flash (uses your tuning)

    func spawnMuzzleFlash(at position: CGPoint,
                          directionAngle: CGFloat,
                          zPos: CGFloat) {

        // Core + beam should render, sparks optional
        guard budget.allow(2) else { return }

        // 1) Core
        let core = SKShapeNode(circleOfRadius: tuning.muzzleCoreRadius)
        core.position = position
        core.zPosition = zPos
        core.fillColor = .white
        core.strokeColor = .clear
        core.glowWidth = tuning.muzzleCoreGlow
        core.alpha = tuning.muzzleCoreAlpha
        core.blendMode = .add
        layer.addChild(core)

        let coreFade  = SKAction.fadeOut(withDuration: tuning.muzzleCoreDuration)
        let coreScale = SKAction.scale(to: 0.4, duration: tuning.muzzleCoreDuration)
        core.run(.sequence([.group([coreFade, coreScale]), .removeFromParent()]))

        // 2) Beam (pooled)
        let beam = pool.makeSpark(color: SKColor(red: 0.3, green: 0.7, blue: 1.0, alpha: 1.0))
        beam.size = CGSize(width: tuning.muzzleBeamLength, height: tuning.muzzleBeamThickness)
        beam.position = position
        beam.zPosition = zPos
        beam.alpha = tuning.muzzleBeamAlpha
        beam.zRotation = directionAngle
        layer.addChild(beam)

        let beamFade  = SKAction.fadeOut(withDuration: tuning.muzzleBeamDuration)
        let beamScale = SKAction.scaleX(to: 0.2, duration: tuning.muzzleBeamDuration)

        let recycleBeam = SKAction.run { [weak self, weak beam] in
            guard let self, let beam else { return }
            self.pool.recycleSpark(beam)
        }

        beam.run(.sequence([.group([beamFade, beamScale]), recycleBeam]))

        // 3) Sparks (optional + budget)
        var allowedSparks = 0
        for _ in 0..<tuning.muzzleSparkCount {
            if budget.allow(1) { allowedSparks += 1 } else { break }
        }
        guard allowedSparks > 0 else { return }

        for _ in 0..<allowedSparks {
            let sLength = CGFloat.random(in: tuning.muzzleSparkLength)
            let sThickness: CGFloat = tuning.muzzleSparkThickness

            let spark = pool.makeSpark(color: SKColor(red: 0.5, green: 0.8, blue: 1.0, alpha: 1.0))
            spark.size = CGSize(width: sLength, height: sThickness)
            spark.position = position
            spark.zPosition = zPos
            spark.alpha = 0.95

            let jitter = CGFloat.random(in: -(.pi/6)...(.pi/6))
            let a = directionAngle + jitter
            spark.zRotation = a

            let dist = CGFloat.random(in: tuning.muzzleSparkDistance)
            let dx = cos(a) * dist
            let dy = sin(a) * dist

            layer.addChild(spark)

            let dur = tuning.muzzleSparkDuration
            let move  = SKAction.moveBy(x: dx, y: dy, duration: dur)
            let fade  = SKAction.fadeOut(withDuration: dur)
            let scale = SKAction.scaleX(to: 0.2, duration: dur)

            let recycle = SKAction.run { [weak self, weak spark] in
                guard let self, let spark else { return }
                self.pool.recycleSpark(spark)
            }

            spark.run(.sequence([.group([move, fade, scale]), recycle]))
        }
    }
}
