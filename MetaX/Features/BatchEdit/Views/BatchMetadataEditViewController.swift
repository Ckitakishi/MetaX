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
                dateCard.onToggleEnabled = { [weak self] isEnabled in
                    self?.handleFieldToggle(isEnabled, for: .dateTimeOriginal)
                }
                dateCard.onDateSet = { [weak self] date in
                    self?.viewModel.updateValue(.date(date), for: .dateTimeOriginal)
                }
                fieldViews[field] = dateCard
            case .location:
                let locationField = LocationCardField(label: field.label, showsToggle: true)
                locationField.onToggleEnabled = { [weak self] isEnabled in
                    self?.handleFieldToggle(isEnabled, for: .location)
                }
                fieldViews[field] = locationField
            case .exposureProgram, .meteringMode, .whiteBalance, .flash:
                let options: [ExifOption]
                switch field {
                case .exposureProgram: options = ExifPickerOptions.exposureProgram
                case .meteringMode: options = ExifPickerOptions.meteringMode
                case .whiteBalance: options = ExifPickerOptions.whiteBalance
                default: options = ExifPickerOptions.flash
                }
                let pickerField = FormPickerField(
                    label: field.label,
                    options: options,
                    placeholderTitle: String(localized: .batchSelect),
                    showsToggle: true
                )
                pickerField.onToggleEnabled = { [weak self] isEnabled in
                    self?.handleFieldToggle(isEnabled, for: field)
                }
                fieldViews[field] = pickerField
            default:
                let formField = FormTextField(
                    label: field.label,
                    placeholder: field.placeholder,
                    keyboardType: field.keyboardType,
                    readOnly: false,
                    unit: field.unit,
                    showsToggle: true
                )
                formField.onToggleEnabled = { [weak self] isEnabled in
                    self?.handleFieldToggle(isEnabled, for: field)
                }
                fieldViews[field] = formField
                textFieldToField[formField.textField] = field
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
                    pickerField.select(rawValue: rawValue)
                } else {
                    pickerField.clearSelection()
                }
            } else {
                pickerField.clearSelection()
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
}
