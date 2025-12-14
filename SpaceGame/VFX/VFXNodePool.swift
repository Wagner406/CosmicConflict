//
//  VFXNodePool.swift
//  SpaceGame
//
//  Created by Alexander Wagner on 14.12.25.
//

import SpriteKit

final class VFXNodePool {

    private var sparkPool: [SKSpriteNode] = []
    private let maxSparks: Int

    init(maxSparks: Int = 400) {
        self.maxSparks = maxSparks
        sparkPool.reserveCapacity(maxSparks)
    }

    func makeSpark(color: SKColor) -> SKSpriteNode {
        if let node = sparkPool.popLast() {
            node.color = color
            node.colorBlendFactor = 1.0
            node.alpha = 1.0
            node.isHidden = false
            node.removeAllActions()
            return node
        }

        // 1x1 Sprite, Größe wird später gesetzt
        let node = SKSpriteNode(color: color, size: CGSize(width: 1, height: 1))
        node.blendMode = .add
        node.anchorPoint = CGPoint(x: 0.0, y: 0.5)
        return node
    }

    func recycleSpark(_ node: SKSpriteNode) {
        node.removeAllActions()
        node.isHidden = true
        node.removeFromParent()

        guard sparkPool.count < maxSparks else { return }
        sparkPool.append(node)
    }
}
