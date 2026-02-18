//
//  MetadataEditViewController.swift
//  MetaX
//
//  Created by Yuhan Chen on 2026/02/09.
//  Copyright © 2026 Yuhan Chen. All rights reserved.
//

import CoreLocation
import MapKit
import UIKit

@MainActor
final class MetadataEditViewController: UIViewController, UITextFieldDelegate,
    UIAdaptivePresentationControllerDelegate, ViewModelObserving {

    var onSave: (([MetadataField: MetadataFieldValue]) -> Void)?
    var onCancel: (() -> Void)?
    var onRequestLocationSearch: (() -> Void)?

    private let currentMetadata: Metadata
    private let viewModel: MetadataEditViewModel

    private var keyboardObserver: KeyboardObserver?

    // Strongly-typed field management
    private var fieldViews: [MetadataField: UIView] = [:]
    private var textFieldToField: [UITextField: MetadataField] = [:]

    struct FormSection {
        let title: String
        let hint: LocalizedStringResource?
        let fields: [MetadataField]
    }

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.alwaysBounceVertical = true
        sv.keyboardDismissMode = .onDrag
        sv.showsVerticalScrollIndicator = false
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 32
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let datePicker: UIDatePicker = {
        let picker = UIDatePicker()
        picker.datePickerMode = .dateAndTime
        picker.preferredDatePickerStyle = .compact
        picker.maximumDate = Date()
        return picker
    }()

    init(metadata: Metadata, viewModel: MetadataEditViewModel) {
        currentMetadata = metadata
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
        setupFields()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError()
    }

    private func setupFields() {
        for field in MetadataField.allCases {
            switch field {
            case .dateTimeOriginal:
                fieldViews[field] = UIView() // Spacer for date row
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

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupAccessoryViews()
        setupDelegates()
        setupBindings()

        keyboardObserver = KeyboardObserver(scrollView: scrollView)
        keyboardObserver?.startObserving()
    }

    private func setupUI() {
        title = String(localized: .viewEditMetadata)
        view.backgroundColor = Theme.Colors.mainBackground

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancel)
        )

        let saveButton = UIBarButtonItem(
            title: String(localized: .save),
            style: .done,
            target: self,
            action: #selector(save)
        )
        saveButton.tintColor = Theme.Colors.accent
        navigationItem.rightBarButtonItem = saveButton

        view.addSubview(scrollView)
        scrollView.addSubview(stackView)

        (fieldViews[.location] as? LocationCardField)?.button.addTarget(
            self,
            action: #selector(searchLocation),
            for: .touchUpInside
        )

        let sections = [
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

        for section in sections {
            var views: [UIView] = []
            if let hint = section.hint {
                views.append(createHint(resource: hint, color: .systemGray))
            }

            for field in section.fields {
                if field == .dateTimeOriginal {
                    let dateLabel = UILabel()
                    dateLabel.text = field.label
                    dateLabel.font = Theme.Typography.footnote
                    dateLabel.textColor = .secondaryLabel
                    let dateRow = UIStackView(arrangedSubviews: [dateLabel, datePicker])
                    dateRow.axis = .vertical; dateRow.spacing = 8; dateRow.alignment = .leading
                    views.append(dateRow)
                } else if let view = fieldViews[field] {
                    views.append(view)
                }
            }
            stackView.addArrangedSubview(createGroup(title: section.title, views: views))
        }

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.leadingAnchor,
                constant: Theme.Layout.standardPadding
            ),
            stackView.trailingAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.trailingAnchor,
                constant: -Theme.Layout.standardPadding
            ),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -40),
        ])

        let tap = UITapGestureRecognizer(target: view, action: #selector(UIView.endEditing))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    private func setupBindings() {
        let tf = { (field: MetadataField) -> UITextField? in (self.fieldViews[field] as? FormTextField)?.textField }
        let pf = { (field: MetadataField) -> FormPickerField? in (self.fieldViews[field] as? FormPickerField) }

        // 1. Observe nested Fields struct properties
        observe(viewModel: viewModel, property: { $0.fields.dateTimeOriginal }) { [weak self] in
            self?.datePicker.date = $0
        }
        observe(viewModel: viewModel, property: { $0.locationAddress }) { [weak self] addr in
            guard let self, let loc = viewModel.fields.location else { return }
            (fieldViews[.location] as? LocationCardField)?.setLocation(loc, title: addr)
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

        // 2. Read-only display fields
        tf(.pixelWidth)?.text = viewModel.pixelWidth
        tf(.pixelHeight)?.text = viewModel.pixelHeight
        tf(.profileName)?.text = viewModel.profileName

        // 3. UI State
        observe(viewModel: viewModel, property: { $0.isModified }) { [weak self] in
            self?.navigationItem.rightBarButtonItem?.isEnabled = $0
        }

        // 4. Centralized User Action Handling
        datePicker.addTarget(self, action: #selector(dateChanged), for: .valueChanged)

        for (field, view) in fieldViews {
            if let tfView = view as? FormTextField {
                tfView.textField.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
            } else if let pfView = view as? FormPickerField {
                pfView.onValueChanged = { [weak self] in
                    self?.viewModel.updateValue(pfView.selectedRawValue, for: field)
                }
            }
        }
    }

    @objc private func dateChanged() {
        viewModel.updateValue(datePicker.date, for: .dateTimeOriginal)
    }

    @objc private func textFieldDidChange(_ textField: UITextField) {
        guard let field = textFieldToField[textField] else { return }
        viewModel.updateValue(textField.text, for: field)
    }

    private func setupAccessoryViews() {
        let tf = { (field: MetadataField) -> UITextField? in (self.fieldViews[field] as? FormTextField)?.textField }

        tf(.exposureBias)?.inputAccessoryView = createAccessoryToolbar(items: [
            ("-", #selector(toggleNegative)),
            ("+", #selector(togglePositive)),
        ])

        tf(.shutter)?.inputAccessoryView = createAccessoryToolbar(items: [
            ("/", #selector(insertSlash)),
        ])
    }

    private func createAccessoryToolbar(items: [(String, Selector)]) -> UIView {
        let container = UIView(frame: CGRect(x: 0, y: 0, width: view.frame.width, height: 44))
        container.backgroundColor = .secondarySystemBackground.withAlphaComponent(0.8)

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        for (title, action) in items {
            stack.addArrangedSubview(createAccessoryButton(title: title, action: action))
        }

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 6),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -6),
            stack.widthAnchor.constraint(equalToConstant: CGFloat(items.count * 55)),
        ])

        return container
    }

    private func createAccessoryButton(title: String, action: Selector) -> UIButton {
        var config = UIButton.Configuration.gray()
        config.title = title
        config.baseForegroundColor = Theme.Colors.text
        config.background.backgroundColor = Theme.Colors.cardBackground
        config.background.strokeColor = Theme.Colors.border
        config.background.strokeWidth = 1.0
        config.cornerStyle = .fixed

        let btn = UIButton(configuration: config)
        btn.addTarget(self, action: action, for: .touchUpInside)
        return btn
    }

    @objc private func insertSlash() {
        guard let tf = (fieldViews[.shutter] as? FormTextField)?.textField else { return }
        tf.insertText("/")
        viewModel.updateValue(tf.text, for: .shutter)
    }

    @objc private func togglePositive() {
        guard let tf = (fieldViews[.exposureBias] as? FormTextField)?.textField, var text = tf.text else { return }
        text = text.trimmingCharacters(in: CharacterSet(charactersIn: "+−-"))
        if !text.isEmpty, text != "0" {
            tf.text = "+" + text
        } else if text == "0" {
            tf.text = "0"
        } else {
            tf.text = "+"
        }
        viewModel.updateValue(tf.text, for: .exposureBias)
    }

    @objc private func toggleNegative() {
        guard let tf = (fieldViews[.exposureBias] as? FormTextField)?.textField, var text = tf.text else { return }
        text = text.trimmingCharacters(in: CharacterSet(charactersIn: "+−-"))
        if !text.isEmpty, text != "0" {
            tf.text = "-" + text
        } else if text == "0" {
            tf.text = "0"
        } else {
            tf.text = "-"
        }
        viewModel.updateValue(tf.text, for: .exposureBias)
    }

    @objc private func doneEditing() {
        view.endEditing(true)
    }

    private func setupDelegates() {
        for view in fieldViews.values {
            if let tf = view as? FormTextField {
                tf.textField.delegate = self
            }
        }
    }

    private func createGroup(title: String, views: [UIView]) -> UIView {
        let groupStack = UIStackView(arrangedSubviews: views)
        groupStack.axis = .vertical
        groupStack.spacing = 16

        let pixelIcon = UIView()
        pixelIcon.backgroundColor = Theme.Colors.accent
        pixelIcon.translatesAutoresizingMaskIntoConstraints = false
        pixelIcon.widthAnchor.constraint(equalToConstant: 8).isActive = true
        pixelIcon.heightAnchor.constraint(equalToConstant: 8).isActive = true

        let headerLabel = UILabel()
        headerLabel.text = title
        headerLabel.font = Theme.Typography.subheadline
        headerLabel.textColor = .label

        let headerStack = UIStackView(arrangedSubviews: [pixelIcon, headerLabel])
        headerStack.axis = .horizontal
        headerStack.spacing = 12
        headerStack.alignment = .center

        let container = UIStackView(arrangedSubviews: [headerStack, groupStack])
        container.axis = .vertical
        container.spacing = 12
        return container
    }

    private func createHint(resource: LocalizedStringResource, color: UIColor) -> UIView {
        let container = UIView()

        let line = UIView()
        line.backgroundColor = color
        line.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = String(localized: resource)
        label.font = Theme.Typography.captionMono.withSize(11)
        label.textColor = color
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(line)
        container.addSubview(label)

        NSLayoutConstraint.activate([
            line.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            line.topAnchor.constraint(equalTo: container.topAnchor),
            line.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            line.widthAnchor.constraint(equalToConstant: 3),

            label.leadingAnchor.constraint(equalTo: line.trailingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            label.topAnchor.constraint(equalTo: container.topAnchor),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        return container
    }

    func updateLocation(from model: LocationModel) {
        guard let coord = model.coordinate else { return }
        let location = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        viewModel.reverseGeocode(location)
    }

    func textField(
        _ textField: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        guard let field = textFieldToField[textField] else { return true }

        // Special handling for Exposure Compensation: auto-prefix '+' if first char is a digit
        if field == .exposureBias {
            let currentText = textField.text ?? ""
            if currentText.isEmpty,
               let firstScalar = string.unicodeScalars.first,
               CharacterSet.decimalDigits.contains(firstScalar),
               string != "0" {
                let newText = "+" + string
                textField.text = newText
                viewModel.updateValue(newText, for: field)
                return false
            }
        }

        return viewModel.validateInput(
            currentText: textField.text ?? "",
            range: range,
            replacementString: string,
            for: field
        )
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    @objc private func searchLocation() {
        onRequestLocationSearch?()
    }

    @objc private func cancel() {
        onCancel?()
    }

    @objc private func save() {
        let fields = viewModel.getPreparedFields()
        onSave?(fields)
    }
}

extension MetadataEditViewController {
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        onCancel?()
    }
}
