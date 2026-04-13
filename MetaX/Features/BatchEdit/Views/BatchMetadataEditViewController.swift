//
//  BatchMetadataEditViewController.swift
//  MetaX
//
//  Created by Yuhan Chen on 2026/03/27.
//  Copyright © 2026 Yuhan Chen. All rights reserved.
//

import CoreLocation
import UIKit

/// Editor for batch metadata editing.
/// Subclass of MetadataFormViewController with batch-specific fields and bindings.
@MainActor
final class BatchMetadataEditViewController: MetadataFormViewController {

    private let viewModel: BatchMetadataEditViewModel
    private let assetCount: Int

    // MARK: - Initialization

    init(viewModel: BatchMetadataEditViewModel, assetCount: Int) {
        self.viewModel = viewModel
        self.assetCount = assetCount
        super.init(formViewModel: viewModel)
        setupFields()
    }

    // MARK: - Template Overrides

    override var formTitle: String { String(localized: .batchEditTitleWithCount(assetCount)) }
    override var saveButtonTitle: String { String(localized: .batchApply) }

    override var formSections: [FormSection] {
        [
            FormSection(
                title: String(localized: .editGroupBasicInfo),
                hint: nil,
                fields: [.dateTimeOriginal, .location]
            ),
            FormSection(
                title: String(localized: .editGroupCopyright),
                hint: nil,
                fields: [.artist, .copyright]
            ),
            FormSection(
                title: String(localized: .editGroupGear),
                hint: .editHintGear,
                fields: [.make, .model, .lensMake, .lensModel]
            ),
            FormSection(
                title: String(localized: .shooting),
                hint: .editHintExposure,
                fields: [
                    .aperture,
                    .shutter,
                    .iso,
                    .focalLength,
                    .exposureBias,
                    .focalLength35,
                    .exposureProgram,
                    .meteringMode,
                    .whiteBalance,
                    .flash,
                ]
            ),
        ]
    }

    override func additionalFormSetup() {
        stackView.addArrangedSubview(createHint(resource: .batchHintBasicInfo, color: .systemGray))
    }

    override func shouldProceedWithSave(fields: [MetadataField: MetadataFieldValue]) async -> Bool {
        let updatedFields = viewModel.fieldsMarkedForUpdate(in: fields)
        let clearedFields = viewModel.fieldsMarkedForClearing(in: fields)
        guard !updatedFields.isEmpty || !clearedFields.isEmpty else { return true }

        var sections: [BatchChangeSummaryViewController.Section] = []

        if !updatedFields.isEmpty {
            let rows = updatedFields.compactMap { field -> BatchChangeSummaryViewController.Row? in
                guard let value = fields[field] else { return nil }
                return .init(title: field.label, value: displayValue(for: field, value: value))
            }
            sections.append(
                .init(
                    title: String(localized: .batchSummaryUpdateSection),
                    rows: rows
                )
            )
        }

        if !clearedFields.isEmpty {
            let rows = clearedFields.map { BatchChangeSummaryViewController.Row(title: $0.label, value: nil) }
            sections.append(
                .init(
                    title: String(localized: .batchSummaryClearSection),
                    rows: rows
                )
            )
        }

        return await BatchChangeSummaryViewController.present(
            title: String(localized: .batchSummaryTitle),
            sections: sections,
            confirmTitle: String(localized: .alertContinue),
            cancelTitle: String(localized: .alertCancel),
            on: self
        )
    }

    // MARK: - Field Setup

    override func setupFields() {
        let editableFields: [MetadataField] = [
            .dateTimeOriginal, .location,
            .artist, .copyright,
            .make, .model, .lensMake, .lensModel,
            .aperture, .shutter, .iso, .focalLength, .exposureBias, .focalLength35,
            .exposureProgram, .meteringMode, .whiteBalance, .flash,
        ]

        for field in editableFields {
            switch field {
            case .dateTimeOriginal:
                let dateCard = DateCardField(label: field.label, showsToggle: true)
                dateCard.onDateSet = { [weak self] date in
                    self?.viewModel.updateValue(.date(date), for: .dateTimeOriginal)
                }
                fieldViews[field] = dateCard
            case .location:
                fieldViews[field] = LocationCardField(label: field.label, showsToggle: true)
            case .exposureProgram, .meteringMode, .whiteBalance, .flash:
                fieldViews[field] = FormPickerField(
                    label: field.label,
                    options: field.exifOptions ?? [],
                    placeholderTitle: String(localized: .batchSelect),
                    showsToggle: true
                )
            default:
                let formField = FormTextField(
                    label: field.label,
                    placeholder: field.placeholder,
                    keyboardType: field.keyboardType,
                    readOnly: false,
                    unit: field.unit,
                    showsToggle: true
                )
                fieldViews[field] = formField
                textFieldToField[formField.textField] = field
            }

            // Wire up toggle callback uniformly via FieldToggleable protocol
            if let togglable = fieldViews[field] as? FieldToggleable {
                togglable.onToggleEnabled = { [weak self] isEnabled in
                    self?.handleFieldToggle(isEnabled, for: field)
                }
            }
        }
    }

