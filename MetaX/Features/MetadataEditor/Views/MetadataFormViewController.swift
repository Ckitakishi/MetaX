//
//  MetadataFormViewController.swift
//  MetaX
//
//  Created by Yuhan Chen on 2026/03/29.
//  Copyright © 2026 Yuhan Chen. All rights reserved.
//

import CoreLocation
import UIKit

// MARK: - ViewModel Protocol

@MainActor
protocol MetadataFormEditing: AnyObject {
    func updateValue(_ value: MetadataFieldValue?, for field: MetadataField)
    func validateInput(currentText: String, range: NSRange, replacementString: String, for field: MetadataField) -> Bool
    func getPreparedFields() -> [MetadataField: MetadataFieldValue]
    func reverseGeocode(_ loc: CLLocation)
    var locationAddress: String? { get }
}

// MARK: - Base View Controller

/// Shared base class for single-photo and batch metadata editing.
/// Subclasses provide field setup, sections, bindings, and title/save text.
@MainActor
class MetadataFormViewController: UIViewController, UITextFieldDelegate,
    UIAdaptivePresentationControllerDelegate, ViewModelObserving {

    // MARK: - Callbacks

    var onSave: (([MetadataField: MetadataFieldValue]) -> Void)?
    var onCancel: (() -> Void)?
    var onRequestLocationSearch: (() -> Void)?

    // MARK: - ViewModel

    let formViewModel: any MetadataFormEditing

    init(formViewModel: any MetadataFormEditing) {
        self.formViewModel = formViewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError()
    }

    // MARK: - Field Management

    var fieldViews: [MetadataField: UIView] = [:]
    var textFieldToField: [UITextField: MetadataField] = [:]

    struct FormSection {
        let title: String
        let hint: LocalizedStringResource?
        let fields: [MetadataField]
    }

    // MARK: - UI Components

    let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.alwaysBounceVertical = true
        sv.keyboardDismissMode = .onDrag
        sv.showsVerticalScrollIndicator = false
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 32
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private var keyboardObserver: KeyboardObserver?
    private var saveTask: Task<Void, Never>?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupFormLayout()
        setupAccessoryViews()
        setupDelegates()
        setupBindings()

        keyboardObserver = KeyboardObserver(scrollView: scrollView)
        keyboardObserver?.startObserving()
    }

    // MARK: - Template Methods (subclass overrides)

    /// Called during init to create field views. Subclass must override.
    func setupFields() {}

    /// Called in viewDidLoad to set up ViewModel → UI bindings. Subclass must override.
    func setupBindings() {}

    /// The form title shown in the navigation bar.
    var formTitle: String { "" }

    /// The save button title.
    var saveButtonTitle: String { String(localized: .save) }

    /// The sections to display in the form.
    var formSections: [FormSection] { [] }

    /// Whether the save button starts enabled. Default is false.
    var saveButtonInitiallyEnabled: Bool { false }

    /// Called after form layout is set up, before sections are built.
    /// Subclass can add views to stackView here (e.g. a global hint).
    func additionalFormSetup() {}

    /// Called before dispatching prepared fields to `onSave`.
    /// Subclasses can present confirmation UI and return `false` to abort saving.
    func shouldProceedWithSave(fields: [MetadataField: MetadataFieldValue]) async -> Bool { true }

    // MARK: - Form Layout

    private func setupFormLayout() {
        title = formTitle
        view.backgroundColor = Theme.Colors.mainBackground

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancel)
        )

        let saveButton = UIBarButtonItem(
            title: saveButtonTitle,
            style: .done,
            target: self,
            action: #selector(save)
        )
        saveButton.tintColor = Theme.Colors.accent
        saveButton.isEnabled = saveButtonInitiallyEnabled
        navigationItem.rightBarButtonItem = saveButton

        view.addSubview(scrollView)
        scrollView.addSubview(stackView)

        (fieldViews[.location] as? LocationCardField)?.button.addTarget(
            self,
            action: #selector(searchLocation),
            for: .touchUpInside
        )

        additionalFormSetup()

        for section in formSections {
            var views: [UIView] = []
            if let hint = section.hint {
                views.append(createHint(resource: hint, color: .systemGray))
            }
            for field in section.fields {
                if let view = fieldViews[field] {
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

    // MARK: - Accessory Views

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
        formViewModel.updateValue(tf.text.map(MetadataFieldValue.string), for: .shutter)
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
        formViewModel.updateValue(tf.text.map(MetadataFieldValue.string), for: .exposureBias)
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
        formViewModel.updateValue(tf.text.map(MetadataFieldValue.string), for: .exposureBias)
    }

    // MARK: - Delegates

    private func setupDelegates() {
        for view in fieldViews.values {
            if let tf = view as? FormTextField {
                tf.textField.delegate = self
            }
        }
    }

    // MARK: - UITextFieldDelegate

    @objc func textFieldDidChange(_ textField: UITextField) {
        guard let field = textFieldToField[textField] else { return }
        formViewModel.updateValue(textField.text.map(MetadataFieldValue.string), for: field)
    }

    func textField(
        _ textField: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        guard let field = textFieldToField[textField] else { return true }

        if field == .exposureBias {
            let currentText = textField.text ?? ""
            if currentText.isEmpty,
               let firstScalar = string.unicodeScalars.first,
               CharacterSet.decimalDigits.contains(firstScalar),
               string != "0" {
                let newText = "+" + string
                textField.text = newText
                formViewModel.updateValue(.string(newText), for: field)
                return false
            }
        }

        return formViewModel.validateInput(
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

    // MARK: - Actions

    @objc private func searchLocation() {
        onRequestLocationSearch?()
    }

    @objc private func cancel() {
        onCancel?()
    }

    @objc private func save() {
        guard saveTask == nil else { return }
        let fields = formViewModel.getPreparedFields()
        let wasSaveButtonEnabled = navigationItem.rightBarButtonItem?.isEnabled ?? true
        navigationItem.rightBarButtonItem?.isEnabled = false

        saveTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                saveTask = nil
                navigationItem.rightBarButtonItem?.isEnabled = wasSaveButtonEnabled
            }
            guard await shouldProceedWithSave(fields: fields) else { return }
            onSave?(fields)
        }
    }

    // MARK: - Location Update

    func updateLocation(from model: LocationModel) {
        guard let coord = model.coordinate else { return }
        let location = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        formViewModel.reverseGeocode(location)
    }

    // MARK: - UI Helpers

    func createGroup(title: String, views: [UIView]) -> UIView {
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

    func createHint(resource: LocalizedStringResource, color: UIColor) -> UIView {
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
}

// MARK: - UIAdaptivePresentationControllerDelegate

extension MetadataFormViewController {
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        onCancel?()
    }
}
