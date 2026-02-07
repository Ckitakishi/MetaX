//
//  DetailSectionHeaderView.swift
//  MetaX
//
//  Created by Ckitakishi on 2018/4/14.
//  Copyright © 2018年 Yuhan Chen. All rights reserved.
//

import UIKit

class DetailSectionHeaderView: UIView {
    
    private let accentBar: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(named: "greenSea") ?? .systemTeal
        view.layer.cornerRadius = 2
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 20, weight: .semibold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    var headerTitle: String = "" {
        didSet {
            titleLabel.text = headerTitle
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = .clear
        addSubview(accentBar)
        addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            accentBar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            accentBar.centerYAnchor.constraint(equalTo: centerYAnchor),
            accentBar.widthAnchor.constraint(equalToConstant: 4),
            accentBar.heightAnchor.constraint(equalTo: heightAnchor, multiplier: 0.5),
            
            titleLabel.leadingAnchor.constraint(equalTo: accentBar.trailingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
}
