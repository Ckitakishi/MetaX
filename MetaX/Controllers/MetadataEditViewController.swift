//
//  MetadataEditViewController.swift
//  MetaX
//
//  Created by Yuhan Chen on 2026/02/09.
//

import UIKit
import CoreLocation

protocol MetadataEditDelegate: AnyObject {
    func metadataEditDidSave(fields: [String: Any])
}

final class MetadataEditViewController: UIViewController, UITextFieldDelegate {
    
    weak var delegate: MetadataEditDelegate?
    private let currentMetadata: Metadata
    private let container: DependencyContainer
    private var selectedLocation: CLLocation?
    private let geocoder = CLGeocoder()
    private var keyboardObserver: KeyboardObserver?
    
    // MARK: - UI Components
    
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
        stack.spacing = 24
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    // Form Fields
    private let makeField = FormTextField(label: String(localized: .make))
    private let modelField = FormTextField(label: String(localized: .model))
    private let lensField = FormTextField(label: String(localized: .lensModel))
    
    private let apertureField = FormTextField(label: String(localized: .fnumber), placeholder: "e.g. 2.8")
    private let shutterField = FormTextField(label: String(localized: .exposureTime), placeholder: "e.g. 1/125")
    private let isoField = FormTextField(label: String(localized: .isospeedRatings), placeholder: "e.g. 400")
    private let focalLengthField = FormTextField(label: String(localized: .focalLength), placeholder: "e.g. 35")
    
    private let artistField = FormTextField(label: String(localized: .artist))
    private let copyrightField = FormTextField(label: String(localized: .copyright))
    
    private let locationField = FormButtonField(label: String(localized: .viewAddLocation))
    
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
        picker.maximumDate = Date()
        return picker
    }()
    
    // MARK: - Initialization
    
    init(metadata: Metadata, container: DependencyContainer) {
        self.currentMetadata = metadata
        self.container = container
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        prefillData()
        setupDelegates()
        
        keyboardObserver = KeyboardObserver(scrollView: scrollView)
        keyboardObserver?.startObserving()
    }
    
    deinit {
        keyboardObserver?.stopObserving()
    }
    
    private func setupUI() {
        title = String(localized: .viewEditMetadata)
        view.backgroundColor = Theme.Colors.mainBackground
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(save))
        
        view.addSubview(scrollView)
        scrollView.addSubview(stackView)
        
        locationField.button.addTarget(self, action: #selector(searchLocation), for: .touchUpInside)
        
        // Group 1: Basic
        let dateGroup = UIStackView(arrangedSubviews: [dateLabel, datePicker])
        dateGroup.axis = .vertical; dateGroup.spacing = 8; dateGroup.alignment = .leading
        
        let basicGroup = createGroup(title: "BASIC INFO", views: [dateGroup, locationField])
        stackView.addArrangedSubview(basicGroup)
        
        // Group 2: Gear
        let gearGroup = createGroup(title: "GEAR", views: [makeField, modelField, lensField])
        stackView.addArrangedSubview(gearGroup)
        
        // Group 3: Exposure
        let exposureGroup = createGroup(title: "EXPOSURE", views: [apertureField, shutterField, isoField, focalLengthField])
        stackView.addArrangedSubview(exposureGroup)
        
        // Group 4: Rights
        let rightsGroup = createGroup(title: "COPYRIGHT", views: [artistField, copyrightField])
        stackView.addArrangedSubview(rightsGroup)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 20),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40)
        ])
        
        let tap = UITapGestureRecognizer(target: view, action: #selector(UIView.endEditing))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }
    
    private func setupDelegates() {
        let fields = [makeField, modelField, lensField, apertureField, shutterField, isoField, focalLengthField, artistField, copyrightField]
        fields.forEach { $0.textField.delegate = self }
    }
    
    private func createGroup(title: String, views: [UIView]) -> UIView {
        let groupStack = UIStackView(arrangedSubviews: views)
        groupStack.axis = .vertical
        groupStack.spacing = 16
        
        let headerLabel = UILabel()
        headerLabel.text = title
        headerLabel.font = Theme.Typography.indexMono
        headerLabel.textColor = Theme.Colors.accent
        
        let container = UIStackView(arrangedSubviews: [headerLabel, groupStack])
        container.axis = .vertical
        container.spacing = 12
        return container
    }
    
    private func prefillData() {
        let props = currentMetadata.sourceProperties
        let exif = props["{Exif}"] as? [String: Any] ?? [:]
        let tiff = props["{TIFF}"] as? [String: Any] ?? [:]
        
        makeField.textField.text = tiff["Make"] as? String
        modelField.textField.text = tiff["Model"] as? String
        lensField.textField.text = exif["LensModel"] as? String
        
        if let f = exif["FNumber"] as? Double { apertureField.textField.text = "\(f)" }
        if let s = exif["ExposureTime"] as? Double { 
            let rational = Rational(approximationOf: s)
            shutterField.textField.text = rational.num < rational.den ? "\(rational.num)/\(rational.den)" : "\(s)"
        }
        if let iso = (exif["ISOSpeedRatings"] as? [Int])?.first { isoField.textField.text = "\(iso)" }
        if let focal = exif["FocalLength"] as? Double { focalLengthField.textField.text = "\(focal)" }
        
        artistField.textField.text = tiff["Artist"] as? String
        copyrightField.textField.text = tiff["Copyright"] as? String
        
        if let dateStr = exif["DateTimeOriginal"] as? String,
           let date = DateFormatter(with: .yMdHms).getDate(from: dateStr) {
            datePicker.date = min(date, Date())
        }
        
        // Initial location resolve
        if let loc = currentMetadata.rawGPS {
            updateLocationInField(with: loc, name: nil)
        } else {
            locationField.button.setTitle("---", for: .normal)
        }
    }
    
    private func updateLocationInField(with location: CLLocation, name: String?) {
        self.selectedLocation = location
        
        if let name = name {
            locationField.button.setTitle(name, for: .normal)
            return
        }
        
        locationField.button.setTitle("...", for: .normal)
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            let address: String
            if let p = placemarks?.first {
                let infos = [p.thoroughfare, p.locality, p.administrativeArea, p.country]
                address = infos.compactMap { $0 }.joined(separator: ", ")
            } else {
                address = String(format: "%.4f, %.4f", location.coordinate.latitude, location.coordinate.longitude)
            }
            
            DispatchQueue.main.async {
                self?.locationField.button.setTitle(address.isEmpty ? "---" : address, for: .normal)
            }
        }
    }
    
    // MARK: - UITextFieldDelegate
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    // MARK: - Actions
    
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
        
        // Core Metadata Fields
        fields["Make"] = makeField.textField.text
        fields["Model"] = modelField.textField.text
        fields["LensModel"] = lensField.textField.text
        fields["Artist"] = artistField.textField.text
        fields["Copyright"] = copyrightField.textField.text
        
        // Shooting Params
        if let val = apertureField.textField.text, let d = Double(val) { fields["FNumber"] = d }
        if let val = shutterField.textField.text {
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
        
        // Time & Location
        fields[MetadataKeys.dateTimeOriginal] = datePicker.date
        if let loc = selectedLocation {
            fields[MetadataKeys.location] = loc
        }
        
        delegate?.metadataEditDidSave(fields: fields)
        dismiss(animated: true)
    }
}

