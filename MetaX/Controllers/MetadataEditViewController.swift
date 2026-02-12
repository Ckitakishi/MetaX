//
//  MetadataEditViewController.swift
//  MetaX
//
//  Created by Yuhan Chen on 2026/02/09.
//  Copyright © 2026 Yuhan Chen. All rights reserved.
//

import UIKit
import CoreLocation
import MapKit

protocol MetadataEditDelegate: AnyObject {
    func metadataEditDidSave(fields: [String: Any], completion: @escaping (Bool) -> Void)
}

final class MetadataEditViewController: UIViewController, UITextFieldDelegate {

    weak var delegate: MetadataEditDelegate?
    private let currentMetadata: Metadata
    private let container: DependencyContainer
    private let viewModel = MetadataEditViewModel()
    private var selectedLocation: CLLocation?
    private let geocoder = CLGeocoder()
    private var geocodingTask: Task<Void, Never>?
    private var keyboardObserver: KeyboardObserver?

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

    private let dateLabel: UILabel = {
        let label = UILabel()
        label.text = String(localized: .viewAddDate)
        label.font = Theme.Typography.captionMono
        label.textColor = .secondaryLabel
        return label
    }()

    private let datePicker: UIDatePicker = {
        let picker = UIDatePicker()
        picker.datePickerMode = .dateAndTime
        picker.preferredDatePickerStyle = .compact
        return picker
    }()

    private let locationField = LocationCardField(label: String(localized: .viewAddLocation))

    private let artistField = FormTextField(label: String(localized: .artist), placeholder: "Artist name", maxLength: 64)
    private let copyrightField = FormTextField(label: String(localized: .copyright), placeholder: "Copyright notice", maxLength: 200)

    private let makeField = FormTextField(label: String(localized: .make), placeholder: "SONY", maxLength: 64)
    private let modelField = FormTextField(label: String(localized: .model), placeholder: "ILCE-7C", maxLength: 64)
    private let lensMakeField = FormTextField(label: String(localized: .lensMake), placeholder: "SONY", maxLength: 64)
    private let lensModelField = FormTextField(label: String(localized: .lensModel), placeholder: "FE 50mm F1.4 GM", maxLength: 64)

    private let apertureField = FormTextField(label: String(localized: .fnumber), placeholder: "e.g. 2.8", keyboardType: .decimalPad)
    private let shutterField = FormTextField(label: String(localized: .exposureTime), placeholder: "e.g. 1/125", keyboardType: .numbersAndPunctuation)
    private let isoField = FormTextField(label: String(localized: .isospeedRatings), placeholder: "e.g. 400", keyboardType: .numberPad)
    private let focalLengthField = FormTextField(label: String(localized: .focalLength), placeholder: "e.g. 35", keyboardType: .decimalPad)
    private let exposureBiasField = FormTextField(label: String(localized: .exposureBiasValue), placeholder: "e.g. 1.3", keyboardType: .decimalPad)
    private let focalLength35Field = FormTextField(label: String(localized: .focalLenIn35MmFilm), placeholder: "e.g. 28", keyboardType: .numberPad)

    private let exposureProgramPicker = FormPickerField(label: String(localized: .exposureProgram), options: ExifPickerOptions.exposureProgram)
    private let meteringModePicker = FormPickerField(label: String(localized: .meteringMode), options: ExifPickerOptions.meteringMode)
    private let whiteBalancePicker = FormPickerField(label: String(localized: .whiteBalance), options: ExifPickerOptions.whiteBalance)
    private let flashPicker = FormPickerField(label: String(localized: .flash), options: ExifPickerOptions.flash)

    private let pixelWidthField = FormTextField(label: String(localized: .pixelWidth), readOnly: true)
    private let pixelHeightField = FormTextField(label: String(localized: .pixelHeight), readOnly: true)
    private let profileNameField = FormTextField(label: String(localized: .profileName), readOnly: true)

