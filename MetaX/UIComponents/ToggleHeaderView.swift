//
//  ToggleHeaderView.swift
//  MetaX
//
//  Created by Yuhan Chen on 2026/03/31.
//  Copyright © 2026 Yuhan Chen. All rights reserved.
//

import UIKit

/// A reusable header view with a label and optional checkbox toggle.
/// Used by form field components to support batch-edit toggle behavior.
final class ToggleHeaderView: UIView {

    static func make(text: String, onToggle: @escaping (Bool) -> Void) -> ToggleHeaderView {
        let header = ToggleHeaderView(text: text)
        header.onToggle = onToggle
        return header
    }

    var onToggle: ((Bool) -> Void)?

    private(set) var isEnabled = true

    let label: UILabel = {
        let l = UILabel()
        l.font = Theme.Typography.footnote
        l.textColor = .secondaryLabel
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let toggleButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
        config.background.cornerRadius = 0
        config.background.strokeWidth = 1.5
        config.cornerStyle = .fixed
        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    // MARK: - Initialization

    init(text: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        label.text = text

        let stack = UIStackView(arrangedSubviews: [toggleButton, label])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(tapped))
        stack.addGestureRecognizer(tapGesture)

        addSubview(stack)
        NSLayoutConstraint.activate([
            toggleButton.widthAnchor.constraint(equalToConstant: 16),
            toggleButton.heightAnchor.constraint(equalToConstant: 16),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        updateAppearance()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError()
    }

    // MARK: - Public

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        updateAppearance()
    }

    // MARK: - Private

    @objc private func tapped() {
        isEnabled.toggle()
        updateAppearance()
        onToggle?(isEnabled)
    }

    private func updateAppearance() {
        var config = toggleButton.configuration ?? .plain()
        config.baseForegroundColor = isEnabled ? .white : Theme.Colors.border
        config.background.backgroundColor = isEnabled ? Theme.Colors.accent : .clear
        config.background.strokeColor = isEnabled ? Theme.Colors.accent : .secondaryLabel.withAlphaComponent(0.7)
        config.background.strokeWidth = 1.0
        config.background.cornerRadius = 2
        config.image = isEnabled ? UIImage(
            systemName: "checkmark",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 9, weight: .bold)
        ) : nil
        toggleButton.configuration = config
    }
}
