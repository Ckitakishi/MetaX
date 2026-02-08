//
//  DetailDataPickerPopover.swift
//  MetaX
//
//  Created by Ckitakishi on 2018/4/6.
//  Copyright © 2018 Yuhan Chen. All rights reserved.
//

import UIKit

class DetailDatePickerPopover: UIViewController  {
    
    private let datePicker: UIDatePicker = {
        let picker = UIDatePicker()
        picker.datePickerMode = .date // Only date, not time
        picker.preferredDatePickerStyle = .wheels // Classic wheels for popover
        picker.translatesAutoresizingMaskIntoConstraints = false
        return picker
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        datePicker.maximumDate = Date()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        view.addSubview(datePicker)
        
        NSLayoutConstraint.activate([
            datePicker.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            datePicker.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            datePicker.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            datePicker.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8)
        ])
        
        // Set preferred content size for popover
        preferredContentSize = CGSize(width: 320, height: 220)
    }
    
    var curDate: Date {
        return datePicker.date
    }
}

