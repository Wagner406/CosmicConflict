//
//  UI.swift
//  SpaceGame
//
//  Created by Alexander Wagner on 30.11.25.
//

import UIKit

extension UIScreen {
    static var current: UIScreen? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.screen
    }
}
