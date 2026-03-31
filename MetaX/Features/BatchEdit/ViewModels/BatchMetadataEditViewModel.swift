//
//  BatchMetadataEditViewModel.swift
//  MetaX
//
//  Created by Yuhan Chen on 2026/03/27.
//  Copyright © 2026 Yuhan Chen. All rights reserved.
//

import CoreLocation
import Observation
import UIKit

/// ViewModel for batch metadata editing.
/// All fields start empty — only fields the user explicitly fills will be applied.
@Observable @MainActor
final class BatchMetadataEditViewModel: MetadataFormEditing {

    // MARK: - Field State

    /// String-based fields: nil means "don't change", empty string means "clear".
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
    var artist: String?
    var copyright: String?

    /// Picker-based fields: nil means "don't change".
    var exposureProgram: Int?
    var meteringMode: Int?
    var whiteBalance: Int?
    var flash: Int?

    /// Date is applied when the field is enabled.
    var dateTimeOriginal: Date = .init()

    /// Location: nil means "don't change".
    var location: CLLocation?
    var locationAddress: String?
    private(set) var isGeocoding = false

    private let geocoder = CLGeocoder()
    private var geocodingTask: Task<Void, Never>?
    private var enabledFields: Set<MetadataField> = []

    // MARK: - State

    /// True when the user has filled at least one field.
    var hasAnyField: Bool {
        !enabledFields.isEmpty
    }

    func isFieldEnabled(_ field: MetadataField) -> Bool {
        enabledFields.contains(field)
    }

    func setFieldEnabled(_ enabled: Bool, for field: MetadataField) {
        if enabled {
            enabledFields.insert(field)
        } else {
            enabledFields.remove(field)
            clearValue(for: field)
        }
    }

    // MARK: - Field Updates

    func updateValue(_ value: MetadataFieldValue?, for field: MetadataField) {
        switch field {
        case .make: make = value?.stringValue
        case .model: model = value?.stringValue
        case .lensMake: lensMake = value?.stringValue
        case .lensModel: lensModel = value?.stringValue
        case .aperture: aperture = value?.stringValue
        case .shutter: shutter = value?.stringValue
        case .iso: iso = value?.stringValue
        case .focalLength: focalLength = value?.stringValue
        case .exposureBias: exposureBias = value?.stringValue
        case .focalLength35: focalLength35 = value?.stringValue
        case .exposureProgram: exposureProgram = value?.intValue
        case .meteringMode: meteringMode = value?.intValue
        case .whiteBalance: whiteBalance = value?.intValue
        case .flash: flash = value?.intValue
        case .artist: artist = value?.stringValue
        case .copyright: copyright = value?.stringValue
        case .dateTimeOriginal:
            if let date = value?.dateValue {
                dateTimeOriginal = min(date, Date())
            }
        case .location:
            location = value?.locationValue
            if location == nil {
                locationAddress = nil
            }
        default: break
        }
    }

    private func clearValue(for field: MetadataField) {
        switch field {
        case .make: make = nil
        case .model: model = nil
        case .lensMake: lensMake = nil
        case .lensModel: lensModel = nil
        case .aperture: aperture = nil
        case .shutter: shutter = nil
        case .iso: iso = nil
        case .focalLength: focalLength = nil
        case .exposureBias: exposureBias = nil
        case .focalLength35: focalLength35 = nil
        case .artist: artist = nil
        case .copyright: copyright = nil
        case .exposureProgram: exposureProgram = nil
        case .meteringMode: meteringMode = nil
        case .whiteBalance: whiteBalance = nil
        case .flash: flash = nil
        case .dateTimeOriginal:
            dateTimeOriginal = .init()
        case .location:
            location = nil
            locationAddress = nil
        default:
            break
        }
    }

    // MARK: - Geocoding

    func reverseGeocode(_ loc: CLLocation) {
        location = loc
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

    // MARK: - Field Preparation

    /// Returns all non-empty fields as a dictionary ready for the save pipeline.
    func getPreparedFields() -> [MetadataField: MetadataFieldValue] {
        var result: [MetadataField: MetadataFieldValue] = [:]

        func addTextPatch(_ field: MetadataField, _ value: String?) {
            guard enabledFields.contains(field) else { return }
            guard let value, !value.isEmpty else {
                result[field] = .null
                return
            }
            result[field] = .string(value)
        }

        func addDoublePatch(_ field: MetadataField, _ value: String?) {
            guard enabledFields.contains(field) else { return }
            guard let value, !value.isEmpty else {
                result[field] = .null
                return
            }
            if let number = Double(value) {
                result[field] = .double(number)
            } else {
                result[field] = .null
            }
        }

        func addIntPatch(_ field: MetadataField, _ value: String?) {
            guard enabledFields.contains(field) else { return }
            guard let value, !value.isEmpty else {
                result[field] = .null
                return
            }
            if let number = Int(value) {
                result[field] = .int(number)
            } else {
                result[field] = .null
            }
        }

        func addIntArrayPatch(_ field: MetadataField, _ value: String?) {
            guard enabledFields.contains(field) else { return }
            guard let value, !value.isEmpty else {
                result[field] = .null
                return
            }
            if let number = Int(value) {
                result[field] = .intArray([number])
            } else {
                result[field] = .null
            }
        }

        addTextPatch(.make, make)
        addTextPatch(.model, model)
        addTextPatch(.lensMake, lensMake)
        addTextPatch(.lensModel, lensModel)
        addTextPatch(.artist, artist)
        addTextPatch(.copyright, copyright)

        // Numeric fields
        addDoublePatch(.aperture, aperture)
        if enabledFields.contains(.shutter) {
            if let val = shutter, !val.isEmpty {
                result[.shutter] = MetadataFieldConverter.parseShutter(val)
            } else {
                result[.shutter] = .null
            }
        }
        addIntArrayPatch(.iso, iso)
        addDoublePatch(.focalLength, focalLength)
        if enabledFields.contains(.exposureBias) {
            if let val = exposureBias, !val.isEmpty {
                let clean = val.replacingOccurrences(of: "+", with: "")
                if let d = Double(clean) {
                    result[.exposureBias] = .double(d)
                } else {
                    result[.exposureBias] = .null
                }
            } else {
                result[.exposureBias] = .null
            }
        }
        addIntPatch(.focalLength35, focalLength35)

        // Pickers
        if enabledFields
            .contains(.exposureProgram) {
            result[.exposureProgram] = exposureProgram.map(MetadataFieldValue.int) ?? .null
        }
        if enabledFields
            .contains(.meteringMode) { result[.meteringMode] = meteringMode.map(MetadataFieldValue.int) ?? .null }
        if enabledFields
            .contains(.whiteBalance) { result[.whiteBalance] = whiteBalance.map(MetadataFieldValue.int) ?? .null }
        if enabledFields.contains(.flash) { result[.flash] = flash.map(MetadataFieldValue.int) ?? .null }

        // Date and Location
        if enabledFields.contains(.dateTimeOriginal) {
            result[.dateTimeOriginal] = .date(dateTimeOriginal)
        }
        if enabledFields.contains(.location) {
            result[.location] = location.map(MetadataFieldValue.location) ?? .null
        }

        return result
    }

    // MARK: - Validation (delegates to shared logic)

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
