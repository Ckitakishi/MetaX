//
//  Theme.swift
//  MetaX
//
//  Created by Yuhan Chen on 2026/02/08.
//

import UIKit

enum Theme {
    // MARK: - Colors
    enum Colors {
        static let accent = UIColor(named: "greenSea") ?? .systemTeal
        static let cardBackground = UIColor.secondarySystemGroupedBackground
        static let mainBackground = UIColor.systemGroupedBackground
    }
    
    // MARK: - Layout
    enum Layout {
        static let cardCornerRadius: CGFloat = 0
        static let imageCornerRadius: CGFloat = 0
        static let cardPadding: CGFloat = 16
        static let cellSpacing: CGFloat = 10
        static let sectionHeaderHeight: CGFloat = 60
        static let horizontalMargin: CGFloat = 20
    }
    
    // MARK: - Shadows
    enum Shadows {
        static let normalShadowOffset = CGSize(width: 4, height: 4)
        static let pressedShadowOffset = CGSize(width: 1.5, height: 1.5)

        static func applyCardShadow(to layer: CALayer) {
            layer.shadowColor = UIColor.black.cgColor
            layer.shadowOpacity = 1.0
            layer.shadowOffset = normalShadowOffset
            layer.shadowRadius = 0
        }

        static func applyCardBorder(to layer: CALayer) {
            layer.borderWidth = 1
            layer.borderColor = UIColor.black.cgColor
        }

        static func applyPressEffect(to view: UIView, isPressed: Bool) {
            view.transform = isPressed ? CGAffineTransform(translationX: 1.5, y: 1.5) : .identity
            view.layer.shadowOffset = isPressed ? pressedShadowOffset : normalShadowOffset
        }
    }
    
    // MARK: - Typography
    enum Typography {
        /// For the most prominent titles (originally cardTitle)
        static let headline = UIFont.systemFont(ofSize: 15, weight: .bold)
        /// For secondary titles or Section Headers
        static let subheadline = UIFont.systemFont(ofSize: 18, weight: .heavy)
        /// Standard body text - medium weight (originally bodyMedium)
        static let bodyMedium = UIFont.systemFont(ofSize: 15, weight: .medium)
        /// Standard body text - regular weight (originally bodyRegular)
        static let body = UIFont.systemFont(ofSize: 15, weight: .regular)
        /// For supplementary info and labels (originally caption, propLabel)
        static let footnote = UIFont.systemFont(ofSize: 13, weight: .regular)
        /// Monospaced font for metadata display (originally metaMono)
        static let captionMono = UIFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        /// Monospaced font for Header indices
        static let indexMono = UIFont.monospacedDigitSystemFont(ofSize: 14, weight: .bold)
    }
}