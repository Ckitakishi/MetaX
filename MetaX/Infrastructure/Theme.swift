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

        // MARK: Settings Colors

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
        /// Standard album thumbnail size.
        static let thumbnailSize: CGFloat = 96
        /// 16:9 aspect ratio for hero images.
        static let heroAspectRatio: CGFloat = 0.5625
        /// Base height for asset detail headers.
        static let heroHeaderHeight: CGFloat = 320
    }

    // MARK: - Animation

    enum Animation {
        static let pressEffect: TimeInterval = 0.1
        static let splashFade: TimeInterval = 0.35
    }

    // MARK: - Shadows

    @MainActor
    enum Shadows {
        static let layerOffset: CGFloat = 4
        static let pressedTranslation: CGFloat = 4

        /// Adds a stacked layer behind the card for a Neo-Brutalist depth effect.
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

        /// Provides a unified animation for Neo-Brutalist press feedback.
        static func animatePress(for view: UIView, isPressed: Bool, completion: (() -> Void)? = nil) {
            UIView.animate(
                withDuration: Animation.pressEffect,
                delay: 0,
                options: [.allowUserInteraction, .beginFromCurrentState],
                animations: {
                    applyPressEffect(to: view, isPressed: isPressed)
                },
                completion: { _ in completion?() }
            )
        }
    }

    // MARK: - Typography

    enum Typography {
        /// Large poster/display title (e.g., Support page header).
        static let poster = UIFont.systemFont(ofSize: 32, weight: .bold)
        /// Display titles (e.g., empty state).
        static let title = UIFont.systemFont(ofSize: 24, weight: .bold)
        /// Monospaced logotype for navigation bars.
        static let navBrand = UIFont.monospacedDigitSystemFont(ofSize: 10, weight: .bold)
        /// Prominent headline titles.
        static let headline = UIFont.systemFont(ofSize: 14, weight: .semibold)
        /// Section headers.
        static let subheadline = UIFont.systemFont(ofSize: 18, weight: .bold)
        /// Standard callout text.
        static let callout = UIFont.systemFont(ofSize: 16)
        /// Standard body text (medium).
        static let bodyMedium = UIFont.systemFont(ofSize: 15, weight: .medium)
        /// Standard body text (regular).
        static let body = UIFont.systemFont(ofSize: 15, weight: .regular)
        /// Supplementary info and labels.
        static let footnote = UIFont.systemFont(ofSize: 13, weight: .regular)
        /// Monospaced font for metadata display.
        static let captionMono = UIFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        /// Monospaced font for header indices.
        static let indexMono = UIFont.monospacedDigitSystemFont(ofSize: 14, weight: .bold)
        /// Hint or caption text.
        static let hint = UIFont.systemFont(ofSize: 12, weight: .regular)
    }
}
