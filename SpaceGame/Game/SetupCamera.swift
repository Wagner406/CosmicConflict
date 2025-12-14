//
//  SetupCamera.swift
//  SpaceGame
//

import SpriteKit

extension GameScene {

    func setupCamera() {
        camera = cameraNode
        addChild(cameraNode)

        cameraNode.position = playerShip.position
        cameraNode.setScale(cameraZoom)

        setupHUD() // kommt aus HUD.swift
    }
}
