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
        static let border = UIColor.label
        static let text = UIColor.label
        static let tagBackground = UIColor.systemBackground
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
        static let layerOffset: CGFloat = 4
        static let pressedTranslation: CGFloat = 4

        /// Adds a stacked layer behind the card for Neo-Brutalist depth effect
        @discardableResult
        static func applyStackedLayer(to cardView: UIView, in parentView: UIView) -> UIView {
            let layerView = UIView()
            layerView.backgroundColor = Colors.cardBackground
            layerView.translatesAutoresizingMaskIntoConstraints = false
            parentView.insertSubview(layerView, belowSubview: cardView)

            applyCardBorder(to: layerView.layer)

            NSLayoutConstraint.activate([
                layerView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: layerOffset),
                layerView.topAnchor.constraint(equalTo: cardView.topAnchor, constant: layerOffset),
                layerView.widthAnchor.constraint(equalTo: cardView.widthAnchor),
                layerView.heightAnchor.constraint(equalTo: cardView.heightAnchor),
            ])

            return layerView
        }

        static func applyCardBorder(to layer: CALayer) {
            layer.borderWidth = 1
            layer.borderColor = Colors.border.cgColor
        }

        static func updateLayerColors(for layer: CALayer) {
            layer.borderColor = Colors.border.cgColor
        }

        static func applyPressEffect(to view: UIView, isPressed: Bool) {
            view.transform = isPressed ? CGAffineTransform(translationX: pressedTranslation, y: pressedTranslation) : .identity
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
