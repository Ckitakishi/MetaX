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

private enum FieldDraft<Value> {
    case untouched
    case cleared
    case value(Value)
}

private enum BatchMetadataDraftKind {
    case string
    case int
    case date
    case location
    case unsupported
}

/// ViewModel for batch metadata editing.
/// All fields start empty — only fields the user explicitly fills will be applied.
@Observable @MainActor
final class BatchMetadataEditViewModel: MetadataFormEditing {

    // MARK: - Field State

    private var stringDrafts: [MetadataField: FieldDraft<String>] = [:]
    private var intDrafts: [MetadataField: FieldDraft<Int>] = [:]
    private var dateDrafts: [MetadataField: FieldDraft<Date>] = [:]
    private var locationDrafts: [MetadataField: FieldDraft<CLLocation>] = [:]

    /// String-based fields: nil means "don't change", empty string means "clear".
    var make: String? { stringValue(for: .make) }
    var model: String? { stringValue(for: .model) }
    var lensMake: String? { stringValue(for: .lensMake) }
    var lensModel: String? { stringValue(for: .lensModel) }
    var aperture: String? { stringValue(for: .aperture) }
    var shutter: String? { stringValue(for: .shutter) }
    var iso: String? { stringValue(for: .iso) }
    var focalLength: String? { stringValue(for: .focalLength) }
    var exposureBias: String? { stringValue(for: .exposureBias) }
    var focalLength35: String? { stringValue(for: .focalLength35) }
    var artist: String? { stringValue(for: .artist) }
    var copyright: String? { stringValue(for: .copyright) }

    /// Picker-based fields: nil means "don't change".
    var exposureProgram: Int? { intValue(for: .exposureProgram) }
    var meteringMode: Int? { intValue(for: .meteringMode) }
    var whiteBalance: Int? { intValue(for: .whiteBalance) }
    var flash: Int? { intValue(for: .flash) }

    /// Date is applied when the field is enabled.
    var dateTimeOriginal: Date { dateValue(for: .dateTimeOriginal) ?? .init() }

    /// Location: nil means "don't change".
    var location: CLLocation? { locationValue(for: .location) }
    var locationAddress: String?
    private(set) var isGeocoding = false

    private let geocoder = CLGeocoder()
    private var geocodingTask: Task<Void, Never>?

    // MARK: - State

    /// True when the user has filled at least one field.
    var hasAnyField: Bool {
        stringDrafts.values.contains { !$0.isUntouched }
            || intDrafts.values.contains { !$0.isUntouched }
            || dateDrafts.values.contains { !$0.isUntouched }
            || locationDrafts.values.contains { !$0.isUntouched }
    }

    func isFieldEnabled(_ field: MetadataField) -> Bool {
        switch field.batchDraftKind {
        case .string:
            !stringDraft(for: field).isUntouched
        case .int:
            !intDraft(for: field).isUntouched
        case .date:
            !dateDraft(for: field).isUntouched
        case .location:
            !locationDraft(for: field).isUntouched
        case .unsupported:
            false
        }
    }

    /// Toggles a field on/off for batch editing.
    /// Enabling a field sets it to `.cleared` — meaning "clear this field on all assets".
    /// The user can then type a value to switch it to `.value(…)` instead.
    /// Date fields are handled differently in the VC: the toggle immediately seeds
    /// `Date()` as a starting value because dates cannot be cleared.
    func setFieldEnabled(_ enabled: Bool, for field: MetadataField) {
        if enabled {
            guard !isFieldEnabled(field) else { return }

            switch field.batchDraftKind {
            case .string:
                stringDrafts[field] = .cleared
            case .int:
                intDrafts[field] = .cleared
            case .date:
                dateDrafts[field] = .cleared
            case .location:
                locationDrafts[field] = .cleared
            case .unsupported:
                break
            }
        } else {
            clearDraft(for: field)
            if field == .location {
                cancelGeocoding()
                locationAddress = nil
            }
        }
    }

    // MARK: - Field Updates

