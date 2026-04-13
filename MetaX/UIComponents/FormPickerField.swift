//
//  FormPickerField.swift
//  MetaX
//
//  Created by Yuhan Chen on 2026/02/09.
//  Copyright © 2026 Yuhan Chen. All rights reserved.
//

import UIKit

typealias ExifOption = (rawValue: Int, displayName: String)

/// Predefined options for EXIF metadata pickers.
enum ExifPickerOptions {
    static let exposureProgram: [ExifOption] = [
        (0, String(localized: .exposureProgramNotDefined)),
        (1, String(localized: .exposureProgramManual)),
        (2, String(localized: .exposureProgramProgramAe)),
        (3, String(localized: .exposureProgramAperturePriorityAe)),
        (4, String(localized: .exposureProgramShutterSpeedPriorityAe)),
        (5, String(localized: .exposureProgramCreative)),
        (6, String(localized: .exposureProgramAction)),
        (7, String(localized: .exposureProgramPortrait)),
        (8, String(localized: .exposureProgramLandscape)),
        (9, String(localized: .exposureProgramBulb)),
    ]

    static let meteringMode: [ExifOption] = [
        (0, String(localized: .meteringModeUnknown)),
        (1, String(localized: .meteringModeAverage)),
        (2, String(localized: .meteringModeCenterWeightedAverage)),
        (3, String(localized: .meteringModeSpot)),
        (4, String(localized: .meteringModeMultiSpot)),
        (5, String(localized: .meteringModeMultiSegment)),
        (6, String(localized: .meteringModePartial)),
        (255, String(localized: .meteringModeOther)),
    ]

    static let whiteBalance: [ExifOption] = [
        (0, String(localized: .whiteBalanceAuto)),
        (1, String(localized: .whiteBalanceManual)),
    ]

    static let flash: [ExifOption] = [
        (0, String(localized: .flashNoFlash)),
        (1, String(localized: .flashFired)),
        (5, String(localized: .flashFiredReturnNotDetected)),
        (7, String(localized: .flashFiredReturnDetected)),
        (8, String(localized: .flashOnDidNotFire)),
        (9, String(localized: .flashOnFired)),
        (13, String(localized: .flashOnReturnNotDetected)),
        (15, String(localized: .flashOnReturnDetected)),
        (16, String(localized: .flashOffDidNotFire)),
        (20, String(localized: .flashOffDidNotFireReturnNotDetected)),
        (24, String(localized: .flashAutoDidNotFire)),
        (25, String(localized: .flashAutoFired)),
        (29, String(localized: .flashAutoFiredReturnNotDetected)),
        (31, String(localized: .flashAutoFiredReturnDetected)),
        (32, String(localized: .flashNoFlashFunction)),
        (48, String(localized: .flashOffNoFlashFunction)),
        (65, String(localized: .flashFiredRedEyeReduction)),
        (69, String(localized: .flashFiredRedEyeReductionReturnNotDetected)),
        (71, String(localized: .flashFiredRedEyeReductionReturnDetected)),
        (73, String(localized: .flashOnRedEyeReduction)),
        (77, String(localized: .flashOnRedEyeReductionReturnNotDetected)),
        (79, String(localized: .flashOnRedEyeReductionReturnDetected)),
        (80, String(localized: .flashOffRedEyeReduction)),
        (88, String(localized: .flashAutoDidNotFireRedEyeReduction)),
        (89, String(localized: .flashAutoFiredRedEyeReduction)),
        (93, String(localized: .flashAutoFiredRedEyeReductionReturnNotDetected)),
        (95, String(localized: .flashAutoFiredRedEyeReductionReturnDetected)),
    ]
}

/// A custom form field that displays a title and a button which opens a picker menu.
final class FormPickerField: UIView, FieldToggleable {

    // MARK: - Properties

    private(set) var selectedRawValue: Int?
    var onValueChanged: (() -> Void)?
    var onToggleEnabled: ((Bool) -> Void)?
    private let options: [ExifOption]
    private let placeholderTitle: String?
    private let showsToggle: Bool
    private var isFieldEnabled = true
    private var toggleHeader: ToggleHeaderView?

    // MARK: - UI Components

