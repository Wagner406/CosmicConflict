//
//  LevelFactory.swift
//  SpaceGame
//
//  Created by Alexander Wagner on 29.11.25.
//

import SpriteKit

enum LevelFactory {

    /// Allgemeine Funktion: baut eine Map für ein GameLevel
    static func makeLevelNode(for level: GameLevel, size: CGSize) -> SKNode {
        let textureName = level.config.backgroundTextureName
        let texture = SKTexture(imageNamed: textureName)

        if texture.size() != .zero {
            let map = SKSpriteNode(texture: texture)

            // Seitenverhältnisse
            let sceneAspect = size.width / size.height
            let imageAspect = texture.size().width / texture.size().height

            var finalWidth = size.width
            var finalHeight = size.height

            // Bild korrekt skalieren ohne Verzerrung
            if imageAspect > sceneAspect {
                finalHeight = size.height
                finalWidth  = size.height * imageAspect
            } else {
                finalWidth  = size.width
                finalHeight = size.width / imageAspect
            }

            // Weltgröße über LevelConfig
            let worldScale = level.config.worldScale
            finalWidth  *= worldScale
            finalHeight *= worldScale

            map.size = CGSize(width: finalWidth, height: finalHeight)

            // Map in der Mitte platzieren
            map.position = CGPoint(x: size.width / 2, y: size.height / 2)
            map.zPosition = 0

            return map
        }

        // Fallback falls Textur fehlt
        let fallback = SKSpriteNode(color: .black, size: size)
        fallback.zPosition = 0
        return fallback
    }

    /// Kompatibilitäts-Helper für deinen alten Code
    static func makeDemoLevel(size: CGSize) -> SKNode {
        return makeLevelNode(for: GameLevels.level1, size: size)
    }
}
