//
//  MetadataEditViewController.swift
//  MetaX
//
//  Created by Yuhan Chen on 2026/02/09.
//  Copyright © 2026 Yuhan Chen. All rights reserved.
//

import CoreLocation
import UIKit

@MainActor
final class MetadataEditViewController: MetadataFormViewController {

    private let currentMetadata: Metadata
    private let viewModel: MetadataEditViewModel

    private let datePicker: UIDatePicker = {
        let picker = UIDatePicker()
        picker.datePickerMode = .dateAndTime
        picker.preferredDatePickerStyle = .compact
        picker.maximumDate = Date()
        return picker
    }()

    // MARK: - Initialization

    init(metadata: Metadata, viewModel: MetadataEditViewModel) {
        currentMetadata = metadata
        self.viewModel = viewModel
        super.init(formViewModel: viewModel)
        setupFields()
    }

    // MARK: - Template Overrides

    override var formTitle: String { String(localized: .viewEditMetadata) }

    override var formSections: [FormSection] {
        [
            FormSection(
                title: String(localized: .editGroupBasicInfo),
                hint: nil,
                fields: [.dateTimeOriginal, .location]
            ),
            FormSection(title: String(localized: .editGroupCopyright), hint: nil, fields: [.artist, .copyright]),
            FormSection(
                title: String(localized: .editGroupGear),
                hint: .editHintGear,
                fields: [.make, .model, .lensMake, .lensModel]
            ),
            FormSection(title: String(localized: .shooting), hint: .editHintExposure, fields: [
                .aperture, .shutter, .iso, .focalLength, .exposureBias, .focalLength35,
                .exposureProgram, .meteringMode, .whiteBalance, .flash,
            ]),
            FormSection(
                title: String(localized: .editGroupFileInfo),
                hint: .editHintFileInfo,
                fields: [.pixelWidth, .pixelHeight, .profileName]
            ),
        ]
    }

    // MARK: - Field Setup

    override func setupFields() {
        for field in MetadataField.allCases {
            switch field {
            case .dateTimeOriginal:
                fieldViews[field] = UIView() // Spacer — date row built inline in section loop override
            case .location:
                fieldViews[field] = LocationCardField(label: field.label)
            case .exposureProgram, .meteringMode, .whiteBalance, .flash:
                let options: [ExifOption]
                switch field {
                case .exposureProgram: options = ExifPickerOptions.exposureProgram
                case .meteringMode: options = ExifPickerOptions.meteringMode
                case .whiteBalance: options = ExifPickerOptions.whiteBalance
                default: options = ExifPickerOptions.flash
                }
                fieldViews[field] = FormPickerField(label: field.label, options: options)
            default:
                let isReadOnly = [.pixelWidth, .pixelHeight, .profileName].contains(field)
                let formField = FormTextField(
                    label: field.label,
                    placeholder: field.placeholder,
                    keyboardType: field.keyboardType,
                    readOnly: isReadOnly,
                    unit: field.unit
                )
                fieldViews[field] = formField
                textFieldToField[formField.textField] = field
            }
        }
    }

    // MARK: - Bindings

    override func setupBindings() {
        let tf = { (field: MetadataField) -> UITextField? in (self.fieldViews[field] as? FormTextField)?.textField }
        let pf = { (field: MetadataField) -> FormPickerField? in (self.fieldViews[field] as? FormPickerField) }

        // Observe nested Fields struct properties
        observe(viewModel: viewModel, property: { $0.fields.dateTimeOriginal }) { [weak self] in
            self?.datePicker.date = $0
        }
        observe(viewModel: viewModel, property: { $0.locationAddress }) { [weak self] addr in
            guard let self, let loc = viewModel.fields.location else { return }
            (self.fieldViews[.location] as? LocationCardField)?.setLocation(loc, title: addr)
        }

        observe(viewModel: viewModel, property: { $0.fields.make }) { tf(.make)?.text = $0 }
        observe(viewModel: viewModel, property: { $0.fields.model }) { tf(.model)?.text = $0 }
        observe(viewModel: viewModel, property: { $0.fields.lensMake }) { tf(.lensMake)?.text = $0 }
        observe(viewModel: viewModel, property: { $0.fields.lensModel }) { tf(.lensModel)?.text = $0 }
        observe(viewModel: viewModel, property: { $0.fields.aperture }) { tf(.aperture)?.text = $0 }
        observe(viewModel: viewModel, property: { $0.fields.shutter }) { tf(.shutter)?.text = $0 }
        observe(viewModel: viewModel, property: { $0.fields.iso }) { tf(.iso)?.text = $0 }
        observe(viewModel: viewModel, property: { $0.fields.focalLength }) { tf(.focalLength)?.text = $0 }
        observe(viewModel: viewModel, property: { $0.fields.exposureBias }) { tf(.exposureBias)?.text = $0 }
        observe(viewModel: viewModel, property: { $0.fields.focalLength35 }) { tf(.focalLength35)?.text = $0 }

        observe(viewModel: viewModel, property: { $0.fields.exposureProgram }) {
            if let v = $0 { pf(.exposureProgram)?.select(rawValue: v) }
        }
        observe(viewModel: viewModel, property: { $0.fields.meteringMode }) {
            if let v = $0 { pf(.meteringMode)?.select(rawValue: v) }
        }
        observe(viewModel: viewModel, property: { $0.fields.whiteBalance }) {
            if let v = $0 { pf(.whiteBalance)?.select(rawValue: v) }
        }
        observe(viewModel: viewModel, property: { $0.fields.flash }) {
            if let v = $0 { pf(.flash)?.select(rawValue: v) }
        }

        observe(viewModel: viewModel, property: { $0.fields.artist }) { tf(.artist)?.text = $0 }
        observe(viewModel: viewModel, property: { $0.fields.copyright }) { tf(.copyright)?.text = $0 }

        // Read-only display fields
        tf(.pixelWidth)?.text = viewModel.pixelWidth
        tf(.pixelHeight)?.text = viewModel.pixelHeight
        tf(.profileName)?.text = viewModel.profileName

        // Save button enabled state
        observe(viewModel: viewModel, property: { $0.isModified }) { [weak self] in
            self?.navigationItem.rightBarButtonItem?.isEnabled = $0
        }

        // User action handling
        datePicker.addTarget(self, action: #selector(dateChanged), for: .valueChanged)

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

    // MARK: - Date Row Override

    /// Single-photo editor builds the date row inline (label + compact picker).
    /// Override the section building to handle .dateTimeOriginal specially.
    override func viewDidLoad() {
        // We need to patch the date field into the section before super builds the form.
        // The base class iterates formSections and looks up fieldViews[field].
        // For .dateTimeOriginal we stored a spacer UIView — we replace it now with the real date row.
        let dateLabel = UILabel()
        dateLabel.text = MetadataField.dateTimeOriginal.label
        dateLabel.font = Theme.Typography.footnote
        dateLabel.textColor = .secondaryLabel
        let dateRow = UIStackView(arrangedSubviews: [dateLabel, datePicker])
        dateRow.axis = .vertical; dateRow.spacing = 8; dateRow.alignment = .leading
        fieldViews[.dateTimeOriginal] = dateRow

        super.viewDidLoad()
    }

    @objc private func dateChanged() {
        viewModel.updateValue(.date(datePicker.date), for: .dateTimeOriginal)
    }
}
