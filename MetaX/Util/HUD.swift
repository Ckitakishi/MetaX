//
//  HUD.swift
//  MetaX
//
//  Created by Yuhan Chen on 2026/02/09.
//

import UIKit

@MainActor
final class HUD {
    static let shared = HUD()

    private var containerView: UIView?
    private var hudView: UIView?
    // Incremented on each show(); auto-dismiss closures capture their own generation
    // so they only dismiss the HUD they were created for.
    private var showGeneration: Int = 0

    private init() {}

    enum HUDType {
        case processing(String)
        case info(String)
        case error(String)
    }

    static func showProcessing(with message: String) {
        shared.show(.processing(message))
    }

    static func showInfo(with message: String) {
        shared.show(.info(message))
    }

    static func showError(with message: String) {
        shared.show(.error(message))
    }

    static func dismiss() {
        shared.hide()
    }

    private func show(_ type: HUDType) {
        hide()

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) else { return }

        let container = UIView(frame: window.bounds)
        container.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        container.backgroundColor = UIColor.black.withAlphaComponent(0.2)
        container.alpha = 0
        self.containerView = container

        let hud = UIView()
        hud.backgroundColor = Theme.Colors.tagBackground
        hud.layer.borderWidth = 2
        hud.layer.borderColor = Theme.Colors.border.cgColor
        hud.translatesAutoresizingMaskIntoConstraints = false
        hud.registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: UIView, _: UITraitCollection) in
            view.layer.borderColor = Theme.Colors.border.cgColor
        }
        self.hudView = hud

        container.addSubview(hud)
        window.addSubview(container)

        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        hud.addSubview(stackView)

        let messageLabel = UILabel()
        messageLabel.font = Theme.Typography.bodyMedium
        messageLabel.textColor = Theme.Colors.text
        messageLabel.numberOfLines = 0
        messageLabel.textAlignment = .center

        switch type {
        case .processing(let message):
            let activity = UIActivityIndicatorView(style: .medium)
            activity.color = Theme.Colors.text
            activity.startAnimating()
            stackView.addArrangedSubview(activity)
            messageLabel.text = message
        case .info(let message):
            let icon = UIImageView(image: UIImage(systemName: "info.circle"))
            icon.tintColor = Theme.Colors.text
            icon.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                icon.widthAnchor.constraint(equalToConstant: 28),
                icon.heightAnchor.constraint(equalToConstant: 28)
            ])
            stackView.addArrangedSubview(icon)
            messageLabel.text = message
        case .error(let message):
            let icon = UIImageView(image: UIImage(systemName: "exclamationmark.triangle"))
            icon.tintColor = .systemRed
            icon.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                icon.widthAnchor.constraint(equalToConstant: 28),
                icon.heightAnchor.constraint(equalToConstant: 28)
            ])
            stackView.addArrangedSubview(icon)
            messageLabel.text = message
        }

        stackView.addArrangedSubview(messageLabel)

        NSLayoutConstraint.activate([
            hud.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            hud.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            hud.widthAnchor.constraint(greaterThanOrEqualToConstant: 120),
            hud.widthAnchor.constraint(lessThanOrEqualTo: container.widthAnchor, multiplier: 0.8),

            stackView.topAnchor.constraint(equalTo: hud.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: hud.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: hud.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: hud.bottomAnchor, constant: -20)
        ])

        UIView.animate(withDuration: 0.2) {
            container.alpha = 1
        }

        if case .processing = type { return }

        showGeneration += 1
        let generation = showGeneration
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard let self, self.showGeneration == generation else { return }
            self.hide()
        }
    }

    private func hide() {
        guard let container = containerView else { return }
        // Clear singleton references immediately so a rapid show() call sees
        // a clean state; the local `container` keeps the view alive through
        // the animation via ARC.
        containerView = nil
        hudView = nil
        container.layer.removeAllAnimations()
        UIView.animate(withDuration: 0.2, animations: {
            container.alpha = 0
        }) { _ in
            container.removeFromSuperview()
        }
    }
}