    private let label: UILabel = {
        let l = UILabel()
        l.font = Theme.Typography.footnote
        l.textColor = .secondaryLabel
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let button: UIButton = {
        var config = UIButton.Configuration.plain()
        config.background.backgroundColor = Theme.Colors.tagBackground
        config.background.strokeColor = Theme.Colors.border
        config.background.strokeWidth = 1.0
        config.background.cornerRadius = 0
        config.cornerStyle = .fixed
        config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
        let btn = UIButton(configuration: config)
        btn.clipsToBounds = true
        btn.contentHorizontalAlignment = .leading
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()

    // MARK: - Initialization

    init(label labelText: String, options: [ExifOption], placeholderTitle: String? = nil, showsToggle: Bool = false) {
        self.options = options
        self.placeholderTitle = placeholderTitle
        self.showsToggle = showsToggle
        super.init(frame: .zero)

        label.text = labelText
        button.showsMenuAsPrimaryAction = true
        button.menu = buildMenu()
        applyPlaceholder()
        setFieldEnabled(!showsToggle)

        let headerAnchor: UIView
        if showsToggle {
            let header = ToggleHeaderView.make(text: labelText) { [weak self] isEnabled in
                guard let self else { return }
                isFieldEnabled = isEnabled
                applyFieldEnabledState()
                onToggleEnabled?(isEnabled)
            }
            toggleHeader = header
            addSubview(header)
            headerAnchor = header
        } else {
            addSubview(label)
            headerAnchor = label
        }
        addSubview(button)

        NSLayoutConstraint.activate([
            headerAnchor.topAnchor.constraint(equalTo: topAnchor),
            headerAnchor.leadingAnchor.constraint(equalTo: leadingAnchor),
            headerAnchor.trailingAnchor.constraint(equalTo: trailingAnchor),

            button.topAnchor.constraint(equalTo: headerAnchor.bottomAnchor, constant: 6),
            button.leadingAnchor.constraint(equalTo: leadingAnchor),
            button.trailingAnchor.constraint(equalTo: trailingAnchor),
            button.bottomAnchor.constraint(equalTo: bottomAnchor),
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 50),
        ])

        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: FormPickerField, _) in
            var config = self.button.configuration ?? .plain()
            config.background.backgroundColor = Theme.Colors.tagBackground
            config.background.strokeColor = Theme.Colors.border
            self.button.configuration = config
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError()
    }

    // MARK: - Public Methods

    func setSelection(rawValue: Int) {
        selectedRawValue = rawValue
        let name = options.first(where: { $0.rawValue == rawValue })?.displayName ?? "\(rawValue)"

        var config = button.configuration ?? .plain()
        var attrs = AttributeContainer()
        attrs.font = Theme.Typography.bodyMedium
        attrs.foregroundColor = Theme.Colors.text
        config.attributedTitle = AttributedString(name, attributes: attrs)
        button.configuration = config

    }

    func setSelection(rawValue: Int?, placeholderTitle: String? = nil) {
        if let rawValue {
            setSelection(rawValue: rawValue)
        } else {
            selectedRawValue = nil
            applyPlaceholder(titleOverride: placeholderTitle)
        }
    }

    func setLabelHidden(_ hidden: Bool) {
        label.isHidden = hidden
    }

    func setInteractionEnabled(_ enabled: Bool) {
        button.isUserInteractionEnabled = enabled
        button.alpha = enabled ? 1.0 : 0.7
    }

    func setPlaceholderTitle(_ title: String) {
        applyPlaceholder(titleOverride: title)
    }

    func setFieldEnabled(_ enabled: Bool) {
        isFieldEnabled = enabled
        toggleHeader?.setEnabled(enabled)
        applyFieldEnabledState()
    }

    // MARK: - Private Methods

    private func applyFieldEnabledState() {
        button.isUserInteractionEnabled = isFieldEnabled
        button.alpha = isFieldEnabled || !showsToggle ? 1.0 : 0.6
        label.alpha = isFieldEnabled || !showsToggle ? 1.0 : 0.6
    }

    private func buildMenu() -> UIMenu {
        let actions = options.map { option in
            UIAction(title: option.displayName) { [weak self] _ in
                self?.setSelection(rawValue: option.rawValue)
                self?.onValueChanged?()
            }
        }
        return UIMenu(children: actions)
    }

    private func applyPlaceholder(titleOverride: String? = nil) {
        guard let title = titleOverride ?? placeholderTitle else { return }
        var config = button.configuration ?? .plain()
        var attrs = AttributeContainer()
        attrs.font = Theme.Typography.bodyMedium
        attrs.foregroundColor = .secondaryLabel
        config.attributedTitle = AttributedString(title, attributes: attrs)
        button.configuration = config
    }
}