    // MARK: - Bindings

    override func setupBindings() {
        for field in fieldViews.keys {
            applyFieldState(for: field)
        }

        observe(viewModel: viewModel, property: { $0.locationAddress }) { [weak self] _ in
            self?.applyFieldState(for: .location)
        }

        observe(viewModel: viewModel, property: { $0.location }) { [weak self] _ in
            self?.applyFieldState(for: .location)
        }

        observe(viewModel: viewModel, property: { $0.hasAnyField }) { [weak self] in
            self?.navigationItem.rightBarButtonItem?.isEnabled = $0
        }

        // User action handling
        for (field, view) in fieldViews {
            if let tfView = view as? FormTextField {
                tfView.textField.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
            } else if let pfView = view as? FormPickerField {
                pfView.onValueChanged = { [weak self] in
                    self?.viewModel.updateValue(pfView.selectedRawValue.map(MetadataFieldValue.int), for: field)
                }
            }
        }
    }

    private func handleFieldToggle(_ isEnabled: Bool, for field: MetadataField) {
        viewModel.setFieldEnabled(isEnabled, for: field)
        if field == .dateTimeOriginal, isEnabled {
            // Date should not be cleared, so seed with "now" as a starting point for the picker.
            viewModel.updateValue(.date(Date()), for: .dateTimeOriginal)
        }
        applyFieldState(for: field)
    }

    private func applyFieldState(for field: MetadataField) {
        let isEnabled = viewModel.isFieldEnabled(field)

        switch field {
        case .dateTimeOriginal:
            guard let dateField = fieldViews[field] as? DateCardField else { return }
            dateField.setFieldEnabled(isEnabled)
            dateField.setDate(viewModel.dateTimeOriginal)
        case .location:
            guard let locationField = fieldViews[field] as? LocationCardField else { return }
            locationField.setFieldEnabled(isEnabled)
            if let loc = viewModel.location {
                locationField.setLocation(loc, title: viewModel.locationAddress)
            } else {
                locationField.setLocation(nil, title: nil)
            }
        case .exposureProgram, .meteringMode, .whiteBalance, .flash:
            guard let pickerField = fieldViews[field] as? FormPickerField else { return }
            pickerField.setFieldEnabled(isEnabled)
            if isEnabled {
                if let rawValue = pickerValue(for: field) {
                    pickerField.setSelection(rawValue: rawValue)
                } else {
                    pickerField.setSelection(rawValue: nil)
                }
            } else {
                pickerField.setSelection(rawValue: nil)
            }
        default:
            guard let textField = fieldViews[field] as? FormTextField else { return }
            textField.setFieldEnabled(isEnabled)
            if !isEnabled {
                textField.textField.text = nil
            }
        }
    }

    private func pickerValue(for field: MetadataField) -> Int? {
        switch field {
        case .exposureProgram: return viewModel.exposureProgram
        case .meteringMode: return viewModel.meteringMode
        case .whiteBalance: return viewModel.whiteBalance
        case .flash: return viewModel.flash
        default: return nil
        }
    }

    private func displayValue(for field: MetadataField, value: MetadataFieldValue) -> String {
        switch value {
        case let .string(text):
            return text
        case let .double(number):
            return abs(number.truncatingRemainder(dividingBy: 1)) < 1e-9
                ? String(format: "%.0f", number)
                : String(format: "%.1f", number)
        case let .int(number):
            return pickerDisplayName(for: field, rawValue: number) ?? String(number)
        case let .intArray(numbers):
            return numbers.map(String.init).joined(separator: ", ")
        case let .date(date):
            return DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .short)
        case let .location(location):
            return viewModel.locationAddress ?? ReverseGeocodingFormatter.coordinateFallback(for: location)
        case .null:
            return ""
        }
    }

    private func pickerDisplayName(for field: MetadataField, rawValue: Int) -> String? {
        field.exifOptions?.first { $0.rawValue == rawValue }?.displayName
    }
}
