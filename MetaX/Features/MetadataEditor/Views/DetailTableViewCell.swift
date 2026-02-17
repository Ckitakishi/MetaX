//
//  DetailTableViewCell.swift
//  MetaX
//
//  Created by Ckitakishi on 2018/4/2.
//  Copyright © 2018 Yuhan Chen. All rights reserved.
//

import UIKit

@MainActor
class DetailTableViewCell: UITableViewCell {

    private let neoContainer = NeoBrutalistContainerView(contentPadding: 12)

    private let propLabel: UILabel = {
        let label = UILabel()
        label.font = Theme.Typography.footnote
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let valueLabel: UILabel = {
        let label = UILabel()
        label.font = Theme.Typography.bodyMedium
        label.textColor = Theme.Colors.text
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    var cellDataSource: DetailCellModel? {
        didSet {
            guard let dataSource = cellDataSource else { return }
            let text = dataSource.prop
            let attributed = NSMutableAttributedString(string: text)
            attributed.addAttribute(.kern, value: 1.0, range: NSRange(location: 0, length: text.count))
            propLabel.attributedText = attributed
            valueLabel.text = dataSource.value
        }
    }

    func applyCardBorders(isFirst: Bool, isLast: Bool) {
        neoContainer.updateBorders(isFirst: isFirst, isLast: isLast)
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        selectionStyle = .none
        backgroundColor = .clear

        neoContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(neoContainer)

        let targetView = neoContainer.contentView
        targetView.addSubview(propLabel)
        targetView.addSubview(valueLabel)

        let padding: CGFloat = 12
        let borderWidth: CGFloat = 1
        let contentInset = borderWidth + padding

        NSLayoutConstraint.activate([
            neoContainer.topAnchor.constraint(equalTo: contentView.topAnchor),
            neoContainer.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor,
                constant: Theme.Layout.standardPadding
            ),
            neoContainer.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor,
                constant: -Theme.Layout.standardPadding
            ),
            neoContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            propLabel.topAnchor.constraint(equalTo: targetView.topAnchor, constant: padding),
            propLabel.leadingAnchor.constraint(equalTo: targetView.leadingAnchor, constant: contentInset),
            propLabel.trailingAnchor.constraint(equalTo: targetView.trailingAnchor, constant: -contentInset),

            valueLabel.topAnchor.constraint(equalTo: propLabel.bottomAnchor, constant: 4),
            valueLabel.leadingAnchor.constraint(equalTo: targetView.leadingAnchor, constant: contentInset),
            valueLabel.trailingAnchor.constraint(equalTo: targetView.trailingAnchor, constant: -contentInset),
            valueLabel.bottomAnchor.constraint(equalTo: targetView.bottomAnchor, constant: -padding),
        ])
    }
}
