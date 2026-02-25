//
//  NeoBrutalistPressable.swift
//  MetaX
//
//  Created by Yuhan Chen on 2026/02/25.
//

import UIKit

/// A protocol that provides Neo-Brutalist press animation capabilities to any UIView.
@MainActor
protocol NeoBrutalistPressable: UIView {
    var targetView: UIView { get }
}

extension NeoBrutalistPressable {
    func handleTouchesBegan() {
        Theme.Shadows.animatePress(for: targetView, isPressed: true)
    }

    func handleTouchesEnded(action: (() -> Void)? = nil) {
        Theme.Shadows.animatePress(for: targetView, isPressed: false) {
            action?()
        }
    }

    func handleTouchesCancelled() {
        Theme.Shadows.animatePress(for: targetView, isPressed: false)
    }
}
