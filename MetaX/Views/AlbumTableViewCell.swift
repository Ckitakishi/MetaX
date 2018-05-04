//
//  AlbumTableViewCell.swift
//  MetaX
//
//  Created by Ckitakishi on 2018/3/15.
//  Copyright © 2018年 Yuhan Chen. All rights reserved.
//

import UIKit

class AlbumTableViewCell: UITableViewCell {
    
    @IBOutlet private weak var thumnailImageView: UIImageView!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var countLabel: UILabel!
    
    var title: String? = "" {
        didSet {
            titleLabel.text = title
        }
    }
    
    var count: Int = 0 {
        didSet {
            countLabel.text = String(count)
        }
    }
    
    var thumnail: UIImage! {
        didSet {
            thumnailImageView.image = thumnail
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        
    }
}
