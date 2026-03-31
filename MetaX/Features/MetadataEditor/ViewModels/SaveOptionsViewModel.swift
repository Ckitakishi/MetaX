//
//  SaveOptionsViewModel.swift
//  MetaX
//
//  Created by Yuhan Chen on 2026/02/16.
//

import Observation
import UIKit

@Observable @MainActor
final class SaveOptionsViewModel {

    // MARK: - Nested Types

    enum Step: Sendable {
        case initial
        case deletionInquiry
    }

    struct Option: Sendable {
        let title: String
        let description: String
        let icon: String
        let color: UIColor
        let isEnabled: Bool
        let action: (@MainActor @Sendable () -> Void)?

        init(
            title: String,
            description: String,
            icon: String,
            color: UIColor,
            isEnabled: Bool = true,
            action: (@MainActor @Sendable () -> Void)? = nil
        ) {
            self.title = title
            self.description = description
            self.icon = icon
            self.color = color
            self.isEnabled = isEnabled
            self.action = isEnabled ? action : nil
        }
    }

    // MARK: - Properties

    private(set) var currentStep: Step = .initial
    private(set) var options: [Option] = []

    var onSelect: ((SaveWorkflowMode) -> Void)?

    // MARK: - Initialization

    init(batchMode: Bool = false) {
        if batchMode {
            showBatchStep()
        } else {
            showInitialStep()
        }
    }

    // MARK: - Public Methods

    func showInitialStep() {
        currentStep = .initial
        options = [
            Option(
                title: String(localized: .saveModifyOriginal),
                description: String(localized: .saveModifyOriginalDesc),
                icon: "pencil",
                color: Theme.Colors.accent
            ) { [weak self] in
                self?.onSelect?(.updateOriginal)
            },
            Option(
                title: String(localized: .saveAsCopy),
                description: String(localized: .saveAsCopyDesc),
                icon: "photo.badge.plus",
                color: Theme.Colors.accent
            ) { [weak self] in
                self?.showDeletionInquiry()
            },
        ]
    }

    // MARK: - Private Methods

    private func showBatchStep() {
        currentStep = .initial
        options = [
            Option(
                title: String(localized: .saveModifyOriginal),
                description: String(localized: .saveModifyOriginalDesc),
                icon: "pencil",
                color: Theme.Colors.accent
            ) { [weak self] in
                self?.onSelect?(.updateOriginal)
            },
            Option(
                title: String(localized: .saveAsCopy),
                description: String(localized: .saveBatchCopyUnavailable),
                icon: "photo.badge.plus",
                color: Theme.Colors.accent,
                isEnabled: false
            ),
        ]
    }

    private func showDeletionInquiry() {
        currentStep = .deletionInquiry
        options = [
            Option(
                title: String(localized: .saveKeepOriginal),
                description: String(localized: .saveKeepOriginalDesc),
                icon: "doc.on.doc",
                color: Theme.Colors.accent
            ) { [weak self] in
                self?.onSelect?(.saveAsCopy(deleteOriginal: false))
            },
            Option(
                title: String(localized: .saveDeleteOriginal),
                description: String(localized: .saveDeleteOriginalDesc),
                icon: "trash",
                color: .systemRed
            ) { [weak self] in
                self?.onSelect?(.saveAsCopy(deleteOriginal: true))
            },
        ]
    }
}
