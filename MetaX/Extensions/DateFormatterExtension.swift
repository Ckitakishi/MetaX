//
//  DateFormatterExtension.swift
//  MetaX
//
//  Created by Ckitakishi on 2018/4/9.
//  Copyright © 2018年 Yuhan Chen. All rights reserved.
//

import UIKit

extension DateFormatter {
    
    enum Format: String {
        case yMd = "yyyy.MM.dd"
        case yMdHms = "yyyy:MM:dd HH:mm:ss"
    }
    
    convenience init(with format: Format) {
        self.init()
        self.dateFormat = format.rawValue
    }
    
    func setFormat(_ format: Format) {
        dateFormat = format.rawValue
    }
    
    func getStr(from date:Date) -> String {
        return self.string(from: date)
    }
    
    func getDate(from str:String) -> Date? {
        return date(from: str)
    }
}
