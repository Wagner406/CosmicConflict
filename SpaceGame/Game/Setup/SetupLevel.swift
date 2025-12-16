//
//  SetupLevel.swift
//  SpaceGame
//

import SpriteKit

extension GameScene {

    func setupLevel() {
        let currentLevel = level ?? GameLevels.level1
        level = currentLevel

        levelNode = LevelFactory.makeLevelNode(for: currentLevel, size: size)
        addChild(levelNode)
    }
}
