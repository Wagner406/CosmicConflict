//
//  VFXBudget.swift
//  SpaceGame
//
//  Created by Alexander Wagner on 14.12.25.
//

import Foundation

final class VFXBudget {
    private(set) var remaining: Int
    private let maxPerFrame: Int

    init(maxPerFrame: Int = 80) {
        self.maxPerFrame = maxPerFrame
        self.remaining = maxPerFrame
    }

    func beginFrame() {
        remaining = maxPerFrame
    }

    func allow(_ cost: Int) -> Bool {
        guard remaining >= cost else { return false }
        remaining -= cost
        return true
    }
}
