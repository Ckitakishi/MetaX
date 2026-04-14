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
final class ToggleHeaderView: UIControl {

    static func make(text: String, onToggle: @escaping (Bool) -> Void) -> ToggleHeaderView {
        let header = ToggleHeaderView(text: text)
        header.onToggle = onToggle
        return header
    }

    var onToggle: ((Bool) -> Void)?

    private(set) var isChecked = true

    private let toggleSize: CGFloat = 20
    private let verticalHitOutset: CGFloat = 12

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

        addSubview(stack)
        NSLayoutConstraint.activate([
            toggleButton.widthAnchor.constraint(equalToConstant: toggleSize),
            toggleButton.heightAnchor.constraint(equalToConstant: toggleSize),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        toggleButton.addTarget(self, action: #selector(tapped), for: .touchUpInside)
        updateAppearance()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError()
    }

    // MARK: - Public

    func setEnabled(_ enabled: Bool) {
        isChecked = enabled
        updateAppearance()
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let expandedBounds = bounds.insetBy(dx: 0, dy: -verticalHitOutset)
        return expandedBounds.contains(point)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else {
            super.touchesEnded(touches, with: event)
            return
        }
        if touch.view === toggleButton {
            super.touchesEnded(touches, with: event)
            return
        }
        let touchPoint = touch.location(in: self)
        guard point(inside: touchPoint, with: event) else {
            super.touchesEnded(touches, with: event)
            return
        }
        tapped()
    }

    // MARK: - Private

    @objc private func tapped() {
        isChecked.toggle()
        updateAppearance()
        onToggle?(isChecked)
    }

    private func updateAppearance() {
        var config = toggleButton.configuration ?? .plain()
        config.baseForegroundColor = isChecked ? .white : Theme.Colors.border
        config.background.backgroundColor = isChecked ? Theme.Colors.accent : .clear
        config.background.strokeColor = isChecked ? Theme.Colors.accent : .secondaryLabel.withAlphaComponent(0.7)
        config.background.strokeWidth = 1.0
        config.background.cornerRadius = 2
        config.image = isChecked ? UIImage(
            systemName: "checkmark",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .bold)
        ) : nil
        toggleButton.configuration = config
        accessibilityTraits = isChecked ? [.button, .selected] : .button
    }
}
