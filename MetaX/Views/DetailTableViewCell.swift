//
//  DetailTableViewCell.swift
//  MetaX
//
//  Created by Ckitakishi on 2018/4/2.
//  Copyright © 2018 Yuhan Chen. All rights reserved.
//

import UIKit

class DetailTableViewCell: UITableViewCell {

    // Card borders — shown/hidden based on row position within section
    private let topBorder = DetailTableViewCell.makeBorderView()
    private let bottomBorder = DetailTableViewCell.makeBorderView()
    private let leftBorder = DetailTableViewCell.makeBorderView()
    private let rightBorder = DetailTableViewCell.makeBorderView()

    private let rowSeparator: UIView = {
        let v = UIView()
        v.backgroundColor = Theme.Colors.border.withAlphaComponent(0.4)
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let container: UIView = {
        let v = UIView()
        v.backgroundColor = Theme.Colors.cardBackground
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let propLabel: UILabel = {
        let label = UILabel()
        label.font = .monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let valueLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 17, weight: .semibold)
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

    /// Call from `willDisplay` to stitch borders across section rows.
    func applyCardBorders(isFirst: Bool, isLast: Bool) {
        topBorder.isHidden = !isFirst
        bottomBorder.isHidden = !isLast
        rowSeparator.isHidden = isLast
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private static func makeBorderView() -> UIView {
        let v = UIView()
        v.backgroundColor = Theme.Colors.border
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }

    private func setupUI() {
        selectionStyle = .none
        backgroundColor = .clear

        contentView.addSubview(container)
        container.addSubview(leftBorder)
        container.addSubview(rightBorder)
        container.addSubview(topBorder)
        container.addSubview(bottomBorder)
        container.addSubview(rowSeparator)
        container.addSubview(propLabel)
        container.addSubview(valueLabel)

        let borderWidth: CGFloat = 1
        let padding: CGFloat = 12
        let contentInset = borderWidth + padding

        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: contentView.topAnchor),
            container.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Theme.Layout.cardPadding),
            container.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Theme.Layout.cardPadding),
            container.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            leftBorder.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            leftBorder.topAnchor.constraint(equalTo: container.topAnchor),
            leftBorder.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            leftBorder.widthAnchor.constraint(equalToConstant: borderWidth),

            rightBorder.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            rightBorder.topAnchor.constraint(equalTo: container.topAnchor),
            rightBorder.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            rightBorder.widthAnchor.constraint(equalToConstant: borderWidth),

            topBorder.topAnchor.constraint(equalTo: container.topAnchor),
            topBorder.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            topBorder.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            topBorder.heightAnchor.constraint(equalToConstant: borderWidth),

            bottomBorder.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            bottomBorder.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            bottomBorder.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            bottomBorder.heightAnchor.constraint(equalToConstant: borderWidth),

            rowSeparator.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            rowSeparator.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: contentInset),
            rowSeparator.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -contentInset),
            rowSeparator.heightAnchor.constraint(equalToConstant: 0.5),

            propLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: padding),
            propLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: contentInset),
            propLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -contentInset),

            valueLabel.topAnchor.constraint(equalTo: propLabel.bottomAnchor, constant: 4),
            valueLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: contentInset),
            valueLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -contentInset),
            valueLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -padding)
        ])
    }
}
