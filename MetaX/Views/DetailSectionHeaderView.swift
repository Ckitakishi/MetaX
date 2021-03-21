//
//  DetailSectionHeaderView.swift
//  MetaX
//
//  Created by Ckitakishi on 2018/4/14.
//  Copyright © 2018年 Yuhan Chen. All rights reserved.
//

import UIKit
import LoadableNib

extension DetailSectionHeaderView: Loadable {}

class DetailSectionHeaderView: UIView {
    
    @IBOutlet weak var titleLabel: UILabel!
    
    var headetTitle: String = "" {
        didSet {
            
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.firstLineHeadIndent = 16;
            
            let stringAttributes: [NSAttributedString.Key : Any] = [
                .font: UIFont.systemFont(ofSize: 24.0),
                .paragraphStyle: paragraphStyle
            ]

            titleLabel.attributedText = NSAttributedString(string: headetTitle, attributes:stringAttributes)
        }
    }
}
