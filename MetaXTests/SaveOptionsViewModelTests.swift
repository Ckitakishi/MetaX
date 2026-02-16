//
//  SaveOptionsViewModelTests.swift
//  MetaXTests
//

import Foundation
@testable import MetaX
import Testing

@Suite("Save Options State Tests")
@MainActor
struct SaveOptionsViewModelTests {

    @Test("Initial state should show main save options")
    func initialState() {
        let viewModel = SaveOptionsViewModel()

        #expect(viewModel.currentStep == .initial)
        #expect(viewModel.options.count == 2)
        #expect(viewModel.options[0].title == String(localized: .saveModifyOriginal))
        #expect(viewModel.options[1].title == String(localized: .saveAsCopy))
    }

    @Test("Selecting 'Save as Copy' should transition to deletion inquiry")
    func transitionToDeletionInquiry() {
        let viewModel = SaveOptionsViewModel()

        // Simulate tapping "Save as Copy" (the second option)
        viewModel.options[1].action()

        #expect(viewModel.currentStep == .deletionInquiry)
        #expect(viewModel.options.count == 2)
        #expect(viewModel.options[0].title == String(localized: .saveKeepOriginal))
        #expect(viewModel.options[1].title == String(localized: .saveDeleteOriginal))
    }

    @Test("Selecting 'Modify Original' should trigger correct callback")
    func modifyOriginalCallback() {
        let viewModel = SaveOptionsViewModel()
        var selectedMode: SaveWorkflowMode?

        viewModel.onSelect = { selectedMode = $0 }

        // Tap "Modify Original"
        viewModel.options[0].action()

        #expect(selectedMode == .updateOriginal)
    }

    @Test("Selecting deletion options should trigger correct copy mode")
    func copyModeCallbacks() {
        let viewModel = SaveOptionsViewModel()
        var selectedMode: SaveWorkflowMode?
        viewModel.onSelect = { selectedMode = $0 }

        // 1. Go to deletion inquiry
        viewModel.options[1].action()

        // 2. Tap "Keep Original"
        viewModel.options[0].action()
        if case let .saveAsCopy(delete) = selectedMode {
            #expect(delete == false)
        } else {
            Issue.record("Expected saveAsCopy(deleteOriginal: false)")
        }

        // 3. Tap "Delete Original"
        viewModel.options[1].action()
        if case let .saveAsCopy(delete) = selectedMode {
            #expect(delete == true)
        } else {
            Issue.record("Expected saveAsCopy(deleteOriginal: true)")
        }
    }
}
