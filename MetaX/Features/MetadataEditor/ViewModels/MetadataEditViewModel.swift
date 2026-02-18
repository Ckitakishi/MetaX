//
//  MetadataEditViewModel.swift
//  MetaX
//
//  Created by Yuhan Chen on 2026/02/11.
//  Copyright © 2026 Yuhan Chen. All rights reserved.
//

import CoreLocation
import Observation
import UIKit

@Observable @MainActor
final class MetadataEditViewModel {

    /// A consolidated structure representing all editable fields.
    struct Fields: Equatable {
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
        var dateTimeOriginal: Date = .init()
        var location: CLLocation?
        var artist: String?
        var copyright: String?

        static func == (lhs: Fields, rhs: Fields) -> Bool {
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

    /// Single source of truth for the form data
    var fields: Fields

    // Read-only display fields (not part of editable state)
    let pixelWidth: String?
    let pixelHeight: String?
    let profileName: String?

    // UI state
    var locationAddress: String?
    private(set) var isGeocoding = false

    private let initialFields: Fields
    private let geocoder = CLGeocoder()
    private var geocodingTask: Task<Void, Never>?

    init(metadata: Metadata) {
        let props = metadata.sourceProperties
        let exif = props[MetadataKeys.exifDict] as? [String: Any] ?? [:]
        let tiff = props[MetadataKeys.tiffDict] as? [String: Any] ?? [:]

        pixelWidth = (props[MetadataField.pixelWidth.key] as? Int).map { "\($0)" }
        pixelHeight = (props[MetadataField.pixelHeight.key] as? Int).map { "\($0)" }
        profileName = props[MetadataField.profileName.key] as? String

        // Temporary variables for construction
        let make = tiff[MetadataKeys.make] as? String
        let model = tiff[MetadataKeys.model] as? String
        let lensMake = exif[MetadataKeys.lensMake] as? String
        let lensModel = exif[MetadataKeys.lensModel] as? String

        var aperture: String?
        if let val = exif[MetadataKeys.fNumber] as? Double {
            aperture = Self.formatValue(val)
        }

        var shutter: String?
        if let val = exif[MetadataKeys.exposureTime] as? Double {
            let rational = Rational(approximationOf: val)
            shutter = rational.num < rational.den ? "\(rational.num)/\(rational.den)" : Self.formatValue(val)
        }

        var iso: String?
        if let isoRatings = exif[MetadataKeys.isoSpeedRatings] as? [Int], let firstIso = isoRatings.first {
            iso = "\(firstIso)"
        } else if let isoInt = exif[MetadataKeys.isoSpeedRatings] as? Int {
            iso = "\(isoInt)"
        }

        var focalLength: String?
        if let val = exif[MetadataKeys.focalLength] as? Double {
            focalLength = Self.formatValue(val)
        }

        var exposureBias: String?
        if let val = exif[MetadataKeys.exposureBiasValue] as? Double {
            exposureBias = val > 0 ? "+" + Self.formatValue(val) : Self.formatValue(val)
        }

        var focalLength35: String?
        if let val = exif[MetadataKeys.focalLenIn35mmFilm] as? Int {
            focalLength35 = "\(val)"
        } else if let val = exif[MetadataKeys.focalLenIn35mmFilm] as? Double {
            focalLength35 = "\(Int(val))"
        }

        let dateTimeOriginal: Date
        if let dateStr = exif[MetadataKeys.dateTimeOriginal] as? String,
           let date = DateFormatter.yMdHms.date(from: dateStr) {
            dateTimeOriginal = min(date, Date())
        } else {
            dateTimeOriginal = Date()
        }

        let parsedFields = Fields(
            make: make,
            model: model,
            lensMake: lensMake,
            lensModel: lensModel,
            aperture: aperture,
            shutter: shutter,
            iso: iso,
            focalLength: focalLength,
            exposureBias: exposureBias,
            focalLength35: focalLength35,
            exposureProgram: exif[MetadataKeys.exposureProgram] as? Int,
            meteringMode: exif[MetadataKeys.meteringMode] as? Int,
            whiteBalance: exif[MetadataKeys.whiteBalance] as? Int,
            flash: exif[MetadataKeys.flash] as? Int,
            dateTimeOriginal: dateTimeOriginal,
            location: metadata.rawGPS,
            artist: tiff[MetadataKeys.artist] as? String,
            copyright: tiff[MetadataKeys.copyright] as? String
        )

        fields = parsedFields
        initialFields = parsedFields

        if let loc = parsedFields.location {
            reverseGeocode(loc)
        }
    }

    var isModified: Bool {
        return fields != initialFields
    }

    /// Centralized update method to avoid switch-cases in the ViewController.
    func updateValue(_ value: Any?, for field: MetadataField) {
        switch field {
        case .make: fields.make = value as? String
        case .model: fields.model = value as? String
        case .lensMake: fields.lensMake = value as? String
        case .lensModel: fields.lensModel = value as? String
        case .aperture: fields.aperture = value as? String
        case .shutter: fields.shutter = value as? String
        case .iso: fields.iso = value as? String
        case .focalLength: fields.focalLength = value as? String
        case .exposureBias: fields.exposureBias = value as? String
        case .focalLength35: fields.focalLength35 = value as? String
        case .exposureProgram: fields.exposureProgram = value as? Int
        case .meteringMode: fields.meteringMode = value as? Int
        case .whiteBalance: fields.whiteBalance = value as? Int
        case .flash: fields.flash = value as? Int
        case .artist: fields.artist = value as? String
        case .copyright: fields.copyright = value as? String
        case .dateTimeOriginal: if let d = value as? Date { fields.dateTimeOriginal = min(d, Date()) }
        case .location: if let l = value as? CLLocation { fields.location = l }
        default: break
        }
    }

    func reverseGeocode(_ loc: CLLocation) {
        fields.location = loc
        geocodingTask?.cancel()
        geocoder.cancelGeocode()
        isGeocoding = true
        locationAddress = "..."

        geocodingTask = Task {
            do {
                let placemarks = try await geocoder.reverseGeocodeLocation(loc)
                guard !Task.isCancelled else { return }
                isGeocoding = false
                if let p = placemarks.first {
                    let infos = [p.thoroughfare, p.locality, p.administrativeArea, p.country]
                    locationAddress = infos.compactMap { $0 }.joined(separator: ", ")
                } else {
                    locationAddress = Self.coordinateFallback(for: loc)
                }
            } catch {
                guard !Task.isCancelled else { return }
                isGeocoding = false
                locationAddress = Self.coordinateFallback(for: loc)
            }
        }
    }

    private static func coordinateFallback(for location: CLLocation) -> String {
        String(format: "%.4f, %.4f", location.coordinate.latitude, location.coordinate.longitude)
    }

    private static func formatValue(_ value: Double) -> String {
        return value.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", value) : String(
            format: "%.1f",
            value
        )
    }

