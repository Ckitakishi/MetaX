//
//  DetailSectionHeaderView.swift
//  MetaX
//
//  Created by Ckitakishi on 2018/4/14.
//  Copyright © 2018年 Yuhan Chen. All rights reserved.
//

import UIKit

extension DetailSectionHeaderView: NibLoadable {}

class DetailSectionHeaderView: UIView {
    
    @IBOutlet weak var titleLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        titleLabel.addBorder(.left, color: .greenSea, thickness: 6.0)
    }
    
    var headetTitle: String = "" {
        didSet {
            
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.firstLineHeadIndent = 16;
            
            let stringAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24.0),
                .paragraphStyle: paragraphStyle
            ]

            titleLabel.attributedText = NSAttributedString(string: headetTitle, attributes:stringAttributes)
        }
    }
}