    func updateValue(_ value: MetadataFieldValue?, for field: MetadataField) {
        switch field {
        case .make, .model, .lensMake, .lensModel,
             .aperture, .shutter, .iso, .focalLength, .exposureBias, .focalLength35,
             .artist, .copyright:
            setStringDraft(value?.stringValue, for: field)
        case .exposureProgram, .meteringMode, .whiteBalance, .flash:
            setIntDraft(value?.intValue, for: field)
        case .dateTimeOriginal:
            guard isFieldEnabled(field) else { return }
            if let date = value?.dateValue {
                dateDrafts[field] = .value(min(date, Date()))
            } else {
                dateDrafts[field] = .cleared
            }
        case .location:
            guard isFieldEnabled(field) else { return }
            if let location = value?.locationValue {
                locationDrafts[field] = .value(location)
            } else {
                cancelGeocoding()
                locationDrafts[field] = .cleared
                locationAddress = nil
            }
        default:
            break
        }
    }

    // MARK: - Geocoding

    func reverseGeocode(_ loc: CLLocation) {
        locationDrafts[.location] = .value(loc)
        cancelGeocoding()
        isGeocoding = true
        locationAddress = "..."

        geocodingTask = Task { [weak self] in
            guard let self else { return }
            let address = await ReverseGeocodingFormatter.resolveAddress(for: loc, using: geocoder)
            guard !Task.isCancelled else {
                isGeocoding = false
                return
            }
            isGeocoding = false
            locationAddress = address
        }
    }

    // MARK: - Field Preparation

    /// Returns all non-empty fields as a dictionary ready for the save pipeline.
    func getPreparedFields() -> [MetadataField: MetadataFieldValue] {
        var result: [MetadataField: MetadataFieldValue] = [:]

        func addStringPatch(_ field: MetadataField) {
            switch stringDraft(for: field) {
            case .untouched:
                return
            case .cleared:
                result[field] = .null
            case let .value(value):
                result[field] = value.isEmpty ? .null : .string(value)
            }
        }

        func addDoublePatch(_ field: MetadataField) {
            switch stringDraft(for: field) {
            case .untouched:
                return
            case .cleared:
                result[field] = .null
            case let .value(value):
                guard !value.isEmpty, let number = Double(value) else {
                    result[field] = .null
                    return
                }
                result[field] = .double(number)
            }
        }

        func addIntPatch(_ field: MetadataField) {
            switch field.batchDraftKind {
            case .string:
                switch stringDraft(for: field) {
                case .untouched:
                    return
                case .cleared:
                    result[field] = .null
                case let .value(value):
                    guard !value.isEmpty, let number = Int(value) else {
                        result[field] = .null
                        return
                    }
                    result[field] = .int(number)
                }
            case .int:
                switch intDraft(for: field) {
                case .untouched:
                    return
                case .cleared:
                    result[field] = .null
                case let .value(value):
                    result[field] = .int(value)
                }
            case .date, .location, .unsupported:
                return
            }
        }

        func addIntArrayPatch(_ field: MetadataField) {
            switch stringDraft(for: field) {
            case .untouched:
                return
            case .cleared:
                result[field] = .null
            case let .value(value):
                guard !value.isEmpty, let number = Int(value) else {
                    result[field] = .null
                    return
                }
                result[field] = .intArray([number])
            }
        }

        addStringPatch(.make)
        addStringPatch(.model)
        addStringPatch(.lensMake)
        addStringPatch(.lensModel)
        addStringPatch(.artist)
        addStringPatch(.copyright)

        addDoublePatch(.aperture)
        switch stringDraft(for: .shutter) {
        case .untouched:
            break
        case .cleared:
            result[.shutter] = .null
        case let .value(value):
            result[.shutter] = value.isEmpty ? .null : MetadataFieldConverter.parseShutter(value)
        }
        addIntArrayPatch(.iso)
        addDoublePatch(.focalLength)
        switch stringDraft(for: .exposureBias) {
        case .untouched:
            break
        case .cleared:
            result[.exposureBias] = .null
        case let .value(value):
            if value.isEmpty {
                result[.exposureBias] = .null
            } else {
                let clean = value.replacingOccurrences(of: "+", with: "")
                result[.exposureBias] = Double(clean).map(MetadataFieldValue.double) ?? .null
            }
        }
        addIntPatch(.focalLength35)

        addIntPatch(.exposureProgram)
        addIntPatch(.meteringMode)
        addIntPatch(.whiteBalance)
        addIntPatch(.flash)

        switch dateDraft(for: .dateTimeOriginal) {
        case .untouched:
            break
        case .cleared:
            result[.dateTimeOriginal] = .date(dateTimeOriginal)
        case let .value(date):
            result[.dateTimeOriginal] = .date(date)
        }

        switch locationDraft(for: .location) {
        case .untouched:
            break
        case .cleared:
            result[.location] = .null
        case let .value(location):
            result[.location] = .location(location)
        }

        return result
    }

