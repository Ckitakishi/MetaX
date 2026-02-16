//
//  SaveOptionsViewController.swift
//  MetaX
//
//  Created by Yuhan Chen on 2026/02/12.
//  Copyright © 2026 Yuhan Chen. All rights reserved.
//

import UIKit

final class SaveOptionsViewController: UIViewController {
    var onSelect: ((SaveWorkflowMode) -> Void)?
    var onCancel: (() -> Void)?
    private var didSelectOption = false

    private let containerStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
        view.backgroundColor = Theme.Colors.sheetBackground
        view.addSubview(containerStack)

        setupInitialCards()

        NSLayoutConstraint.activate([
            // 48pt clears the grabber handle area
            containerStack.topAnchor.constraint(equalTo: view.topAnchor, constant: 48),
            containerStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            containerStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            containerStack.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -20),
        ])

        if let sheet = sheetPresentationController {
            sheet.detents = [
                .custom { [weak self] _ in
                    guard let self else { return 256 }
                    self.view.layoutIfNeeded()
                    let contentHeight = self.containerStack.systemLayoutSizeFitting(
                        CGSize(width: self.view.bounds.width - 32, height: UIView.layoutFittingCompressedSize.height),
                        withHorizontalFittingPriority: .required,
                        verticalFittingPriority: .fittingSizeLevel
                    ).height
                    return contentHeight + 48 + 20 // top padding + bottom padding
                },
            ]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 20
        }
    }

    private func setupInitialCards() {
        containerStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let modifyCard = OptionCardView(
            title: String(localized: .saveModifyOriginal),
            description: String(localized: .saveModifyOriginalDesc),
            icon: "pencil"
        )
        let saveNewCard = OptionCardView(
            title: String(localized: .saveAsCopy),
            description: String(localized: .saveAsCopyDesc),
            icon: "photo.badge.plus"
        )

        containerStack.addArrangedSubview(modifyCard)
        containerStack.addArrangedSubview(saveNewCard)

        modifyCard.onTap = { [weak self] in
            self?.didSelectOption = true
            self?.dismiss(animated: true) {
                self?.onSelect?(.updateOriginal)
            }
        }
        saveNewCard.onTap = { [weak self] in
            self?.showDeletionInquiry()
        }
    }

    private func showDeletionInquiry() {
        UIView.transition(with: containerStack, duration: 0.2, options: .transitionCrossDissolve) {
            self.containerStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
            self.sheetPresentationController?.invalidateDetents()

            let keepCard = OptionCardView(
                title: String(localized: .saveKeepOriginal),
                description: String(localized: .saveKeepOriginalDesc),
                icon: "doc.on.doc"
            )
            let deleteCard = OptionCardView(
                title: String(localized: .saveDeleteOriginal),
                description: String(localized: .saveDeleteOriginalDesc),
                icon: "trash",
                iconTint: .systemRed
            )

            self.containerStack.addArrangedSubview(keepCard)
            self.containerStack.addArrangedSubview(deleteCard)

            keepCard.onTap = { [weak self] in
                self?.didSelectOption = true
                self?.dismiss(animated: true) {
                    self?.onSelect?(.saveAsCopy(deleteOriginal: false))
                }
            }
            deleteCard.onTap = { [weak self] in
                self?.didSelectOption = true
                self?.dismiss(animated: true) {
                    self?.onSelect?(.saveAsCopy(deleteOriginal: true))
                }
            }
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if !didSelectOption {
            onCancel?()
        }
    }
}

// MARK: - Option Card View

private final class OptionCardView: UIView {
    var onTap: (() -> Void)?

    private let iconBgView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 20
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let iconImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.font = Theme.Typography.headline
        l.textColor = Theme.Colors.text
        return l
    }()

    private let descLabel: UILabel = {
        let l = UILabel()
        l.font = Theme.Typography.hint
        l.textColor = .secondaryLabel
        l.numberOfLines = 0
        return l
    }()

    init(title: String, description: String, icon: String, iconTint: UIColor = Theme.Colors.accent) {
        super.init(frame: .zero)

        backgroundColor = Theme.Colors.sheetBackground
        layer.cornerRadius = Theme.Layout.cardCornerRadius
        Theme.Shadows.applyCardBorder(to: layer)

        titleLabel.text = title
        descLabel.text = description
        iconImageView.image = UIImage(systemName: icon)
        iconImageView.tintColor = iconTint
        iconBgView.backgroundColor = iconTint.withAlphaComponent(0.12)

        let textStack = UIStackView(arrangedSubviews: [titleLabel, descLabel])
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(iconBgView)
        iconBgView.addSubview(iconImageView)
        addSubview(textStack)

        NSLayoutConstraint.activate([
            iconBgView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            iconBgView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconBgView.widthAnchor.constraint(equalToConstant: 40),
            iconBgView.heightAnchor.constraint(equalToConstant: 40),

            iconImageView.centerXAnchor.constraint(equalTo: iconBgView.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconBgView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 22),
            iconImageView.heightAnchor.constraint(equalToConstant: 22),

            textStack.leadingAnchor.constraint(equalTo: iconBgView.trailingAnchor, constant: 14),
            textStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            textStack.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            textStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14),
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)

        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: OptionCardView, _: UITraitCollection) in
            Theme.Shadows.updateLayerColors(for: self.layer)
            self.iconBgView.layer.borderColor = Theme.Colors.border.cgColor
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError()
    }

    @objc private func handleTap() {
        UIView.animate(withDuration: Theme.Animation.pressEffect, animations: {
            self.transform = CGAffineTransform(
                translationX: Theme.Shadows.pressedTranslation,
                y: Theme.Shadows.pressedTranslation
            )
        }) { _ in
            UIView.animate(withDuration: Theme.Animation.pressEffect) {
                self.transform = .identity
            }
            self.onTap?()
        }
    }
}
