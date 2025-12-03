//
//  LevelFactory.swift
//  SpaceGame
//
//  Created by Alexander Wagner on 29.11.25.
//

import SpriteKit

enum LevelFactory {

    static func makeDemoLevel(size: CGSize) -> SKNode {
        let texture = SKTexture(imageNamed: "space1")   // dein Space-Level-Bild

        // Prüfen ob das Bild existiert
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

            // WELTGRÖSSE ERHÖHEN – HIER BESTIMMST DU WIE GROSS DIE MAP IST
            let worldScale: CGFloat = 2.0     // 3x so groß wie der Bildschirm → viel mehr Spielfläche
            finalWidth  *= worldScale
            finalHeight *= worldScale

            map.size = CGSize(width: finalWidth, height: finalHeight)

            // Map in der Mitte platzieren
            map.position = CGPoint(x: size.width / 2, y: size.height / 2)
            map.zPosition = 0

            return map
        }

        // Falls Bild fehlt
        let fallback = SKSpriteNode(color: .black, size: size)
        fallback.zPosition = 0
        return fallback
    }
}