// MARK: - LocationSearchDelegate
extension MetadataEditViewController: LocationSearchDelegate {
    func didSelect(_ model: LocationModel) {
        guard let coord = model.coordinate else { return }
        let location = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        
        // Use rich name/address directly
        let fullAddress = model.name + (model.shortPlacemark.isEmpty ? "" : ", " + model.shortPlacemark)
        updateLocationInField(with: location, name: fullAddress)
    }
}

// MARK: - Helper Views

private final class FormTextField: UIView {
    let label: UILabel = {
        let l = UILabel()
        l.font = Theme.Typography.captionMono
        l.textColor = .secondaryLabel
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    
    let textField: UITextField = {
        let tf = UITextField()
        tf.backgroundColor = Theme.Colors.tagBackground
        tf.layer.borderWidth = 2
        tf.layer.borderColor = Theme.Colors.border.cgColor
        tf.layer.cornerRadius = 0
        tf.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 0))
        tf.leftViewMode = .always
        tf.font = Theme.Typography.bodyMedium
        tf.translatesAutoresizingMaskIntoConstraints = false
        tf.autocorrectionType = .no
        return tf
    }()
    
    init(label: String, placeholder: String? = nil) {
        super.init(frame: .zero)
        self.label.text = label
        self.textField.placeholder = placeholder
        
        addSubview(self.label)
        addSubview(textField)
        
        NSLayoutConstraint.activate([
            self.label.topAnchor.constraint(equalTo: topAnchor),
            self.label.leadingAnchor.constraint(equalTo: leadingAnchor),
            self.label.trailingAnchor.constraint(equalTo: trailingAnchor),
            
            textField.topAnchor.constraint(equalTo: self.label.bottomAnchor, constant: 6),
            textField.leadingAnchor.constraint(equalTo: leadingAnchor),
            textField.trailingAnchor.constraint(equalTo: trailingAnchor),
            textField.bottomAnchor.constraint(equalTo: bottomAnchor),
            textField.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    required init?(coder: NSCoder) { fatalError() }
}

private final class FormButtonField: UIView {
    let label: UILabel = {
        let l = UILabel()
        l.font = Theme.Typography.captionMono
        l.textColor = .secondaryLabel
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    
    let button: UIButton = {
        let btn = UIButton(type: .custom)
        btn.backgroundColor = Theme.Colors.tagBackground
        btn.layer.borderWidth = 2
        btn.layer.borderColor = Theme.Colors.border.cgColor
        btn.layer.cornerRadius = 0
        btn.clipsToBounds = true
        btn.setTitleColor(Theme.Colors.text, for: .normal)
        btn.contentHorizontalAlignment = .leading
        btn.contentEdgeInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        btn.titleLabel?.font = Theme.Typography.bodyMedium
        btn.titleLabel?.lineBreakMode = .byWordWrapping
        btn.titleLabel?.numberOfLines = 0
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()
    
    init(label: String) {
        super.init(frame: .zero)
        self.label.text = label
        
        addSubview(self.label)
        addSubview(button)
        
        NSLayoutConstraint.activate([
            self.label.topAnchor.constraint(equalTo: topAnchor),
            self.label.leadingAnchor.constraint(equalTo: leadingAnchor),
            self.label.trailingAnchor.constraint(equalTo: trailingAnchor),
            
            button.topAnchor.constraint(equalTo: self.label.bottomAnchor, constant: 6),
            button.leadingAnchor.constraint(equalTo: leadingAnchor),
            button.trailingAnchor.constraint(equalTo: trailingAnchor),
            button.bottomAnchor.constraint(equalTo: bottomAnchor),
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
    }
    
    required init?(coder: NSCoder) { fatalError() }
}
