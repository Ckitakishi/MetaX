//
//  MetadataEditViewModel.swift
//  MetaX
//
//  Created by Yuhan Chen on 2026/02/11.
//  Copyright © 2026 Yuhan Chen. All rights reserved.
//

import CoreLocation
import UIKit

enum MetadataField: CaseIterable {
    case make, model, lensMake, lensModel
    case aperture, shutter, iso, focalLength, focalLength35, exposureBias
    case exposureProgram, meteringMode, whiteBalance, flash
    case artist, copyright
    case pixelWidth, pixelHeight, profileName // Read-only
    case dateTimeOriginal, location // Special handling

    var key: String {
        switch self {
        case .make: return MetadataKeys.make
        case .model: return MetadataKeys.model
        case .lensMake: return MetadataKeys.lensMake
        case .lensModel: return MetadataKeys.lensModel
        case .aperture: return MetadataKeys.fNumber
        case .shutter: return MetadataKeys.exposureTime
        case .iso: return MetadataKeys.isoSpeedRatings
        case .focalLength: return MetadataKeys.focalLength
        case .focalLength35: return MetadataKeys.focalLenIn35mmFilm
        case .exposureBias: return MetadataKeys.exposureBiasValue
        case .exposureProgram: return MetadataKeys.exposureProgram
        case .meteringMode: return MetadataKeys.meteringMode
        case .whiteBalance: return MetadataKeys.whiteBalance
        case .flash: return MetadataKeys.flash
        case .artist: return MetadataKeys.artist
        case .copyright: return MetadataKeys.copyright
        case .pixelWidth: return "PixelWidth"
        case .pixelHeight: return "PixelHeight"
        case .profileName: return "ProfileName"
        case .dateTimeOriginal: return MetadataKeys.dateTimeOriginal
        case .location: return MetadataKeys.location
        }
    }

    var label: String {
        switch self {
        case .make: return String(localized: .make)
        case .model: return String(localized: .model)
        case .lensMake: return String(localized: .lensMake)
        case .lensModel: return String(localized: .lensModel)
        case .aperture: return String(localized: .fnumber)
        case .shutter: return String(localized: .exposureTime)
        case .iso: return String(localized: .isospeedRatings)
        case .focalLength: return String(localized: .focalLength)
        case .focalLength35: return String(localized: .focalLenIn35MmFilm)
        case .exposureBias: return String(localized: .exposureBiasValue)
        case .exposureProgram: return String(localized: .exposureProgram)
        case .meteringMode: return String(localized: .meteringMode)
        case .whiteBalance: return String(localized: .whiteBalance)
        case .flash: return String(localized: .flash)
        case .artist: return String(localized: .artist)
        case .copyright: return String(localized: .copyright)
        case .pixelWidth: return String(localized: .pixelWidth)
        case .pixelHeight: return String(localized: .pixelHeight)
        case .profileName: return String(localized: .profileName)
        case .dateTimeOriginal: return String(localized: .viewAddDate)
        case .location: return String(localized: .viewAddLocation)
        }
    }

    var unit: String? {
        switch self {
        case .focalLength, .focalLength35: return "mm"
        case .exposureBias: return "EV"
        case .shutter: return "s"
        case .pixelWidth, .pixelHeight: return "px"
        default: return nil
        }
    }

    var keyboardType: UIKeyboardType {
        switch self {
        case .iso, .focalLength35: return .numberPad
        case .aperture, .focalLength, .exposureBias: return .decimalPad
        case .shutter: return .numbersAndPunctuation
        default: return .default
        }
    }

    var placeholder: String? {
        switch self {
        case .artist: return "Artist name"
        case .copyright: return "Copyright notice"
        case .make, .lensMake: return "SONY"
        case .model: return "ILCE-7C"
        case .lensModel: return "FE 50mm F1.4 GM"
        case .aperture: return "e.g. 2.8"
        case .shutter: return "e.g. 1/125"
        case .iso: return "e.g. 400"
        case .focalLength: return "e.g. 35"
        case .exposureBias: return "e.g. 1.3"
        case .focalLength35: return "e.g. 28"
        default: return nil
        }
    }
}

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

    /// Converts raw UI inputs into a metadata batch dictionary for saving.
    func prepareBatch(from raw: RawFields) -> [String: Any] {
        var batch: [String: Any] = [:]

        batch[MetadataKeys.make] = (raw.make?.isEmpty ?? true) ? NSNull() : raw.make
        batch[MetadataKeys.model] = (raw.model?.isEmpty ?? true) ? NSNull() : raw.model
        batch[MetadataKeys.lensMake] = (raw.lensMake?.isEmpty ?? true) ? NSNull() : raw.lensMake
        batch[MetadataKeys.lensModel] = (raw.lensModel?.isEmpty ?? true) ? NSNull() : raw.lensModel

        // Aperture
        if let val = raw.aperture, let d = Double(val) {
            batch[MetadataKeys.fNumber] = d
        } else {
            batch[MetadataKeys.fNumber] = NSNull()
        }

        // Shutter Speed
        if let val = raw.shutter, !val.isEmpty {
            if val.contains("/") {
                let parts = val.components(separatedBy: "/")
                if parts.count == 2, let n = Double(parts[0]), let d = Double(parts[1]), d != 0 {
                    batch[MetadataKeys.exposureTime] = n / d
                } else {
                    batch[MetadataKeys.exposureTime] = NSNull()
                }
            } else if let d = Double(val) {
                batch[MetadataKeys.exposureTime] = d
            } else {
                batch[MetadataKeys.exposureTime] = NSNull()
            }
        } else {
            batch[MetadataKeys.exposureTime] = NSNull()
        }

        // ISO
        if let val = raw.iso, let i = Int(val) {
            batch[MetadataKeys.isoSpeedRatings] = [i]
        } else {
            batch[MetadataKeys.isoSpeedRatings] = NSNull()
        }

        // Focal Length
        if let val = raw.focalLength, let d = Double(val) {
            batch[MetadataKeys.focalLength] = d
        } else {
            batch[MetadataKeys.focalLength] = NSNull()
        }

        // Exposure Bias
        if let val = raw.exposureBias, !val.isEmpty {
            let cleanVal = val.replacingOccurrences(of: "+", with: "")
            if let d = Double(cleanVal) {
                batch[MetadataKeys.exposureBiasValue] = d
            } else {
                batch[MetadataKeys.exposureBiasValue] = NSNull()
            }
        } else {
            batch[MetadataKeys.exposureBiasValue] = NSNull()
        }

        // Focal Length In 35mm
        if let val = raw.focalLength35, let i = Int(val) {
            batch[MetadataKeys.focalLenIn35mmFilm] = i
        } else {
            batch[MetadataKeys.focalLenIn35mmFilm] = NSNull()
        }

        // Pickers
        batch[MetadataKeys.exposureProgram] = raw.exposureProgram ?? NSNull()
        batch[MetadataKeys.meteringMode] = raw.meteringMode ?? NSNull()
        batch[MetadataKeys.whiteBalance] = raw.whiteBalance ?? NSNull()
        batch[MetadataKeys.flash] = raw.flash ?? NSNull()

        // Date and Location
        batch[MetadataKeys.dateTimeOriginal] = raw.dateTimeOriginal ?? NSNull()
        batch[MetadataKeys.location] = raw.location ?? NSNull()

        // Copyright
        batch[MetadataKeys.artist] = (raw.artist?.isEmpty ?? true) ? NSNull() : raw.artist
        batch[MetadataKeys.copyright] = (raw.copyright?.isEmpty ?? true) ? NSNull() : raw.copyright

        return batch
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
