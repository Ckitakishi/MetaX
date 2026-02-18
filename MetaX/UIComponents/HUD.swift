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
    /// Incremented on each show(); auto-dismiss closures capture their own generation
    /// so they only dismiss the HUD they were created for.
    private var showGeneration: Int = 0

    private var downloadProgressLayer: CAShapeLayer?
    private var downloadProgressLabel: UILabel?

    private init() {}

    enum HUDType {
        case processing(String)
        case downloading
        case info(String)
        case error(String)
    }

    static func showProcessing(with message: String) {
        shared.show(.processing(message))
    }

    static func showDownloading() {
        shared.show(.downloading)
    }

    static func updateDownloadProgress(_ progress: Double) {
        shared.updateDownloadProgress(progress)
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
        containerView = container

        let hud = UIView()
        hud.backgroundColor = Theme.Colors.tagBackground
        hud.layer.borderWidth = 2
        hud.layer.borderColor = Theme.Colors.border.cgColor
        hud.translatesAutoresizingMaskIntoConstraints = false
        hud.registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: UIView, _: UITraitCollection) in
            view.layer.borderColor = Theme.Colors.border.cgColor
        }
        hudView = hud

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
        case let .processing(message):
            let activity = UIActivityIndicatorView(style: .medium)
            activity.color = Theme.Colors.text
            activity.startAnimating()
            stackView.addArrangedSubview(activity)
            messageLabel.text = message
            stackView.addArrangedSubview(messageLabel)
        case .downloading:
            let size: CGFloat = 52
            let lineWidth: CGFloat = 4
            let circleView = UIView()
            circleView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                circleView.widthAnchor.constraint(equalToConstant: size),
                circleView.heightAnchor.constraint(equalToConstant: size),
            ])

            let center = CGPoint(x: size / 2, y: size / 2)
            let radius = (size - lineWidth) / 2
            let path = UIBezierPath(
                arcCenter: center, radius: radius,
                startAngle: -.pi / 2, endAngle: 1.5 * .pi,
                clockwise: true
            )

            let trackLayer = CAShapeLayer()
            trackLayer.path = path.cgPath
            trackLayer.strokeColor = UIColor.systemGray4.cgColor
            trackLayer.fillColor = UIColor.clear.cgColor
            trackLayer.lineWidth = lineWidth
            circleView.layer.addSublayer(trackLayer)

            let progressLayer = CAShapeLayer()
            progressLayer.path = path.cgPath
            progressLayer.strokeColor = Theme.Colors.accent.resolvedColor(with: hud.traitCollection).cgColor
            progressLayer.fillColor = UIColor.clear.cgColor
            progressLayer.lineWidth = lineWidth
            progressLayer.lineCap = .round
            progressLayer.strokeEnd = 0
            downloadProgressLayer = progressLayer
            circleView.layer.addSublayer(progressLayer)

            stackView.addArrangedSubview(circleView)

            let percentLabel = UILabel()
            percentLabel.font = Theme.Typography.footnote
            percentLabel.textColor = Theme.Colors.text
            percentLabel.text = "0%"
            downloadProgressLabel = percentLabel
            stackView.addArrangedSubview(percentLabel)
        case let .info(message):
            let icon = UIImageView(image: UIImage(systemName: "info.circle"))
            icon.tintColor = Theme.Colors.text
            icon.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                icon.widthAnchor.constraint(equalToConstant: 28),
                icon.heightAnchor.constraint(equalToConstant: 28),
            ])
            stackView.addArrangedSubview(icon)
            messageLabel.text = message
            stackView.addArrangedSubview(messageLabel)
        case let .error(message):
            let icon = UIImageView(image: UIImage(systemName: "exclamationmark.triangle"))
            icon.tintColor = .systemRed
            icon.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                icon.widthAnchor.constraint(equalToConstant: 28),
                icon.heightAnchor.constraint(equalToConstant: 28),
            ])
            stackView.addArrangedSubview(icon)
            messageLabel.text = message
            stackView.addArrangedSubview(messageLabel)
        }

        NSLayoutConstraint.activate([
            hud.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            hud.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            hud.widthAnchor.constraint(greaterThanOrEqualToConstant: 120),
            hud.widthAnchor.constraint(lessThanOrEqualTo: container.widthAnchor, multiplier: 0.8),

            stackView.topAnchor.constraint(equalTo: hud.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: hud.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: hud.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: hud.bottomAnchor, constant: -20),
        ])

        UIView.animate(withDuration: 0.2) {
            container.alpha = 1
        }

        if case .processing = type { return }
        if case .downloading = type { return }

        showGeneration += 1
        let generation = showGeneration
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard let self, self.showGeneration == generation else { return }
            self.hide()
        }
    }

    private func updateDownloadProgress(_ progress: Double) {
        let animation = CABasicAnimation(keyPath: "strokeEnd")
        animation.fromValue = downloadProgressLayer?.strokeEnd ?? 0
        animation.toValue = CGFloat(progress)
        animation.duration = 0.3
        animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        downloadProgressLayer?.strokeEnd = CGFloat(progress)
        downloadProgressLayer?.add(animation, forKey: "progress")
        downloadProgressLabel?.text = "\(Int(progress * 100))%"
    }

    private func hide() {
        guard let container = containerView else { return }
        // Clear singleton references immediately so a rapid show() call sees
        // a clean state; the local `container` keeps the view alive through
        // the animation via ARC.
        containerView = nil
        hudView = nil
        downloadProgressLayer = nil
        downloadProgressLabel = nil
        container.layer.removeAllAnimations()
        UIView.animate(withDuration: 0.2, animations: {
            container.alpha = 0
        }) { _ in
            container.removeFromSuperview()
        }
    }
}
