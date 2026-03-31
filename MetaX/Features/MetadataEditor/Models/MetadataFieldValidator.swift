
//
//  MetadataFieldValidator.swift
//  MetaX
//
//  Created by Yuhan Chen on 2026/03/27.
//  Copyright © 2026 Yuhan Chen. All rights reserved.
//

import Foundation

/// Shared input validation for metadata fields.
/// Used by both single-photo and batch editing ViewModels.
enum MetadataFieldValidator {

    static func validate(
        currentText: String,
        range: NSRange,
        replacementString string: String,
        for field: MetadataField
    ) -> Bool {
        if string.isEmpty { return true } // Always allow backspace.

        guard let stringRange = Range(range, in: currentText) else { return false }
        let updatedText = currentText.replacingCharacters(in: stringRange, with: string)

        // 1. Character length limits
        let maxLength: Int
        switch field {
        case .iso, .focalLength35, .aperture, .focalLength, .exposureBias: maxLength = 10
        case .shutter: maxLength = 15
        case .artist, .make, .model, .lensMake, .lensModel: maxLength = 64
        case .copyright: maxLength = 200
        default: maxLength = 100
        }
        if updatedText.count > maxLength { return false }

        switch field {
        case .iso, .focalLength35:
            let allowedCharset = CharacterSet.decimalDigits
            return updatedText.rangeOfCharacter(from: allowedCharset.inverted) == nil

        case .aperture, .focalLength:
            let allowedCharset = CharacterSet(charactersIn: "0123456789.")
            if updatedText.rangeOfCharacter(from: allowedCharset.inverted) != nil { return false }
            let dotCount = updatedText.filter { $0 == "." }.count
            return dotCount <= 1

        case .shutter:
            let allowedCharset = CharacterSet(charactersIn: "0123456789./")
            if updatedText.rangeOfCharacter(from: allowedCharset.inverted) != nil { return false }
            let slashCount = updatedText.filter { $0 == "/" }.count
            let dotCount = updatedText.filter { $0 == "." }.count
            return slashCount <= 1 && dotCount <= 1

        case .exposureBias:
            let allowedCharset = CharacterSet(charactersIn: "0123456789.+-")
            if updatedText.rangeOfCharacter(from: allowedCharset.inverted) != nil { return false }

            if updatedText.filter({ $0 == "." }).count > 1 { return false }

            let signs = updatedText.filter { $0 == "+" || $0 == "-" }
            if signs.count > 1 { return false }
            if signs.count == 1 {
                return updatedText.hasPrefix("+") || updatedText.hasPrefix("-")
            }
            return true

        default:
            return true
        }
    }
}

/// Shared conversion helpers for metadata field values.
enum MetadataFieldConverter {

    /// Parses a shutter speed string (e.g. "1/125" or "2.5") into a MetadataFieldValue.
    static func parseShutter(_ val: String) -> MetadataFieldValue {
        if val.contains("/") {
            let parts = val.components(separatedBy: "/")
            if parts.count == 2, let n = Double(parts[0]), let d = Double(parts[1]), d != 0 {
                return .double(n / d)
            }
            return .null
        } else if let d = Double(val) {
            return .double(d)
        }
        return .null
    }
}