    func fieldsMarkedForClearing(in preparedFields: [MetadataField: MetadataFieldValue]) -> [MetadataField] {
        preparedFields.compactMap { field, value in
            if case .null = value {
                return field
            }
            return nil
        }.sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
    }

    func fieldsMarkedForUpdate(in preparedFields: [MetadataField: MetadataFieldValue]) -> [MetadataField] {
        preparedFields.compactMap { field, value in
            if case .null = value {
                return nil
            }
            return field
        }.sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
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

    // MARK: - Draft Accessors

    private func setStringDraft(_ value: String?, for field: MetadataField) {
        guard isFieldEnabled(field) else { return }
        stringDrafts[field] = value.map(FieldDraft.value) ?? .cleared
    }

    private func setIntDraft(_ value: Int?, for field: MetadataField) {
        guard isFieldEnabled(field) else { return }
        intDrafts[field] = value.map(FieldDraft.value) ?? .cleared
    }

    private func clearDraft(for field: MetadataField) {
        stringDrafts.removeValue(forKey: field)
        intDrafts.removeValue(forKey: field)
        dateDrafts.removeValue(forKey: field)
        locationDrafts.removeValue(forKey: field)
    }

    private func cancelGeocoding() {
        geocodingTask?.cancel()
        geocodingTask = nil
        geocoder.cancelGeocode()
        isGeocoding = false
    }

    private func stringDraft(for field: MetadataField) -> FieldDraft<String> {
        stringDrafts[field, default: .untouched]
    }

    private func intDraft(for field: MetadataField) -> FieldDraft<Int> {
        intDrafts[field, default: .untouched]
    }

    private func dateDraft(for field: MetadataField) -> FieldDraft<Date> {
        dateDrafts[field, default: .untouched]
    }

    private func locationDraft(for field: MetadataField) -> FieldDraft<CLLocation> {
        locationDrafts[field, default: .untouched]
    }

    private func stringValue(for field: MetadataField) -> String? {
        switch stringDraft(for: field) {
        case .untouched:
            return nil
        case .cleared:
            return ""
        case let .value(value):
            return value
        }
    }

    private func intValue(for field: MetadataField) -> Int? {
        guard case let .value(value) = intDraft(for: field) else { return nil }
        return value
    }

    private func dateValue(for field: MetadataField) -> Date? {
        guard case let .value(value) = dateDraft(for: field) else { return nil }
        return value
    }

    private func locationValue(for field: MetadataField) -> CLLocation? {
        guard case let .value(value) = locationDraft(for: field) else { return nil }
        return value
    }
}

extension MetadataField {
    fileprivate var batchDraftKind: BatchMetadataDraftKind {
        switch self {
        case .make, .model, .lensMake, .lensModel,
             .aperture, .shutter, .iso, .focalLength, .exposureBias, .focalLength35,
             .artist, .copyright:
            .string
        case .exposureProgram, .meteringMode, .whiteBalance, .flash:
            .int
        case .dateTimeOriginal:
            .date
        case .location:
            .location
        default:
            .unsupported
        }
    }
}

extension FieldDraft {
    fileprivate var isUntouched: Bool {
        if case .untouched = self {
            return true
        }
        return false
    }
}
