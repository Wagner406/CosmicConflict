//
//  EnemyHealthBars.swift
//  SpaceGame
//

import SpriteKit

extension GameScene {

    // MARK: - Enemy Health Bars

    func addEnemyHealthBar(to enemy: SKSpriteNode, maxHP: Int) {
        if enemy.userData == nil {
            enemy.userData = NSMutableDictionary()
        }
        enemy.userData?["maxHP"] = maxHP
        enemy.userData?["hp"] = maxHP

        let width = enemy.size.width * 3
        let height: CGFloat = 50

        let bg = SKSpriteNode(
            color: .black,
            size: CGSize(width: width, height: height)
        )
        bg.alpha = 0.6
        bg.position = CGPoint(
            x: 0,
            y: enemy.size.height / 2 + enemy.size.height * 3
        )
        bg.zPosition = enemy.zPosition + 1
        bg.name = "hpBarBackground"

        let bar = SKSpriteNode(
            color: .green,
            size: CGSize(width: width, height: height)
        )
        bar.anchorPoint = CGPoint(x: 0, y: 0.5)
        bar.position = CGPoint(x: -width / 2, y: 0)
        bar.zPosition = bg.zPosition + 1
        bar.name = "hpBar"

        bg.addChild(bar)
        enemy.addChild(bg)
    }

    func updateEnemyHealthBar(for enemy: SKSpriteNode) {
        guard
            let userData = enemy.userData,
            let hp = userData["hp"] as? Int,
            let maxHP = userData["maxHP"] as? Int,
            maxHP > 0,
            let bg = enemy.childNode(withName: "hpBarBackground") as? SKSpriteNode,
            let bar = bg.childNode(withName: "hpBar") as? SKSpriteNode
        else { return }

        let fraction = max(0, min(1, CGFloat(hp) / CGFloat(maxHP)))
        bar.xScale = fraction

        if fraction > 0.6 {
            bar.color = .green
        } else if fraction > 0.3 {
            bar.color = .yellow
        } else {
            bar.color = .red
        }
    }
}
