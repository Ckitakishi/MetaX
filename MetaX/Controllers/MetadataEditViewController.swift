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

final class MetadataEditViewController: UIViewController, UITextFieldDelegate,
    UIAdaptivePresentationControllerDelegate {

    var onSave: (([String: Any]) -> Void)?
    var onCancel: (() -> Void)?

    private let currentMetadata: Metadata
    private let container: DependencyContainer
    private let viewModel = MetadataEditViewModel()

    private var selectedLocation: CLLocation?
    private let geocoder = CLGeocoder()
    private var geocodingTask: Task<Void, Never>?
    private var keyboardObserver: KeyboardObserver?
    private var initialFields: MetadataEditViewModel.RawFields?

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
        return picker
    }()

    init(metadata: Metadata, container: DependencyContainer) {
        currentMetadata = metadata
        self.container = container
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
        prefillData()
        setupDelegates()
        setupChangeTracking()

        keyboardObserver = KeyboardObserver(scrollView: scrollView)
        keyboardObserver?.startObserving()

        updateSaveButtonState()
    }

    deinit {
        keyboardObserver?.stopObserving()
        geocodingTask?.cancel()
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
        navigationItem.rightBarButtonItem?.isEnabled = false // Disabled by default

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
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -40),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40),
        ])

        let tap = UITapGestureRecognizer(target: view, action: #selector(UIView.endEditing))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    private func setupChangeTracking() {
        for view in fieldViews.values {
            if let tf = view as? FormTextField {
                tf.textField.addTarget(self, action: #selector(fieldDidChange), for: .editingChanged)
            } else if let pf = view as? FormPickerField {
                pf.onValueChanged = { [weak self] in self?.updateSaveButtonState() }
            }
        }
        datePicker.addTarget(self, action: #selector(fieldDidChange), for: .valueChanged)
    }

    @objc private func fieldDidChange() {
        updateSaveButtonState()
    }

    private func updateSaveButtonState() {
        let current = captureCurrentFields()
        navigationItem.rightBarButtonItem?.isEnabled = current != initialFields
    }

    private func captureCurrentFields() -> MetadataEditViewModel.RawFields {
        let f = { (field: MetadataField) -> String? in (self.fieldViews[field] as? FormTextField)?.textField.text }
        let p = { (field: MetadataField) -> Int? in (self.fieldViews[field] as? FormPickerField)?.selectedRawValue }

        return MetadataEditViewModel.RawFields(
            make: f(.make),
            model: f(.model),
            lensMake: f(.lensMake),
            lensModel: f(.lensModel),
            aperture: f(.aperture),
            shutter: f(.shutter),
            iso: f(.iso),
            focalLength: f(.focalLength),
            exposureBias: f(.exposureBias),
            focalLength35: f(.focalLength35),
            exposureProgram: p(.exposureProgram),
            meteringMode: p(.meteringMode),
            whiteBalance: p(.whiteBalance),
            flash: p(.flash),
            dateTimeOriginal: datePicker.date,
            location: selectedLocation,
            artist: f(.artist),
            copyright: f(.copyright)
        )
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
        (fieldViews[.shutter] as? FormTextField)?.textField.insertText("/")
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
        updateSaveButtonState()
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
        updateSaveButtonState()
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
        headerLabel.font = .systemFont(ofSize: 16, weight: .bold)
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

    private func prefillData() {
        datePicker.maximumDate = Date()
        let props = currentMetadata.sourceProperties
        let exif = props[MetadataKeys.exifDict] as? [String: Any] ?? [:]
        let tiff = props[MetadataKeys.tiffDict] as? [String: Any] ?? [:]

        let f = fieldViews
        let setTf = { (field: MetadataField, val: Any?) in
            (f[field] as? FormTextField)?.textField.text = val as? String
        }
        let setPicker = { (field: MetadataField, val: Int?) in
            if let v = val { (f[field] as? FormPickerField)?.select(rawValue: v) }
        }

        setTf(.make, tiff[MetadataKeys.make])
        setTf(.model, tiff[MetadataKeys.model])
        setTf(.lensMake, exif[MetadataKeys.lensMake])
        setTf(.lensModel, exif[MetadataKeys.lensModel])

        if let val = exif[MetadataKeys.fNumber] as? Double { setTf(.aperture, formatValue(val)) }
        if let val = exif[MetadataKeys.exposureTime] as? Double {
            let rational = Rational(approximationOf: val)
            setTf(.shutter, rational.num < rational.den ? "\(rational.num)/\(rational.den)" : formatValue(val))
        }
        if let iso = (exif[MetadataKeys.isoSpeedRatings] as? [Int])?.first {
            setTf(.iso, "\(iso)")
        } else if let iso = exif[MetadataKeys.isoSpeedRatings] as? Int {
            setTf(.iso, "\(iso)")
        }
        if let val = exif[MetadataKeys.focalLength] as? Double { setTf(.focalLength, formatValue(val)) }
        if let val = exif[MetadataKeys.exposureBiasValue] as? Double {
            setTf(.exposureBias, val > 0 ? "+" + formatValue(val) : formatValue(val))
        }
        if let val = exif[MetadataKeys.focalLenIn35mmFilm] as? Int {
            setTf(.focalLength35, "\(val)")
        } else if let val = exif[MetadataKeys.focalLenIn35mmFilm] as? Double {
            setTf(.focalLength35, "\(Int(val))")
        }

        setPicker(.exposureProgram, exif[MetadataKeys.exposureProgram] as? Int)
        setPicker(.meteringMode, exif[MetadataKeys.meteringMode] as? Int)
        setPicker(.whiteBalance, exif[MetadataKeys.whiteBalance] as? Int)
        setPicker(.flash, exif[MetadataKeys.flash] as? Int)

        if let val = props["PixelWidth"] as? Int { setTf(.pixelWidth, "\(val)") }
        if let val = props["PixelHeight"] as? Int { setTf(.pixelHeight, "\(val)") }
        setTf(.profileName, props["ProfileName"])

        setTf(.artist, tiff[MetadataKeys.artist])
        setTf(.copyright, tiff[MetadataKeys.copyright])

        if let dateStr = exif[MetadataKeys.dateTimeOriginal] as? String,
           let date = DateFormatter(with: .yMdHms).getDate(from: dateStr) {
            datePicker.date = min(date, Date())
        }

        if let loc = currentMetadata.rawGPS {
            updateLocationInField(with: loc, name: nil)
        }

        initialFields = captureCurrentFields()
    }

    private func formatValue(_ value: Double) -> String {
        return value.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", value) : String(
            format: "%.1f",
            value
        )
    }

    private func updateLocationInField(with location: CLLocation, name: String?) {
        selectedLocation = location
        updateSaveButtonState()

        guard let field = fieldViews[.location] as? LocationCardField else { return }

        if let name = name {
            field.setLocation(location, title: name)
            return
        }

        field.setLocation(location, title: "...")
        geocodingTask?.cancel()
        geocodingTask = Task { [weak self] in
            guard let self else { return }
            do {
                let placemarks = try await geocoder.reverseGeocodeLocation(location)
                guard !Task.isCancelled else { return }
                let address: String
                if let p = placemarks.first {
                    let infos = [p.thoroughfare, p.locality, p.administrativeArea, p.country]
                    address = infos.compactMap { $0 }.joined(separator: ", ")
                } else {
                    address = Self.coordinateFallback(for: location)
                }
                field.setLocation(location, title: address.isEmpty ? nil : address)
            } catch {
                guard !Task.isCancelled else { return }
                field.setLocation(location, title: Self.coordinateFallback(for: location))
            }
        }
    }

    private static func coordinateFallback(for location: CLLocation) -> String {
        String(format: "%.4f, %.4f", location.coordinate.latitude, location.coordinate.longitude)
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
                textField.text = "+" + string
                updateSaveButtonState()
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
        let searchVC = LocationSearchViewController(container: container)
        searchVC.delegate = self
        present(UINavigationController(rootViewController: searchVC), animated: true)
    }

    @objc private func cancel() {
        onCancel?()
    }

    @objc private func save() {
        let fields = viewModel.prepareBatch(from: captureCurrentFields())
        // Don't dismiss yet, wait for save options to be presented on top
        onSave?(fields)
    }
}

extension MetadataEditViewController {
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        onCancel?()
    }
}

extension MetadataEditViewController: LocationSearchDelegate {
    func didSelect(_ model: LocationModel) {
        guard let coord = model.coordinate else { return }
        let location = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        let fullAddress = model.name + (model.shortPlacemark.isEmpty ? "" : ", " + model.shortPlacemark)
        updateLocationInField(with: location, name: fullAddress)
    }
}
