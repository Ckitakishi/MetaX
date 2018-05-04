//
//  LocationTableViewCell.swift
//  MetaX
//
//  Created by Ckitakishi on 2018/04/11.
//  Copyright © 2018年 Yuhan Chen. All rights reserved.
//

import UIKit
import MapKit

class LocationTableViewCell: UITableViewCell {
    
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var subTitleLabel: UILabel!
    
    var cellDataSource: MKLocalSearchCompletion! {
        didSet {
            titleLabel.text = cellDataSource.title
            subTitleLabel.text = cellDataSource.subtitle
        }
    }
}
