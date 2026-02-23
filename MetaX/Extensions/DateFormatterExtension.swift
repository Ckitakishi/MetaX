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

    /// Thread-safe formatters for the app.
    static var yMd: DateFormatter { cached(format: .yMd) }
    static var yMdHms: DateFormatter { cached(format: .yMdHms) }

    /// Returns a thread-safe, cached DateFormatter for the specified format.
    private static func cached(format: Format) -> DateFormatter {
        let key = "com.metax.dateformatter.\(format.rawValue)"
        if let formatter = Thread.current.threadDictionary[key] as? DateFormatter {
            return formatter
        }

        let formatter = DateFormatter()
        formatter.dateFormat = format.rawValue
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        Thread.current.threadDictionary[key] = formatter
        return formatter
    }

    convenience init(with format: Format) {
        self.init()
        dateFormat = format.rawValue
        locale = Locale(identifier: "en_US_POSIX")
        calendar = Calendar(identifier: .gregorian)
    }
}
