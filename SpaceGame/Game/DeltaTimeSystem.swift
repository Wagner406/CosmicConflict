//
//  DeltaTimeSystem.swift
//  SpaceGame
//

import CoreGraphics
import Foundation

/// Small helper to compute per-frame deltaTime from SpriteKit's currentTime.
struct DeltaTimeSystem {

    private(set) var lastUpdateTime: TimeInterval = 0

    mutating func reset() {
        lastUpdateTime = 0
    }

    /// Returns deltaTime in seconds as CGFloat.
    /// First frame returns 0.
    mutating func deltaTime(for currentTime: TimeInterval) -> CGFloat {
        let dt: CGFloat
        if lastUpdateTime == 0 {
            dt = 0
        } else {
            dt = CGFloat(currentTime - lastUpdateTime)
        }
        lastUpdateTime = currentTime
        return dt
    }
}
