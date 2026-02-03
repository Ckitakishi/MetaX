//
//  AuthLockView.swift
//  MetaX
//
//  Created by Ckitakishi on 2018/04/19.
//  Copyright © 2018年 Yuhan Chen. All rights reserved.
//

import UIKit

extension AuthLockView: NibLoadable {}

protocol AuthLockViewDelegate {
    func toSetting()
}

class AuthLockView: UIView {
    
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var descriptionLabel: UILabel!
    @IBOutlet private weak var actionButton: UIButton!
    
    var delegate: AuthLockViewDelegate? = nil
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    var title: String = "Denied." {
        didSet {
            titleLabel.text = title
        }
    }
    
    var detail: String = "" {
        didSet {
            descriptionLabel.text = detail
        }
    }
    
    var buttonTitle: String = "Setting" {
        didSet {
            actionButton.setTitle(buttonTitle, for: .normal)
            actionButton.addBorder(.all, color: UIColor.white, thickness: 2.0)
        }
    }
    
    @IBAction func goToAction(_ sender: UIButton) {
        if delegate != nil {
            delegate?.toSetting()
        }
    }
}
