//
//  AuthLockView.swift
//  MetaX
//
//  Created by Ckitakishi on 2018/04/19.
//  Copyright © 2018 Yuhan Chen. All rights reserved.
//

import UIKit

@MainActor
protocol AuthLockViewDelegate: AnyObject {
    func toSetting()
}

class AuthLockView: UIView {

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = Theme.Typography.title
        label.textColor = .label
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = Theme.Typography.callout
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private let buttonContainer = UIView()

    private let shadowView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let actionButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 24, bottom: 10, trailing: 24)
        config.baseForegroundColor = .label
        config.background.backgroundColor = Theme.Colors.tagBackground
        config.cornerStyle = .fixed
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attrs in
            var a = attrs
            a.font = Theme.Typography.indexMono
            return a
        }
        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    weak var delegate: AuthLockViewDelegate?

    var title: String = "Denied." {
        didSet { titleLabel.text = title }
    }

    var detail: String = "" {
        didSet { descriptionLabel.text = detail }
    }

    var buttonTitle: String = "Setting" {
        didSet { actionButton.configuration?.title = buttonTitle }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        backgroundColor = Theme.Colors.mainBackground

        let stack = UIStackView(arrangedSubviews: [titleLabel, descriptionLabel, buttonContainer])
        stack.axis = .vertical
        stack.spacing = Theme.Layout.stackSpacing
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stack)
        buttonContainer.addSubview(actionButton)

        shadowView.backgroundColor = Theme.Colors.accent
        buttonContainer.insertSubview(shadowView, belowSubview: actionButton)

        Theme.Shadows.applyCardBorder(to: actionButton.layer)
        Theme.Shadows.applyCardBorder(to: shadowView.layer)

        let offset = Theme.Shadows.layerOffset
        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Theme.Layout.horizontalMargin * 2),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Theme.Layout.horizontalMargin * 2),

            actionButton.topAnchor.constraint(equalTo: buttonContainer.topAnchor),
            actionButton.leadingAnchor.constraint(equalTo: buttonContainer.leadingAnchor),
            actionButton.trailingAnchor.constraint(equalTo: buttonContainer.trailingAnchor, constant: -offset),
            actionButton.bottomAnchor.constraint(equalTo: buttonContainer.bottomAnchor, constant: -offset),

            shadowView.topAnchor.constraint(equalTo: actionButton.topAnchor, constant: offset),
            shadowView.leadingAnchor.constraint(equalTo: actionButton.leadingAnchor, constant: offset),
            shadowView.trailingAnchor.constraint(equalTo: buttonContainer.trailingAnchor),
            shadowView.bottomAnchor.constraint(equalTo: buttonContainer.bottomAnchor),
        ])

        actionButton.addTarget(self, action: #selector(goToAction), for: .touchUpInside)

        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: AuthLockView, _) in
            self.updateBorderColors()
        }
    }

    private func updateBorderColors() {
        Theme.Shadows.updateLayerColors(for: actionButton.layer)
        Theme.Shadows.updateLayerColors(for: shadowView.layer)
    }

    @objc private func goToAction() {
        delegate?.toSetting()
    }
}
