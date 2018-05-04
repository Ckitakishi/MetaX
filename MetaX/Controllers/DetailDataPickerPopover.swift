//
//  DetailDataPickerPopover.swift
//  MetaX
//
//  Created by Ckitakishi on 2018/4/6.
//  Copyright © 2018年 Yuhan Chen. All rights reserved.
//

import UIKit

class DetailDatePickerPopover: UIViewController  {
    
    @IBOutlet weak var datePicker: UIDatePicker!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        datePicker.maximumDate = Date()
    }
    
    var curDate: Date {
        get {
            return datePicker.date
        }
    }
}

