//
//  VFXSystem+Shockwave.swift
//  SpaceGame
//
//  Created by Alexander Wagner on 14.12.25.
//

import SpriteKit

// MARK: - Shockwave + Camera Punch

extension VFXSystem {

    func triggerExplosionShockwave(at position: CGPoint) {
        // Ring
        let ring = SKShapeNode(circleOfRadius: tuning.shockwaveRadius)
        ring.position = position
        ring.zPosition = 999
        ring.strokeColor = .cyan
        ring.lineWidth = tuning.shockwaveLineWidth
        ring.glowWidth = tuning.shockwaveGlowWidth
        ring.fillColor = .clear
        ring.alpha = 0.9
        ring.setScale(tuning.shockwaveStartScale)

        layer.addChild(ring)

        let scaleUp = SKAction.scale(to: tuning.shockwaveEndScale, duration: tuning.shockwaveDuration)
        let fadeOut = SKAction.fadeOut(withDuration: tuning.shockwaveDuration)
        ring.run(.sequence([.group([scaleUp, fadeOut]), .removeFromParent()]))

        // Camera punch + shake
        runCameraPunchAndShake()
    }
}
