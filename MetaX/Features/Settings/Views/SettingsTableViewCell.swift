//
//  SettingsTableViewCell.swift
//  MetaX
//
//  Created by Yuhan Chen on 2026/02/15.
//

import UIKit

class SettingsTableViewCell: UITableViewCell {

    // MARK: - UI Components

    private let neoContainer = NeoBrutalistContainerView()

    private let iconBgView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 4
        view.layer.borderWidth = 0.5
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let iconImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.preferredSymbolConfiguration = .init(pointSize: 14, weight: .regular)
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = Theme.Typography.bodyMedium
        label.textColor = Theme.Colors.text
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let valueLabel: UILabel = {
        let label = UILabel()
        label.font = Theme.Typography.footnote
        label.textColor = .secondaryLabel
        label.textAlignment = .right
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let chevronImageView: UIImageView = {
        let iv = UIImageView()
        iv.tintColor = .tertiaryLabel
        iv.contentMode = .scaleAspectFit
        iv.preferredSymbolConfiguration = .init(pointSize: 12, weight: .bold)
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    // MARK: - Constraints

    private var valueTrailingConstraint: NSLayoutConstraint?
    private var valueChevronConstraint: NSLayoutConstraint?

    // MARK: - Initialization

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Configuration

    func configure(with item: SettingsItem) {
        titleLabel.text = item.title
        valueLabel.text = item.value
        valueLabel.isHidden = (item.value == nil)

        iconImageView.image = UIImage(systemName: item.icon)
        iconImageView.tintColor = item.iconColor
        iconBgView.backgroundColor = item.iconColor.withAlphaComponent(0.12)
        iconBgView.layer.borderColor = item.iconColor.withAlphaComponent(0.2).cgColor

        if item.type == .version {
            chevronImageView.isHidden = true
            valueChevronConstraint?.isActive = false
            valueTrailingConstraint?.isActive = true
        } else {
            chevronImageView.isHidden = false
            let iconName = item.isExternal ? "arrow.up.forward.app" : "chevron.right"
            chevronImageView.image = UIImage(systemName: iconName)
            valueTrailingConstraint?.isActive = false
            valueChevronConstraint?.isActive = true
        }
    }

    func applyCardBorders(isFirst: Bool, isLast: Bool) {
        neoContainer.updateBorders(isFirst: isFirst, isLast: isLast)
    }

    // MARK: - UI Setup

    private func setupUI() {
        selectionStyle = .none
        backgroundColor = .clear

        neoContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(neoContainer)

        let targetView = neoContainer.contentView
        for item in [iconBgView, titleLabel, valueLabel, chevronImageView] {
            targetView.addSubview(item)
        }
        iconBgView.addSubview(iconImageView)

        let padding: CGFloat = 16

        valueTrailingConstraint = valueLabel.trailingAnchor.constraint(
            equalTo: targetView.trailingAnchor,
            constant: -padding - 1
        )
        valueChevronConstraint = valueLabel.trailingAnchor.constraint(
            equalTo: chevronImageView.leadingAnchor,
            constant: -8
        )

        NSLayoutConstraint.activate([
            neoContainer.topAnchor.constraint(equalTo: contentView.topAnchor),
            neoContainer.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor,
                constant: Theme.Layout.cardPadding
            ),
            neoContainer.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor,
                constant: -Theme.Layout.cardPadding
            ),
            neoContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            iconBgView.leadingAnchor.constraint(equalTo: targetView.leadingAnchor, constant: padding + 1),
            iconBgView.centerYAnchor.constraint(equalTo: targetView.centerYAnchor),
            iconBgView.widthAnchor.constraint(equalToConstant: 32),
            iconBgView.heightAnchor.constraint(equalToConstant: 32),

            iconImageView.centerXAnchor.constraint(equalTo: iconBgView.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconBgView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 18),
            iconImageView.heightAnchor.constraint(equalToConstant: 18),

            titleLabel.leadingAnchor.constraint(equalTo: iconBgView.trailingAnchor, constant: 12),
            titleLabel.centerYAnchor.constraint(equalTo: targetView.centerYAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: valueLabel.leadingAnchor, constant: -12),

            chevronImageView.trailingAnchor.constraint(equalTo: targetView.trailingAnchor, constant: -padding - 1),
            chevronImageView.centerYAnchor.constraint(equalTo: targetView.centerYAnchor),
            chevronImageView.widthAnchor.constraint(equalToConstant: 12),

            valueLabel.centerYAnchor.constraint(equalTo: targetView.centerYAnchor),
            valueLabel.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 12),

            targetView.heightAnchor.constraint(greaterThanOrEqualToConstant: 56),
        ])
    }
}
