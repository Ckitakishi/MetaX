//
//  AuthLockView.swift
//  MetaX
//
//  Created by Ckitakishi on 2018/04/19.
//  Copyright © 2018年 Yuhan Chen. All rights reserved.
//

import UIKit

protocol AuthLockViewDelegate: AnyObject {
    func toSetting()
}

class AuthLockView: UIView {
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 24, weight: .bold)
        label.textColor = .label
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()
    
    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()
    
    private let actionButton: UIButton = {
        var config = UIButton.Configuration.borderedProminent()
        config.cornerStyle = .capsule
        config.baseBackgroundColor = UIColor(named: "greenSea") ?? .systemTeal
        let button = UIButton(configuration: config)
        return button
    }()
    
    weak var delegate: AuthLockViewDelegate? = nil
    
    var title: String = "Denied." {
        didSet { titleLabel.text = title }
    }

    var detail: String = "" {
        didSet { descriptionLabel.text = detail }
    }

    var buttonTitle: String = "Setting" {
        didSet { actionButton.setTitle(buttonTitle, for: .normal) }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = .systemBackground
        
        let stack = UIStackView(arrangedSubviews: [titleLabel, descriptionLabel, actionButton])
        stack.axis = .vertical
        stack.spacing = 20
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 40),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -40),
            
            actionButton.heightAnchor.constraint(equalToConstant: 50),
            actionButton.widthAnchor.constraint(equalToConstant: 200)
        ])
        
        actionButton.addTarget(self, action: #selector(goToAction), for: .touchUpInside)
    }
    
    @objc private func goToAction() {
        delegate?.toSetting()
    }
}
