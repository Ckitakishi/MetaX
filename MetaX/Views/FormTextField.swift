//
//  FormTextField.swift
//  MetaX
//
//  Created by Yuhan Chen on 2026/02/09.
//  Copyright © 2026 Yuhan Chen. All rights reserved.
//

import UIKit

final class FormTextField: UIView {
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

    private let maxLength: Int?

    private lazy var counterLabel: UILabel = {
        let l = UILabel()
        l.font = Theme.Typography.captionMono.withSize(10)
        l.textColor = .tertiaryLabel
        l.textAlignment = .right
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    init(label: String, placeholder: String? = nil, keyboardType: UIKeyboardType = .default, readOnly: Bool = false, maxLength: Int? = nil) {
        self.maxLength = maxLength
        super.init(frame: .zero)
        self.label.text = label
        self.textField.placeholder = placeholder
        self.textField.keyboardType = keyboardType

        if readOnly {
            textField.isUserInteractionEnabled = false
            textField.alpha = 0.45
        }

        addSubview(self.label)
        addSubview(textField)

        var constraints: [NSLayoutConstraint] = [
            self.label.topAnchor.constraint(equalTo: topAnchor),
            self.label.leadingAnchor.constraint(equalTo: leadingAnchor),

            textField.topAnchor.constraint(equalTo: self.label.bottomAnchor, constant: 6),
            textField.leadingAnchor.constraint(equalTo: leadingAnchor),
            textField.trailingAnchor.constraint(equalTo: trailingAnchor),
            textField.bottomAnchor.constraint(equalTo: bottomAnchor),
            textField.heightAnchor.constraint(equalToConstant: 50)
        ]

        if let max = maxLength {
            counterLabel.text = "0/\(max)"
            addSubview(counterLabel)
            constraints += [
                counterLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
                counterLabel.firstBaselineAnchor.constraint(equalTo: self.label.firstBaselineAnchor),
                self.label.trailingAnchor.constraint(lessThanOrEqualTo: counterLabel.leadingAnchor, constant: -8)
            ]
            textField.addTarget(self, action: #selector(updateCounter), for: .editingChanged)
        } else {
            constraints.append(self.label.trailingAnchor.constraint(equalTo: trailingAnchor))
        }

        NSLayoutConstraint.activate(constraints)

        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: FormTextField, _: UITraitCollection) in
            self.textField.layer.borderColor = Theme.Colors.border.cgColor
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc private func updateCounter() {
        guard let max = maxLength else { return }
        let count = textField.text?.count ?? 0
        counterLabel.text = "\(count)/\(max)"
        counterLabel.textColor = count >= max - 20 ? .secondaryLabel : .tertiaryLabel
    }
}