    func getPreparedFields() -> [MetadataField: MetadataFieldValue] {
        return prepareFields(from: fields)
    }

    /// Converts raw UI inputs into a metadata fields dictionary.
    private func prepareFields(from raw: Fields) -> [MetadataField: MetadataFieldValue] {
        var fieldsDict: [MetadataField: MetadataFieldValue] = [:]

        fieldsDict[.make] = (raw.make?.isEmpty ?? true) ? .null : .string(raw.make!)
        fieldsDict[.model] = (raw.model?.isEmpty ?? true) ? .null : .string(raw.model!)
        fieldsDict[.lensMake] = (raw.lensMake?.isEmpty ?? true) ? .null : .string(raw.lensMake!)
        fieldsDict[.lensModel] = (raw.lensModel?.isEmpty ?? true) ? .null : .string(raw.lensModel!)

        // Aperture
        if let val = raw.aperture, let d = Double(val) {
            fieldsDict[.aperture] = .double(d)
        } else {
            fieldsDict[.aperture] = .null
        }

        // Shutter Speed
        if let val = raw.shutter, !val.isEmpty {
            if val.contains("/") {
                let parts = val.components(separatedBy: "/")
                if parts.count == 2, let n = Double(parts[0]), let d = Double(parts[1]), d != 0 {
                    fieldsDict[.shutter] = .double(n / d)
                } else {
                    fieldsDict[.shutter] = .null
                }
            } else if let d = Double(val) {
                fieldsDict[.shutter] = .double(d)
            } else {
                fieldsDict[.shutter] = .null
            }
        } else {
            fieldsDict[.shutter] = .null
        }

        // ISO
        if let val = raw.iso, let i = Int(val) {
            fieldsDict[.iso] = .intArray([i])
        } else {
            fieldsDict[.iso] = .null
        }

        // Focal Length
        if let val = raw.focalLength, let d = Double(val) {
            fieldsDict[.focalLength] = .double(d)
        } else {
            fieldsDict[.focalLength] = .null
        }

        // Exposure Bias
        if let val = raw.exposureBias, !val.isEmpty {
            let cleanVal = val.replacingOccurrences(of: "+", with: "")
            if let d = Double(cleanVal) {
                fieldsDict[.exposureBias] = .double(d)
            } else {
                fieldsDict[.exposureBias] = .null
            }
        } else {
            fieldsDict[.exposureBias] = .null
        }

        // Focal Length In 35mm
        if let val = raw.focalLength35, let i = Int(val) {
            fieldsDict[.focalLength35] = .int(i)
        } else {
            fieldsDict[.focalLength35] = .null
        }

        // Pickers
        fieldsDict[.exposureProgram] = raw.exposureProgram.map { .int($0) } ?? .null
        fieldsDict[.meteringMode] = raw.meteringMode.map { .int($0) } ?? .null
        fieldsDict[.whiteBalance] = raw.whiteBalance.map { .int($0) } ?? .null
        fieldsDict[.flash] = raw.flash.map { .int($0) } ?? .null

        // Date and Location
        fieldsDict[.dateTimeOriginal] = .date(raw.dateTimeOriginal)
        fieldsDict[.location] = raw.location.map { .location($0) } ?? .null

        // Copyright
        fieldsDict[.artist] = (raw.artist?.isEmpty ?? true) ? .null : .string(raw.artist!)
        fieldsDict[.copyright] = (raw.copyright?.isEmpty ?? true) ? .null : .string(raw.copyright!)

        return fieldsDict
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
