//
//  DetailTableViewCell.swift
//  MetaX
//
//  Created by Ckitakishi on 2018/4/2.
//  Copyright © 2018年 Yuhan Chen. All rights reserved.
//

import UIKit

class DetailTableViewCell: UITableViewCell {
    
    @IBOutlet private weak var propLabel: UILabel!
    @IBOutlet private weak var valueLabel: UILabel!
    
    var cellDataSource: DetailCellModel? {
        didSet {
            
            guard let dataSource = cellDataSource else { return }
            
            propLabel.text = dataSource.prop
            valueLabel.text = dataSource.value
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
    }
}
