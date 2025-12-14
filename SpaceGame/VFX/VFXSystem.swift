//
//  VFXSystem.swift
//  SpaceGame
//
//  Created by Alexander Wagner on 14.12.25.
//

import SpriteKit

// MARK: - VFXSystem (Core)

/// One-shot Effects (Hit-Sparks, Shockwave, SpriteSheet Explosions)
/// - Adds everything into a dedicated `layer` node (clean scene graph)
/// - Caches sprite-sheet frames (performance)
/// - Clean API: no "in scene:" needed after init
final class VFXSystem {

    // MARK: Performance

    /// NOTE: Must be internal (not `private`) because extensions live in other files.
    let pool = VFXNodePool(maxSparks: 500)
    let budget = VFXBudget(maxPerFrame: 120)

    // MARK: Dependencies

    private unowned let scene: SKScene
    private weak var camera: SKCameraNode?

    // MARK: Layer

    /// All VFX nodes go into this container.
    /// You can move it above/below other layers via zPosition.
    let layer = SKNode()

    // MARK: Tuning

    struct Tuning {
        // Hit
        var hitFlashDuration: TimeInterval = 0.06
        var hitSparkDuration: TimeInterval = 0.18
        var hitSparkDistance: ClosedRange<CGFloat> = 60...120
        var hitSparkLength: ClosedRange<CGFloat> = 18...32
        var hitSparkThickness: ClosedRange<CGFloat> = 3...5

        // Explosion sparks
        var explosionSparkDuration: TimeInterval = 0.35
        var explosionSparkDistance: ClosedRange<CGFloat> = 80...180
        var explosionSparkLength: ClosedRange<CGFloat> = 14...26
        var explosionSparkThickness: ClosedRange<CGFloat> = 3...6

        // Shockwave
        var shockwaveRadius: CGFloat = 80
        var shockwaveLineWidth: CGFloat = 6
        var shockwaveGlowWidth: CGFloat = 10
        var shockwaveStartScale: CGFloat = 0.2
        var shockwaveEndScale: CGFloat = 1.4
        var shockwaveDuration: TimeInterval = 0.18

        // Camera punch + shake
        var punchScaleMultiplier: CGFloat = 0.92
        var punchInDuration: TimeInterval = 0.05
        var punchOutDuration: TimeInterval = 0.12
        var shakeAmount: CGFloat = 8
        var shakeDuration: TimeInterval = 0.16

        // Sprite sheet timing
        var sheetTimePerFrame: TimeInterval = 0.05
        var sheetFadeOutDuration: TimeInterval = 0.5

        // Asteroid destruction drift
        var asteroidDriftDuration: TimeInterval = 0.5
    }

    var tuning = Tuning()

    // MARK: Cached sprite-sheet frames

    /// Must be internal for extensions in other files.
    var cachedEnemyExplosionFrames: [SKTexture]?
    var cachedAsteroidDestroyFrames: [SKTexture]?

    // MARK: Init

    init(scene: SKScene, camera: SKCameraNode? = nil, zPosition: CGFloat = 900) {
        self.scene = scene
        self.camera = camera

        layer.zPosition = zPosition
        scene.addChild(layer)
    }

    func setCamera(_ camera: SKCameraNode?) {
        self.camera = camera
    }

    // MARK: - Frame Budget

    /// Call once per frame (e.g. at top of GameScene.update).
    func beginFrame() {
        budget.beginFrame()
    }

    // MARK: - Shared Helpers (Frames)

    func makeFrames(from sheet: SKTexture, rows: Int, cols: Int) -> [SKTexture] {
        var frames: [SKTexture] = []
        frames.reserveCapacity(rows * cols)

        // order: top-left -> top-right -> next row ...
        for row in 0..<rows {
            for col in 0..<cols {
                let originX = CGFloat(col) / CGFloat(cols)
                let originY = 1.0 - CGFloat(row + 1) / CGFloat(rows)

                let rect = CGRect(
                    x: originX,
                    y: originY,
                    width: 1.0 / CGFloat(cols),
                    height: 1.0 / CGFloat(rows)
                )

                frames.append(SKTexture(rect: rect, in: sheet))
            }
        }

        return frames
    }

    // MARK: - Shared Helpers (Camera)

    func runCameraPunchAndShake() {
        guard let cam = camera else { return }

        let originalScale = cam.xScale
        let punchIn  = SKAction.scale(to: originalScale * tuning.punchScaleMultiplier,
                                      duration: tuning.punchInDuration)
        let punchOut = SKAction.scale(to: originalScale,
                                      duration: tuning.punchOutDuration)
        punchIn.timingMode = .easeOut
        punchOut.timingMode = .easeIn

        let shakeAmount = tuning.shakeAmount
        let shakeDuration = tuning.shakeDuration

        let moveLeft  = SKAction.moveBy(x: -shakeAmount, y: 0, duration: shakeDuration / 4)
        let moveRight = SKAction.moveBy(x:  shakeAmount * 2, y: 0, duration: shakeDuration / 4)
        let moveBack  = SKAction.moveBy(x: -shakeAmount, y: 0, duration: shakeDuration / 4)
        let moveUp    = SKAction.moveBy(x: 0, y: shakeAmount, duration: shakeDuration / 4)
        let moveDown  = SKAction.moveBy(x: 0, y: -shakeAmount, duration: shakeDuration / 4)

        cam.run(.sequence([punchIn, punchOut]))
        cam.run(.sequence([moveLeft, moveRight, moveBack, moveUp, moveDown]))
    }
}
