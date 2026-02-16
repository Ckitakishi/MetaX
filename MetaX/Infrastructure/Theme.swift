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
        static let launchBackground = UIColor(named: "LaunchBackground") ?? .systemBackground

        // Settings Colors (Matched with Rolog)
        static let settingsAppearance = UIColor(named: "SettingsAppearance") ?? .systemPurple
        static let settingsGeneral = UIColor(named: "SettingsGeneral") ?? .systemBlue
        static let settingsSupport = UIColor(named: "SettingsSupport") ?? .systemGreen
        static let settingsAbout = UIColor(named: "SettingsAbout") ?? .systemGray

        static let mainBackground = UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(white: 0.11, alpha: 1.0) : UIColor.systemGray6
        }

        static let sheetBackground = UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(white: 0.18, alpha: 1.0) : .systemBackground
        }

        static let cardBackground = sheetBackground
        static let border = UIColor.label
        static let text = UIColor.label
        static let tagBackground = mainBackground
    }

    // MARK: - Layout

    enum Layout {
        static let cardCornerRadius: CGFloat = 0
        static let imageCornerRadius: CGFloat = 0
        static let standardPadding: CGFloat = 16
        static let cellSpacing: CGFloat = 10
        static let stackSpacing: CGFloat = 24
        static let sectionHeaderHeight: CGFloat = 60
        static let horizontalMargin: CGFloat = 20
        /// Standard album thumbnail size in points (displayed as a square)
        static let thumbnailSize: CGFloat = 96
        /// 16:9 aspect ratio multiplier used for hero image views
        static let heroAspectRatio: CGFloat = 0.5625
        /// Initial height for the detail view image header (updated dynamically per asset)
        static let heroHeaderHeight: CGFloat = 320
    }

    // MARK: - Animation

    enum Animation {
        /// Duration for card press/highlight feedback
        static let pressEffect: TimeInterval = 0.1
        /// Duration for splash screen fade-out
        static let splashFade: TimeInterval = 0.35
    }

    // MARK: - Shadows

    enum Shadows {
        static let layerOffset: CGFloat = 4
        static let pressedTranslation: CGFloat = 4

        /// Adds a stacked layer behind the card for Neo-Brutalist depth effect
        @discardableResult
        static func applyStackedLayer(to cardView: UIView, in parentView: UIView, color: UIColor? = nil) -> UIView {
            let layerView = UIView()
            layerView.backgroundColor = color ?? Colors.cardBackground
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
            layer.borderWidth = 1.0
            layer.borderColor = Colors.border.cgColor
        }

        static func updateLayerColors(for layer: CALayer) {
            layer.borderColor = Colors.border.cgColor
        }

        static func applyPressEffect(to view: UIView, isPressed: Bool) {
            view
                .transform = isPressed ? CGAffineTransform(translationX: pressedTranslation, y: pressedTranslation) :
                .identity
        }
    }

    // MARK: - Typography

    enum Typography {
        /// For display-level titles (e.g. empty state, lock views)
        static let title = UIFont.systemFont(ofSize: 24, weight: .bold)
        /// Compact monospaced brand logotype for navigation bars
        static let navBrand = UIFont.monospacedDigitSystemFont(ofSize: 10, weight: .bold)
        /// For the most prominent titles (originally cardTitle)
        static let headline = UIFont.systemFont(ofSize: 14, weight: .semibold)
        /// For secondary titles or Section Headers
        static let subheadline = UIFont.systemFont(ofSize: 18, weight: .bold)
        /// For callout-sized body text (16pt)
        static let callout = UIFont.systemFont(ofSize: 16)
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
        /// Small font for hint/caption text
        static let hint = UIFont.systemFont(ofSize: 12, weight: .regular)
    }
}
