//
//  DateCardField.swift
//  MetaX
//
//  Created by Yuhan Chen on 2026/03/28.
//  Copyright © 2026 Yuhan Chen. All rights reserved.
//

import UIKit

/// A date field for batch editing.
/// Displays a compact date picker, optionally gated by a batch-edit toggle.
final class DateCardField: UIView, FieldToggleable {

    var onDateSet: ((Date) -> Void)?
    var onToggleEnabled: ((Bool) -> Void)?

    private let showsToggle: Bool
    private var isFieldEnabled = true
    private var toggleHeader: ToggleHeaderView?

    private let label: UILabel = {
        let l = UILabel()
        l.font = Theme.Typography.footnote
        l.textColor = .secondaryLabel
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let datePicker: UIDatePicker = {
        let picker = UIDatePicker()
        picker.datePickerMode = .dateAndTime
        picker.preferredDatePickerStyle = .compact
        picker.maximumDate = Date()
        picker.translatesAutoresizingMaskIntoConstraints = false
        return picker
    }()

    // MARK: - Initialization

    init(label: String, showsToggle: Bool = false) {
        self.showsToggle = showsToggle
        super.init(frame: .zero)
        self.label.text = label

        let headerAnchor: UIView
        if showsToggle {
            let header = ToggleHeaderView.make(text: label) { [weak self] isEnabled in
                guard let self else { return }
                isFieldEnabled = isEnabled
                applyFieldEnabledState()
                onToggleEnabled?(isEnabled)
            }
            toggleHeader = header
            addSubview(header)
            headerAnchor = header
        } else {
            addSubview(self.label)
            headerAnchor = self.label
        }
        addSubview(datePicker)

        NSLayoutConstraint.activate([
            headerAnchor.topAnchor.constraint(equalTo: topAnchor),
            headerAnchor.leadingAnchor.constraint(equalTo: leadingAnchor),
            headerAnchor.trailingAnchor.constraint(equalTo: trailingAnchor),

            datePicker.topAnchor.constraint(equalTo: headerAnchor.bottomAnchor, constant: 8),
            datePicker.leadingAnchor.constraint(equalTo: leadingAnchor),
            datePicker.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        datePicker.addTarget(self, action: #selector(dateChanged), for: .valueChanged)
        setFieldEnabled(!showsToggle)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError()
    }

    func setDate(_ date: Date) {
        datePicker.date = min(date, Date())
    }

    func setFieldEnabled(_ enabled: Bool) {
        isFieldEnabled = enabled
        toggleHeader?.setEnabled(enabled)
        applyFieldEnabledState()
    }

    // MARK: - Actions

    @objc private func dateChanged() {
        onDateSet?(datePicker.date)
    }

    private func applyFieldEnabledState() {
        datePicker.isUserInteractionEnabled = isFieldEnabled
        let alpha: CGFloat = isFieldEnabled || !showsToggle ? 1.0 : 0.6
        datePicker.alpha = alpha
        label.alpha = isFieldEnabled || !showsToggle ? 1.0 : 0.6
    }
}
