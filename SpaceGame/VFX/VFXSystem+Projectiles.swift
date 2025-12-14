//
//  VFXSystem+Projectiles.swift
//  SpaceGame
//
//  Created by Alexander Wagner on 14.12.25.
//

import SpriteKit

// MARK: - Projectiles / Weapons (Muzzle Flash, Ghost Trail, Spawn Pop)

extension VFXSystem {

    // MARK: Spawn Pop

    /// Small scale-pop when spawning a projectile (purely visual).
    func applySpawnPop(to node: SKNode,
                       from startScale: CGFloat = 0.6,
                       to endScale: CGFloat = 1.0,
                       duration: TimeInterval = 0.06) {
        node.setScale(startScale)
        let pop = SKAction.scale(to: endScale, duration: duration)
        pop.timingMode = .easeOut
        node.run(pop, withKey: "vfx.spawnPop")
    }

    // MARK: Ghost Trail (pooled)

    /// Lightweight ghost trail using pooled sprite nodes (no SKShapeNode spam).
    /// Attach this to bullets (player + enemy).
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

            // behind the projectile (local -Y)
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
            dot.size = CGSize(width: s, height: s) // square "dot" (cheap)
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

    // MARK: Muzzle Flash

    /// Short muzzle flash at the muzzle position.
    /// Uses pooled nodes for beam + sparks (cheap) and a single SKShapeNode for the bright core (okay).
    func spawnMuzzleFlash(at position: CGPoint,
                          directionAngle: CGFloat,
                          zPos: CGFloat,
                          coreRadius: CGFloat = 14,
                          beamLength: CGFloat = 36,
                          beamThickness: CGFloat = 10,
                          sparkCount: Int = 4) {

        // If the frame is already busy, skip extra sparks first.
        // (Core + beam are cheap-ish, sparks are the noisy part.)
        let allowSparks = budget.allow(max(0, sparkCount))

        // 1) bright core (single shape node)
        let core = SKShapeNode(circleOfRadius: coreRadius)
        core.position = position
        core.zPosition = zPos
        core.fillColor = .white
        core.strokeColor = .clear
        core.glowWidth = coreRadius * 2.0
        core.alpha = 0.95
        core.blendMode = .add
        layer.addChild(core)

        let coreDuration: TimeInterval = 0.06
        let coreFade  = SKAction.fadeOut(withDuration: coreDuration)
        let coreScale = SKAction.scale(to: 0.4, duration: coreDuration)
        core.run(.sequence([.group([coreFade, coreScale]), .removeFromParent()]))

        // 2) forward beam (pooled)
        let beam = pool.makeSpark(color: SKColor(red: 0.3, green: 0.7, blue: 1.0, alpha: 1.0))
        beam.size = CGSize(width: beamLength, height: beamThickness)
        beam.position = position
        beam.zPosition = zPos
        beam.alpha = 0.9
        beam.zRotation = directionAngle
        layer.addChild(beam)

        let beamDuration: TimeInterval = 0.07
        let beamFade  = SKAction.fadeOut(withDuration: beamDuration)
        let beamScale = SKAction.scaleX(to: 0.2, duration: beamDuration)

        let recycleBeam = SKAction.run { [weak self, weak beam] in
            guard let self, let beam else { return }
            self.pool.recycleSpark(beam)
        }

        beam.run(.sequence([.group([beamFade, beamScale]), recycleBeam]))

        // 3) tiny muzzle sparks (pooled)
        guard allowSparks, sparkCount > 0 else { return }

        for _ in 0..<sparkCount {
            let sLength: CGFloat = CGFloat.random(in: 10...18)
            let sThickness: CGFloat = 3

            let spark = pool.makeSpark(color: SKColor(red: 0.5, green: 0.8, blue: 1.0, alpha: 1.0))
            spark.size = CGSize(width: sLength, height: sThickness)
            spark.position = position
            spark.zPosition = zPos
            spark.alpha = 0.95

            let jitter = CGFloat.random(in: -(.pi/6)...(.pi/6))
            let a = directionAngle + jitter
            spark.zRotation = a

            let dist: CGFloat = CGFloat.random(in: 18...36)
            let dx = cos(a) * dist
            let dy = sin(a) * dist

            layer.addChild(spark)

            let dur: TimeInterval = 0.09
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
