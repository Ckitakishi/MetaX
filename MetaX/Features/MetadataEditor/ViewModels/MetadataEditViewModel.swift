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
final class MetadataEditViewModel: MetadataFormEditing {

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
            lhs.make == rhs.make &&
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

        static func isLocationEqual(_ l1: CLLocation?, _ l2: CLLocation?) -> Bool {
            if l1 == nil && l2 == nil { return true }
            guard let l1, let l2 else { return false }
            return l1.coordinate.latitude == l2.coordinate.latitude &&
                l1.coordinate.longitude == l2.coordinate.longitude &&
                l1.altitude == l2.altitude
        }
    }

    // MARK: - Properties

    /// Single source of truth for the form data.
    var fields: Fields

    // Read-only display fields (not part of editable state).
    let pixelWidth: String?
    let pixelHeight: String?
    let profileName: String?

    // UI state
    var locationAddress: String?
    private(set) var isGeocoding = false

    private let initialFields: Fields
    private let geocoder = CLGeocoder()
    private var geocodingTask: Task<Void, Never>?

    // MARK: - Initialization

    init(metadata: Metadata) {
        let props = metadata.sourceProperties
        let exif = props[MetadataKeys.exifDict] as? [String: Any] ?? [:]
        let tiff = props[MetadataKeys.tiffDict] as? [String: Any] ?? [:]

        pixelWidth = (props[MetadataField.pixelWidth.key] as? Int).map { "\($0)" }
        pixelHeight = (props[MetadataField.pixelHeight.key] as? Int).map { "\($0)" }
        profileName = props[MetadataField.profileName.key] as? String

        // Temporary variables for construction.
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

    // MARK: - State Management

    var isModified: Bool {
        fields != initialFields
    }

    /// Centralized update method for form fields.
    func updateValue(_ value: MetadataFieldValue?, for field: MetadataField) {
        switch field {
        case .make: fields.make = value?.stringValue
        case .model: fields.model = value?.stringValue
        case .lensMake: fields.lensMake = value?.stringValue
        case .lensModel: fields.lensModel = value?.stringValue
        case .aperture: fields.aperture = value?.stringValue
        case .shutter: fields.shutter = value?.stringValue
        case .iso: fields.iso = value?.stringValue
        case .focalLength: fields.focalLength = value?.stringValue
        case .exposureBias: fields.exposureBias = value?.stringValue
        case .focalLength35: fields.focalLength35 = value?.stringValue
        case .exposureProgram: fields.exposureProgram = value?.intValue
        case .meteringMode: fields.meteringMode = value?.intValue
        case .whiteBalance: fields.whiteBalance = value?.intValue
        case .flash: fields.flash = value?.intValue
        case .artist: fields.artist = value?.stringValue
        case .copyright: fields.copyright = value?.stringValue
        case .dateTimeOriginal:
            if let date = value?.dateValue {
                fields.dateTimeOriginal = min(date, Date())
            }
        case .location:
            fields.location = value?.locationValue
        default: break
        }
    }

    // MARK: - Geocoding

    func reverseGeocode(_ loc: CLLocation) {
        fields.location = loc
        geocodingTask?.cancel()
        geocoder.cancelGeocode()
        isGeocoding = true
        locationAddress = "..."

        geocodingTask = Task {
            let address = await ReverseGeocodingFormatter.resolveAddress(for: loc, using: geocoder)
            guard !Task.isCancelled else { return }
            isGeocoding = false
            locationAddress = address
        }
    }

    private static func formatValue(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", value) : String(format: "%.1f", value)
    }

    // MARK: - Field Preparation

    func getPreparedFields() -> [MetadataField: MetadataFieldValue] {
        prepareFields(from: fields)
    }

    /// Converts raw UI inputs into a metadata fields dictionary, only including changes.
    private func prepareFields(from raw: Fields) -> [MetadataField: MetadataFieldValue] {
        var fieldsDict: [MetadataField: MetadataFieldValue] = [:]

        func addIfChanged(_ field: MetadataField, current: String?, initial: String?) {
            if (current ?? "") != (initial ?? "") {
                fieldsDict[field] = (current?.isEmpty ?? true) ? .null : .string(current!)
            }
        }

        addIfChanged(.make, current: raw.make, initial: initialFields.make)
        addIfChanged(.model, current: raw.model, initial: initialFields.model)
        addIfChanged(.lensMake, current: raw.lensMake, initial: initialFields.lensMake)
        addIfChanged(.lensModel, current: raw.lensModel, initial: initialFields.lensModel)
        addIfChanged(.artist, current: raw.artist, initial: initialFields.artist)
        addIfChanged(.copyright, current: raw.copyright, initial: initialFields.copyright)

        // Aperture
        if raw.aperture != initialFields.aperture {
            if let val = raw.aperture, let d = Double(val) {
                fieldsDict[.aperture] = .double(d)
            } else {
                fieldsDict[.aperture] = .null
            }
        }

        // Shutter Speed
        if raw.shutter != initialFields.shutter {
            if let val = raw.shutter, !val.isEmpty {
                fieldsDict[.shutter] = MetadataFieldConverter.parseShutter(val)
            } else {
                fieldsDict[.shutter] = .null
            }
        }

        // ISO
        if raw.iso != initialFields.iso {
            if let val = raw.iso, let i = Int(val) {
                fieldsDict[.iso] = .intArray([i])
            } else {
                fieldsDict[.iso] = .null
            }
        }

        // Focal Length
        if raw.focalLength != initialFields.focalLength {
            if let val = raw.focalLength, let d = Double(val) {
                fieldsDict[.focalLength] = .double(d)
            } else {
                fieldsDict[.focalLength] = .null
            }
        }

        // Exposure Bias
        if raw.exposureBias != initialFields.exposureBias {
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
        }

        // Focal Length In 35mm
        if raw.focalLength35 != initialFields.focalLength35 {
            if let val = raw.focalLength35, let i = Int(val) {
                fieldsDict[.focalLength35] = .int(i)
            } else {
                fieldsDict[.focalLength35] = .null
            }
        }

        // Pickers
        if raw.exposureProgram != initialFields.exposureProgram {
            fieldsDict[.exposureProgram] = raw.exposureProgram.map { .int($0) } ?? .null
        }
        if raw.meteringMode != initialFields.meteringMode {
            fieldsDict[.meteringMode] = raw.meteringMode.map { .int($0) } ?? .null
        }
        if raw.whiteBalance != initialFields.whiteBalance {
            fieldsDict[.whiteBalance] = raw.whiteBalance.map { .int($0) } ?? .null
        }
        if raw.flash != initialFields.flash {
            fieldsDict[.flash] = raw.flash.map { .int($0) } ?? .null
        }

        // Date and Location
        if raw.dateTimeOriginal != initialFields.dateTimeOriginal {
            fieldsDict[.dateTimeOriginal] = .date(raw.dateTimeOriginal)
        }
        if !Fields.isLocationEqual(raw.location, initialFields.location) {
            fieldsDict[.location] = raw.location.map { .location($0) } ?? .null
        }

        return fieldsDict
    }

    // MARK: - Validation

    /// Validates if a string change should be allowed for a specific field.
    func validateInput(
        currentText: String,
        range: NSRange,
        replacementString string: String,
        for field: MetadataField
    ) -> Bool {
        MetadataFieldValidator.validate(
            currentText: currentText,
            range: range,
            replacementString: string,
            for: field
        )
    }
}
