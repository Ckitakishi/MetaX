//
//  MetadataEditViewModel.swift
//  MetaX
//
//  Created by Yuhan Chen on 2026/02/11.
//  Copyright © 2026 Yuhan Chen. All rights reserved.
//

import CoreLocation
import UIKit

struct MetadataEditViewModel {

    struct RawFields: Equatable {
        var make: String?
        var model: String?
        var lensMake: String?
        var lensModel: String?
        var aperture: String?
        var shutter: String?
        var iso: String?
        var focalLength: String?
        var exposureBias: String?
        var focalLength35: String?
        var exposureProgram: Int?
        var meteringMode: Int?
        var whiteBalance: Int?
        var flash: Int?
        var dateTimeOriginal: Date?
        var location: CLLocation?
        var artist: String?
        var copyright: String?

        static func == (lhs: RawFields, rhs: RawFields) -> Bool {
            return lhs.make == rhs.make &&
                lhs.model == rhs.model &&
                lhs.lensMake == rhs.lensMake &&
                lhs.lensModel == rhs.lensModel &&
                lhs.aperture == rhs.aperture &&
                lhs.shutter == rhs.shutter &&
                lhs.iso == rhs.iso &&
                lhs.focalLength == rhs.focalLength &&
                lhs.exposureBias == rhs.exposureBias &&
                lhs.focalLength35 == rhs.focalLength35 &&
                lhs.exposureProgram == rhs.exposureProgram &&
                lhs.meteringMode == rhs.meteringMode &&
                lhs.whiteBalance == rhs.whiteBalance &&
                lhs.flash == rhs.flash &&
                lhs.dateTimeOriginal == rhs.dateTimeOriginal &&
                lhs.artist == rhs.artist &&
                lhs.copyright == rhs.copyright &&
                isLocationEqual(lhs.location, rhs.location)
        }

        private static func isLocationEqual(_ l1: CLLocation?, _ l2: CLLocation?) -> Bool {
            if l1 == nil && l2 == nil { return true }
            guard let l1 = l1, let l2 = l2 else { return false }
            return l1.coordinate.latitude == l2.coordinate.latitude &&
                l1.coordinate.longitude == l2.coordinate.longitude &&
                l1.altitude == l2.altitude
        }
    }

    /// Converts raw UI inputs into a metadata fields dictionary.
    func prepareFields(from raw: RawFields) -> [MetadataField: Any] {
        var fields: [MetadataField: Any] = [:]

        fields[.make] = (raw.make?.isEmpty ?? true) ? NSNull() : raw.make
        fields[.model] = (raw.model?.isEmpty ?? true) ? NSNull() : raw.model
        fields[.lensMake] = (raw.lensMake?.isEmpty ?? true) ? NSNull() : raw.lensMake
        fields[.lensModel] = (raw.lensModel?.isEmpty ?? true) ? NSNull() : raw.lensModel

        // Aperture
        if let val = raw.aperture, let d = Double(val) {
            fields[.aperture] = d
        } else {
            fields[.aperture] = NSNull()
        }

        // Shutter Speed
        if let val = raw.shutter, !val.isEmpty {
            if val.contains("/") {
                let parts = val.components(separatedBy: "/")
                if parts.count == 2, let n = Double(parts[0]), let d = Double(parts[1]), d != 0 {
                    fields[.shutter] = n / d
                } else {
                    fields[.shutter] = NSNull()
                }
            } else if let d = Double(val) {
                fields[.shutter] = d
            } else {
                fields[.shutter] = NSNull()
            }
        } else {
            fields[.shutter] = NSNull()
        }

        // ISO
        if let val = raw.iso, let i = Int(val) {
            fields[.iso] = [i]
        } else {
            fields[.iso] = NSNull()
        }

        // Focal Length
        if let val = raw.focalLength, let d = Double(val) {
            fields[.focalLength] = d
        } else {
            fields[.focalLength] = NSNull()
        }

        // Exposure Bias
        if let val = raw.exposureBias, !val.isEmpty {
            let cleanVal = val.replacingOccurrences(of: "+", with: "")
            if let d = Double(cleanVal) {
                fields[.exposureBias] = d
            } else {
                fields[.exposureBias] = NSNull()
            }
        } else {
            fields[.exposureBias] = NSNull()
        }

        // Focal Length In 35mm
        if let val = raw.focalLength35, let i = Int(val) {
            fields[.focalLength35] = i
        } else {
            fields[.focalLength35] = NSNull()
        }

        // Pickers
        fields[.exposureProgram] = raw.exposureProgram ?? NSNull()
        fields[.meteringMode] = raw.meteringMode ?? NSNull()
        fields[.whiteBalance] = raw.whiteBalance ?? NSNull()
        fields[.flash] = raw.flash ?? NSNull()

        // Date and Location
        fields[.dateTimeOriginal] = raw.dateTimeOriginal ?? NSNull()
        fields[.location] = raw.location ?? NSNull()

        // Copyright
        fields[.artist] = (raw.artist?.isEmpty ?? true) ? NSNull() : raw.artist
        fields[.copyright] = (raw.copyright?.isEmpty ?? true) ? NSNull() : raw.copyright

        return fields
    }

    /// Pure logic to validate if a string change should be allowed for a specific field.
    func validateInput(
        currentText: String,
        range: NSRange,
        replacementString string: String,
        for field: MetadataField
    ) -> Bool {
        if string.isEmpty { return true } // Always allow backspace

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
            // Positive Integers
            let allowedCharset = CharacterSet.decimalDigits
            return updatedText.rangeOfCharacter(from: allowedCharset.inverted) == nil

        case .aperture, .focalLength:
            // Positive Decimals
            let allowedCharset = CharacterSet(charactersIn: "0123456789.")
            if updatedText.rangeOfCharacter(from: allowedCharset.inverted) != nil { return false }
            let dotCount = updatedText.filter { $0 == "." }.count
            return dotCount <= 1

        case .shutter:
            // Fractions or Decimals
            let allowedCharset = CharacterSet(charactersIn: "0123456789./")
            if updatedText.rangeOfCharacter(from: allowedCharset.inverted) != nil { return false }
            let slashCount = updatedText.filter { $0 == "/" }.count
            let dotCount = updatedText.filter { $0 == "." }.count
            return slashCount <= 1 && dotCount <= 1

        case .exposureBias:
            // Signed Decimals
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
