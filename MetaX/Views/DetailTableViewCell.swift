//
//  DetailTableViewCell.swift
//  MetaX
//
//  Created by Ckitakishi on 2018/4/2.
//  Copyright © 2018年 Yuhan Chen. All rights reserved.
//

import UIKit

class DetailTableViewCell: UITableViewCell {
    
    private let propLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let valueLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .label
        label.textAlignment = .right
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    var cellDataSource: DetailCellModel? {
        didSet {
            guard let dataSource = cellDataSource else { return }
            propLabel.text = dataSource.prop
            valueLabel.text = dataSource.value
        }
    }
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        selectionStyle = .none
        contentView.addSubview(propLabel)
        contentView.addSubview(valueLabel)
        
        NSLayoutConstraint.activate([
            propLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            propLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            propLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -12),

            valueLabel.leadingAnchor.constraint(equalTo: propLabel.trailingAnchor, constant: 12),
            valueLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            valueLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            valueLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
    }
}
