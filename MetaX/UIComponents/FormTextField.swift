//
//  FormTextField.swift
//  MetaX
//
//  Created by Yuhan Chen on 2026/02/09.
//  Copyright © 2026 Yuhan Chen. All rights reserved.
//

import UIKit

/// A custom form field that displays a title, a text field, and an optional character counter.
final class FormTextField: UIView {

    // MARK: - Properties

    let label: UILabel = {
        let l = UILabel()
        l.font = Theme.Typography.footnote
        l.textColor = .secondaryLabel
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    let textField: UITextField = {
        let tf = UITextField()
        tf.backgroundColor = Theme.Colors.tagBackground
        tf.layer.borderWidth = 1.0
        tf.layer.borderColor = Theme.Colors.border.cgColor
        tf.layer.cornerRadius = 0
        tf.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 0))
        tf.leftViewMode = .always
        tf.font = Theme.Typography.bodyMedium
        tf.translatesAutoresizingMaskIntoConstraints = false
        tf.autocorrectionType = .no
        return tf
    }()

    private let unitLabel: UILabel = {
        let l = UILabel()
        l.font = Theme.Typography.footnote
        l.textColor = .tertiaryLabel
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let maxLength: Int?

    private lazy var counterLabel: UILabel = {
        let l = UILabel()
        l.font = Theme.Typography.captionMono.withSize(10)
        l.textColor = .tertiaryLabel
        l.textAlignment = .right
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // MARK: - Initialization

    init(
        label labelText: String,
        placeholder: String? = nil,
        keyboardType: UIKeyboardType = .default,
        readOnly: Bool = false,
        maxLength: Int? = nil,
        unit: String? = nil
    ) {
        self.maxLength = maxLength
        super.init(frame: .zero)

        label.text = labelText
        textField.placeholder = placeholder
        textField.keyboardType = keyboardType

        setupLayout(readOnly: readOnly, unit: unit)

        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: FormTextField, _) in
            self.textField.layer.borderColor = Theme.Colors.border.cgColor
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError()
    }

    // MARK: - Private Methods

    private func setupLayout(readOnly: Bool, unit: String?) {
        if let unit {
            unitLabel.text = unit
            let container = UIView()
            container.addSubview(unitLabel)
            NSLayoutConstraint.activate([
                unitLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                unitLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
                unitLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            ])
            textField.rightView = container
            textField.rightViewMode = .always
        }

        if readOnly {
            textField.isUserInteractionEnabled = false
            textField.alpha = 0.45
        }

        addSubview(label)
        addSubview(textField)

        var constraints: [NSLayoutConstraint] = [
            label.topAnchor.constraint(equalTo: topAnchor),
            label.leadingAnchor.constraint(equalTo: leadingAnchor),

            textField.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 6),
            textField.leadingAnchor.constraint(equalTo: leadingAnchor),
            textField.trailingAnchor.constraint(equalTo: trailingAnchor),
            textField.bottomAnchor.constraint(equalTo: bottomAnchor),
            textField.heightAnchor.constraint(equalToConstant: 50),
        ]

        if let max = maxLength {
            counterLabel.text = "0/\(max)"
            addSubview(counterLabel)
            constraints += [
                counterLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
                counterLabel.firstBaselineAnchor.constraint(equalTo: label.firstBaselineAnchor),
                label.trailingAnchor.constraint(lessThanOrEqualTo: counterLabel.leadingAnchor, constant: -8),
            ]
            textField.addTarget(self, action: #selector(updateCounter), for: .editingChanged)
        } else {
            constraints.append(label.trailingAnchor.constraint(equalTo: trailingAnchor))
        }

        NSLayoutConstraint.activate(constraints)
    }

    @objc private func updateCounter() {
        guard let max = maxLength else { return }
        let count = textField.text?.count ?? 0
        counterLabel.text = "\(count)/\(max)"
        counterLabel.textColor = count >= max - 20 ? .secondaryLabel : .tertiaryLabel
    }
}
