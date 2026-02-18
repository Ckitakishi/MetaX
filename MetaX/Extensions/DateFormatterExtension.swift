//
//  DateFormatterExtension.swift
//  MetaX
//
//  Created by Ckitakishi on 2018/4/9.
//  Copyright © 2018 Yuhan Chen. All rights reserved.
//

import Foundation

extension DateFormatter {

    enum Format: String {
        case yMd = "yyyy.MM.dd"
        case yMdHms = "yyyy:MM:dd HH:mm:ss"
    }

    static let yMd: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = Format.yMd.rawValue
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        return formatter
    }()

    static let yMdHms: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = Format.yMdHms.rawValue
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        return formatter
    }()

    convenience init(with format: Format) {
        self.init()
        dateFormat = format.rawValue
        locale = Locale(identifier: "en_US_POSIX")
        calendar = Calendar(identifier: .gregorian)
    }
}
