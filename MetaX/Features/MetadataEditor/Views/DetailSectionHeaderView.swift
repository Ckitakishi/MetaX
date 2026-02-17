//
//  DetailSectionHeaderView.swift
//  MetaX
//
//  Created by Ckitakishi on 2018/4/14.
//  Copyright © 2018 Yuhan Chen. All rights reserved.
//

import UIKit

@MainActor
class DetailSectionHeaderView: UIView {

    private let indicatorBlock: UIView = {
        let view = UIView()
        view.backgroundColor = Theme.Colors.accent
        view.layer.cornerRadius = 0
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = Theme.Typography.subheadline
        label.textColor = Theme.Colors.text
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    var headerTitle: String = "" {
        didSet {
            let text = headerTitle.uppercased()
            let attributedString = NSMutableAttributedString(string: text)
            attributedString.addAttribute(.kern, value: 2.0, range: NSRange(location: 0, length: text.count))
            titleLabel.attributedText = attributedString
        }
    }

    var indicatorColor: UIColor = Theme.Colors.accent {
        didSet {
            indicatorBlock.backgroundColor = indicatorColor
        }
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
        backgroundColor = .clear
        addSubview(indicatorBlock)
        addSubview(titleLabel)

        NSLayoutConstraint.activate([
            indicatorBlock.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Theme.Layout.standardPadding),
            indicatorBlock.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20),
            indicatorBlock.widthAnchor.constraint(equalToConstant: 8),
            indicatorBlock.heightAnchor.constraint(equalToConstant: 8),

            titleLabel.leadingAnchor.constraint(equalTo: indicatorBlock.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Theme.Layout.standardPadding),
            titleLabel.centerYAnchor.constraint(equalTo: indicatorBlock.centerYAnchor),
        ])
    }
}