    init(metadata: Metadata, container: DependencyContainer) {
        self.currentMetadata = metadata
        self.container = container
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupAccessoryViews()
        prefillData()
        setupDelegates()

        keyboardObserver = KeyboardObserver(scrollView: scrollView)
        keyboardObserver?.startObserving()
    }

    deinit {
        keyboardObserver?.stopObserving()
        geocodingTask?.cancel()
    }

    private func setupUI() {
        title = String(localized: .viewEditMetadata)
        view.backgroundColor = Theme.Colors.mainBackground

        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(save))

        view.addSubview(scrollView)
        scrollView.addSubview(stackView)

        locationField.button.addTarget(self, action: #selector(searchLocation), for: .touchUpInside)

        let dateRow = UIStackView(arrangedSubviews: [dateLabel, datePicker])
        dateRow.axis = .vertical; dateRow.spacing = 8; dateRow.alignment = .leading
        let basicGroup = createGroup(title: String(localized: .editGroupBasicInfo), views: [dateRow, locationField])
        stackView.addArrangedSubview(basicGroup)

        let copyrightGroup = createGroup(title: String(localized: .editGroupCopyright), views: [artistField, copyrightField])
        stackView.addArrangedSubview(copyrightGroup)

        let gearHint = createHint(resource: .editHintGear, color: .systemGray)
        let gearGroup = createGroup(title: String(localized: .editGroupGear), views: [gearHint, makeField, modelField, lensMakeField, lensModelField])
        stackView.addArrangedSubview(gearGroup)

        let exposureHint = createHint(resource: .editHintExposure, color: .systemGray)
        let exposureGroup = createGroup(title: String(localized: .editGroupExposure), views: [
            exposureHint,
            apertureField, shutterField, isoField, focalLengthField,
            exposureBiasField, focalLength35Field,
            exposureProgramPicker, meteringModePicker, whiteBalancePicker, flashPicker
        ])
        stackView.addArrangedSubview(exposureGroup)

        let fileInfoHint = createHint(resource: .editHintFileInfo, color: .systemGray2)
        let fileInfoGroup = createGroup(title: String(localized: .editGroupFileInfo), views: [fileInfoHint, pixelWidthField, pixelHeightField, profileNameField])
        stackView.addArrangedSubview(fileInfoGroup)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -40),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40)
        ])

        let tap = UITapGestureRecognizer(target: view, action: #selector(UIView.endEditing))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }
    
    private func setupAccessoryViews() {
        let accessoryContainer = UIView(frame: CGRect(x: 0, y: 0, width: view.frame.width, height: 44))
        accessoryContainer.backgroundColor = .secondarySystemBackground.withAlphaComponent(0.8)

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 8
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        accessoryContainer.addSubview(stack)

        stack.addArrangedSubview(createAccessoryButton(title: "−", action: #selector(toggleNegative)))
        stack.addArrangedSubview(createAccessoryButton(title: "+", action: #selector(togglePositive)))

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: accessoryContainer.leadingAnchor, constant: 12),
            stack.topAnchor.constraint(equalTo: accessoryContainer.topAnchor, constant: 6),
            stack.bottomAnchor.constraint(equalTo: accessoryContainer.bottomAnchor, constant: -6),
            stack.widthAnchor.constraint(equalToConstant: 110)
        ])

        exposureBiasField.textField.inputAccessoryView = accessoryContainer
    }
    
    private func createAccessoryButton(title: String, action: Selector) -> UIButton {
        var config = UIButton.Configuration.gray()
        config.title = title
        config.baseForegroundColor = Theme.Colors.text
        config.background.backgroundColor = Theme.Colors.cardBackground
        config.background.cornerRadius = 6
        config.background.strokeColor = Theme.Colors.border
        config.background.strokeWidth = 1.0
        
        let btn = UIButton(configuration: config)
        btn.addTarget(self, action: action, for: .touchUpInside)
        return btn
    }
    
    @objc private func togglePositive() {
        guard var text = exposureBiasField.textField.text else { return }
        text = text.trimmingCharacters(in: CharacterSet(charactersIn: "+−-"))
        if !text.isEmpty {
            exposureBiasField.textField.text = "+" + text
        } else {
            exposureBiasField.textField.text = "+"
        }
    }
    
    @objc private func toggleNegative() {
        guard var text = exposureBiasField.textField.text else { return }
        text = text.trimmingCharacters(in: CharacterSet(charactersIn: "+−-"))
        if !text.isEmpty {
            exposureBiasField.textField.text = "-" + text
        } else {
            exposureBiasField.textField.text = "-"
        }
    }
    
    @objc private func doneEditing() {
        view.endEditing(true)
    }

    private func setupDelegates() {
        let fields: [UITextField] = [
            makeField.textField, modelField.textField, lensMakeField.textField, lensModelField.textField,
            apertureField.textField, shutterField.textField, isoField.textField, focalLengthField.textField,
            exposureBiasField.textField, focalLength35Field.textField,
            artistField.textField, copyrightField.textField
        ]
        fields.forEach { $0.delegate = self }
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
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        return container
    }

    private func prefillData() {
        datePicker.maximumDate = Date()
        let props = currentMetadata.sourceProperties
        let exif = props["{Exif}"] as? [String: Any] ?? [:]
        let tiff = props["{TIFF}"] as? [String: Any] ?? [:]

        makeField.textField.text = tiff["Make"] as? String
        modelField.textField.text = tiff["Model"] as? String
        lensMakeField.textField.text = exif["LensMake"] as? String
        lensModelField.textField.text = exif["LensModel"] as? String

        if let f = exif["FNumber"] as? Double { apertureField.textField.text = String(format: "%.1f", f) }
        if let s = exif["ExposureTime"] as? Double {
            let rational = Rational(approximationOf: s)
            shutterField.textField.text = rational.num < rational.den ? "\(rational.num)/\(rational.den)" : "\(s)"
        }
        if let iso = (exif["ISOSpeedRatings"] as? [Int])?.first { isoField.textField.text = "\(iso)" }
        if let focal = exif["FocalLength"] as? Double { focalLengthField.textField.text = String(format: "%.1f", focal) }
        if let bias = exif["ExposureBiasValue"] as? Double {
            exposureBiasField.textField.text = bias > 0 ? String(format: "+%.1f", bias) : (bias == 0 ? "0" : String(format: "%.1f", bias))
        }
        if let focal35 = exif["FocalLenIn35mmFilm"] as? Int {
            focalLength35Field.textField.text = "\(focal35)"
        } else if let focal35 = exif["FocalLenIn35mmFilm"] as? Double {
            focalLength35Field.textField.text = "\(Int(focal35))"
        }

        if let val = exif["ExposureProgram"] as? Int { exposureProgramPicker.select(rawValue: val) }
        if let val = exif["MeteringMode"] as? Int { meteringModePicker.select(rawValue: val) }
        if let val = exif["WhiteBalance"] as? Int { whiteBalancePicker.select(rawValue: val) }
        if let val = exif["Flash"] as? Int { flashPicker.select(rawValue: val) }

        if let w = props["PixelWidth"] as? Int { pixelWidthField.textField.text = "\(w) px" }
        if let h = props["PixelHeight"] as? Int { pixelHeightField.textField.text = "\(h) px" }
        if let profile = props["ProfileName"] as? String { profileNameField.textField.text = profile }

        artistField.textField.text = tiff["Artist"] as? String
        copyrightField.textField.text = tiff["Copyright"] as? String

        if let dateStr = exif["DateTimeOriginal"] as? String,
           let date = DateFormatter(with: .yMdHms).getDate(from: dateStr) {
            datePicker.date = min(date, Date())
        }

        if let loc = currentMetadata.rawGPS {
            updateLocationInField(with: loc, name: nil)
        }
    }

    private func updateLocationInField(with location: CLLocation, name: String?) {
        self.selectedLocation = location

        if let name = name {
            locationField.setLocation(location, title: name)
            return
        }

        locationField.setLocation(location, title: "...")
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
                locationField.setLocation(location, title: address.isEmpty ? nil : address)
            } catch {
                guard !Task.isCancelled else { return }
                locationField.setLocation(location, title: Self.coordinateFallback(for: location))
            }
        }
    }

    private static func coordinateFallback(for location: CLLocation) -> String {
        String(format: "%.4f, %.4f", location.coordinate.latitude, location.coordinate.longitude)
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let fieldType: MetadataFieldType
        switch textField {
        case isoField.textField: fieldType = .iso
        case apertureField.textField: fieldType = .aperture
        case focalLengthField.textField: fieldType = .focalLength
        case shutterField.textField: fieldType = .shutterSpeed
        case exposureBiasField.textField: fieldType = .exposureBias
        case focalLength35Field.textField: fieldType = .focalLength35
        case artistField.textField: fieldType = .artist
        case copyrightField.textField: fieldType = .copyright
        case makeField.textField, modelField.textField, lensMakeField.textField, lensModelField.textField:
            fieldType = .gear
        default: fieldType = .gear
        }
        
        return viewModel.validateInput(currentText: textField.text ?? "", range: range, replacementString: string, for: fieldType)
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
        dismiss(animated: true)
    }

    @objc private func save() {
        var fields: [String: Any] = [:]

        if let val = makeField.textField.text, !val.isEmpty { fields["Make"] = val }
        if let val = modelField.textField.text, !val.isEmpty { fields["Model"] = val }
        if let val = lensMakeField.textField.text, !val.isEmpty { fields["LensMake"] = val }
        if let val = lensModelField.textField.text, !val.isEmpty { fields["LensModel"] = val }

        if let val = apertureField.textField.text, let d = Double(val) { fields["FNumber"] = d }

        if let val = shutterField.textField.text, !val.isEmpty {
            if val.contains("/") {
                let parts = val.components(separatedBy: "/")
                if parts.count == 2, let n = Double(parts[0]), let d = Double(parts[1]), d != 0 {
                    fields["ExposureTime"] = n / d
                }
            } else if let d = Double(val) {
                fields["ExposureTime"] = d
            }
        }

        if let val = isoField.textField.text, let i = Int(val) { fields["ISOSpeedRatings"] = [i] }
        if let val = focalLengthField.textField.text, let d = Double(val) { fields["FocalLength"] = d }

        if let val = exposureBiasField.textField.text, !val.isEmpty {
            let cleanVal = val.replacingOccurrences(of: "+", with: "")
            if let d = Double(cleanVal) { fields["ExposureBiasValue"] = d }
        }

        if let val = focalLength35Field.textField.text, let i = Int(val) { fields["FocalLenIn35mmFilm"] = i }

        if let val = exposureProgramPicker.selectedRawValue { fields["ExposureProgram"] = val }
        if let val = meteringModePicker.selectedRawValue { fields["MeteringMode"] = val }
        if let val = whiteBalancePicker.selectedRawValue { fields["WhiteBalance"] = val }
        if let val = flashPicker.selectedRawValue { fields["Flash"] = val }

        fields[MetadataKeys.dateTimeOriginal] = datePicker.date
        if let loc = selectedLocation {
            fields[MetadataKeys.location] = loc
        }

        if let val = artistField.textField.text, !val.isEmpty { fields["Artist"] = val }
        if let val = copyrightField.textField.text, !val.isEmpty { fields["Copyright"] = val }

        delegate?.metadataEditDidSave(fields: fields) { [weak self] shouldDismiss in
            if shouldDismiss {
                self?.dismiss(animated: true)
            }
        }
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
