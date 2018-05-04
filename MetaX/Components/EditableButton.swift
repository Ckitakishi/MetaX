//
//  EditableButton.swift
//  MetaX
//
//  Created by Ckitakishi on 2018/04/05.
//  Copyright © 2018年 Yuhan Chen. All rights reserved.
//

import UIKit

@IBDesignable class EditableButton: UIButton {
    
    public var isEmpty: Bool = false {
        didSet {
            self.isEnabled = isEmpty
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        instantiate()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        instantiate()
    }
    
    func instantiate() {
        titleLabel?.adjustsFontSizeToFitWidth = true
        titleLabel?.numberOfLines = 2
        titleLabel?.lineBreakMode = .byWordWrapping
        titleLabel?.minimumScaleFactor = 0.8
    }
    
    var titleText: String = "" {
        didSet {
            setTitle(titleText, for: .normal)
        }
    }
    
    @IBInspectable var borderColor: UIColor = UIColor.white {
        didSet {
            layer.borderWidth = 1
            layer.borderColor = borderColor.cgColor
        }
    }
    
    @IBInspectable var borderWidth: CGFloat = 1.0 {
        didSet {
            layer.borderWidth = borderWidth
        }
    }
    
    @IBInspectable var cornerRadius: CGFloat = 0.0 {
        didSet {
            layer.cornerRadius = cornerRadius
        }
    }
}
