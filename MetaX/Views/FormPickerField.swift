//
//  FormPickerField.swift
//  MetaX
//
//  Created by Yuhan Chen on 2026/02/09.
//  Copyright © 2026 Yuhan Chen. All rights reserved.
//

import UIKit

typealias ExifOption = (rawValue: Int, displayName: String)

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
        (9, String(localized: .exposureProgramBulb))
    ]

    static let meteringMode: [ExifOption] = [
        (0,   String(localized: .meteringModeUnknown)),
        (1,   String(localized: .meteringModeAverage)),
        (2,   String(localized: .meteringModeCenterWeightedAverage)),
        (3,   String(localized: .meteringModeSpot)),
        (4,   String(localized: .meteringModeMultiSpot)),
        (5,   String(localized: .meteringModeMultiSegment)),
        (6,   String(localized: .meteringModePartial)),
        (255, String(localized: .meteringModeOther))
    ]

    static let whiteBalance: [ExifOption] = [
        (0, String(localized: .whiteBalanceAuto)),
        (1, String(localized: .whiteBalanceManual))
    ]

    static let flash: [ExifOption] = [
        (0,  String(localized: .flashNoFlash)),
        (1,  String(localized: .flashFired)),
        (5,  String(localized: .flashFiredReturnNotDetected)),
        (7,  String(localized: .flashFiredReturnDetected)),
        (8,  String(localized: .flashOnDidNotFire)),
        (9,  String(localized: .flashOnFired)),
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
        (95, String(localized: .flashAutoFiredRedEyeReductionReturnDetected))
    ]
}

final class FormPickerField: UIView {
    private(set) var selectedRawValue: Int?
    var onValueChanged: (() -> Void)?

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
        config.cornerStyle = .fixed
        config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
        let btn = UIButton(configuration: config)
        btn.clipsToBounds = true
        btn.contentHorizontalAlignment = .leading
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()

    private let options: [ExifOption]

    init(label labelText: String, options: [ExifOption]) {
        self.options = options
        super.init(frame: .zero)

        label.text = labelText
        button.showsMenuAsPrimaryAction = true
        button.menu = buildMenu()

        addSubview(label)
        addSubview(button)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: topAnchor),
            label.leadingAnchor.constraint(equalTo: leadingAnchor),
            label.trailingAnchor.constraint(equalTo: trailingAnchor),

            button.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 6),
            button.leadingAnchor.constraint(equalTo: leadingAnchor),
            button.trailingAnchor.constraint(equalTo: trailingAnchor),
            button.bottomAnchor.constraint(equalTo: bottomAnchor),
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 50)
        ])

        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: FormPickerField, _: UITraitCollection) in
            var config = self.button.configuration ?? UIButton.Configuration.plain()
            config.background.backgroundColor = Theme.Colors.tagBackground
            config.background.strokeColor = Theme.Colors.border
            self.button.configuration = config
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    func select(rawValue: Int) {
        selectedRawValue = rawValue
        let name = options.first(where: { $0.rawValue == rawValue })?.displayName ?? "\(rawValue)"
        var config = button.configuration ?? UIButton.Configuration.plain()
        var attrs = AttributeContainer()
        attrs.font = Theme.Typography.bodyMedium
        attrs.foregroundColor = Theme.Colors.text
        config.attributedTitle = AttributedString(name, attributes: attrs)
        button.configuration = config
        onValueChanged?()
    }

    private func buildMenu() -> UIMenu {
        let actions = options.map { option in
            UIAction(title: option.displayName) { [weak self] _ in
                self?.select(rawValue: option.rawValue)
            }
        }
        return UIMenu(children: actions)
    }
}
