//
//  BatchEditTests.swift
//  MetaXTests
//

import CoreLocation
import Foundation
@testable import MetaX
import Photos
import Testing
import UIKit

@Suite("Batch Edit Tests")
@MainActor
struct BatchEditTests {

    @Test("Batch editor only emits enabled fields")
    func batchEditorEmitsOnlyEnabledFields() {
        let viewModel = BatchMetadataEditViewModel()

        viewModel.setFieldEnabled(true, for: .make)
        viewModel.updateValue(.string("Sony"), for: .make)

        viewModel.setFieldEnabled(true, for: .iso)
        viewModel.updateValue(.string("400"), for: .iso)

        let prepared = viewModel.getPreparedFields()

        #expect(prepared.count == 2)
        #expect(prepared[.make]?.rawValue as? String == "Sony")
        #expect(prepared[.iso]?.rawValue as? [Int] == [400])
        #expect(prepared[.model] == nil)
    }

    @Test("Batch editor treats enabled empty fields as clear operations")
    func batchEditorEmitsNullForEnabledEmptyFields() {
        let viewModel = BatchMetadataEditViewModel()

        viewModel.setFieldEnabled(true, for: .artist)
        viewModel.updateValue(.string(""), for: .artist)

        viewModel.setFieldEnabled(true, for: .location)

        let prepared = viewModel.getPreparedFields()

        #expect(prepared[.artist]?.rawValue is NSNull)
        #expect(prepared[.location]?.rawValue is NSNull)
    }

    @Test("Batch editor clears disabled field values")
    func batchEditorClearsValuesWhenFieldDisabled() {
        let viewModel = BatchMetadataEditViewModel()

        viewModel.setFieldEnabled(true, for: .copyright)
        viewModel.updateValue(.string("MetaX"), for: .copyright)
        #expect(viewModel.hasAnyField == true)

        viewModel.setFieldEnabled(false, for: .copyright)

        #expect(viewModel.hasAnyField == false)
        #expect(viewModel.getPreparedFields()[.copyright] == nil)
    }

    @Test("Enabling a text field without input marks it for clearing")
    func enablingTextFieldWithoutInputCreatesClearDraft() {
        let viewModel = BatchMetadataEditViewModel()

        viewModel.setFieldEnabled(true, for: .artist)

        #expect(viewModel.hasAnyField == true)
        #expect(viewModel.artist == "")
        #expect(viewModel.getPreparedFields()[.artist]?.rawValue is NSNull)
    }

    @Test("Batch editor preserves explicit date and location patches")
    func batchEditorDateAndLocationPatches() {
        let viewModel = BatchMetadataEditViewModel()
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let location = CLLocation(latitude: 35.6895, longitude: 139.6917)

        viewModel.setFieldEnabled(true, for: .dateTimeOriginal)
        viewModel.updateValue(.date(date), for: .dateTimeOriginal)
        viewModel.setFieldEnabled(true, for: .location)
        viewModel.updateValue(.location(location), for: .location)

        let prepared = viewModel.getPreparedFields()

        #expect(prepared[.dateTimeOriginal]?.rawValue as? Date == date)
        let storedLocation = prepared[.location]?.rawValue as? CLLocation
        #expect(storedLocation?.coordinate.latitude == location.coordinate.latitude)
        #expect(storedLocation?.coordinate.longitude == location.coordinate.longitude)
    }

    @Test("Disabling date field resets its draft value")
    func batchEditorClearsDraftDateWhenDateFieldDisabled() {
        let viewModel = BatchMetadataEditViewModel()
        let oldDate = Date(timeIntervalSince1970: 1_700_000_000)

        viewModel.setFieldEnabled(true, for: .dateTimeOriginal)
        viewModel.updateValue(.date(oldDate), for: .dateTimeOriginal)
        #expect(viewModel.getPreparedFields()[.dateTimeOriginal]?.rawValue as? Date == oldDate)

        viewModel.setFieldEnabled(false, for: .dateTimeOriginal)

        #expect(viewModel.getPreparedFields()[.dateTimeOriginal] == nil)
        #expect(viewModel.dateTimeOriginal.timeIntervalSinceNow > -5)
    }

    @Test("Disabled fields ignore incoming value updates")
    func disabledFieldsIgnoreValueUpdates() {
        let viewModel = BatchMetadataEditViewModel()

        viewModel.updateValue(.string("Sony"), for: .make)

        #expect(viewModel.make == nil)
        #expect(viewModel.getPreparedFields().isEmpty)
    }

    @Test("Batch save options disable copy flow")
    func batchSaveOptionsDisableCopyFlow() {
        let viewModel = SaveOptionsViewModel(batchMode: true)
        var selectedMode: SaveWorkflowMode?

        viewModel.onSelect = { selectedMode = $0 }

        #expect(viewModel.currentStep == .initial)
        #expect(viewModel.options.count == 2)
        #expect(viewModel.options[0].isEnabled == true)
        #expect(viewModel.options[1].isEnabled == false)
        #expect(viewModel.options[1].action == nil)

        viewModel.options[0].action?()

        #expect(selectedMode == .updateOriginal)
    }

    @Test("Batch error details format each error on its own line")
    func batchErrorDetailsFormatting() {
        let result = BatchEditViewModel.BatchResult(
            succeeded: 1,
            failed: 2,
            cancelled: false,
            errors: [
                ("a", .metadata(.readFailed)),
                ("b", .imageSave(.editionFailed)),
            ]
        )

        let message = BatchEditPresentation.failureDetailsMessage(for: result)

        #expect(message.contains("1."))
        #expect(message.contains("2."))
        #expect(message.contains("MX-1010"))
        #expect(message.contains("MX-1020"))
    }

    @Test("Batch executor rejects save-as-copy mode")
    func batchExecutorRejectsCopyMode() async {
        let viewModel = BatchEditViewModel(
            metadataService: MockBatchMetadataService(),
            imageSaveService: MockBatchImageSaveService(),
            settingsService: MockBatchSettingsService()
        )
        let fakeAsset = makeFakePHAsset(localIdentifier: "batch-test-asset")

        let result = await viewModel.execute(
            assets: [fakeAsset],
            fields: [.make: .string("Sony")],
            mode: .saveAsCopy(deleteOriginal: false)
        )

        #expect(result.succeeded == 0)
        #expect(result.failed == 1)
        #expect(result.cancelled == false)
    }
}

private func makeFakePHAsset(localIdentifier: String) -> PHAsset {
    // PHAsset cannot be initialized directly in unit tests.
    // Keep the unsafe cast contained to a dedicated helper with the selectors this suite needs.
    unsafeBitCast(TestPHAssetProxy(localIdentifier: localIdentifier), to: PHAsset.self)
}

private final class TestPHAssetProxy: NSObject {
    private let storedIdentifier: String

    init(localIdentifier: String) {
        storedIdentifier = localIdentifier
        super.init()
    }

    @objc var localIdentifier: String {
        storedIdentifier
    }
}

private final class MockBatchMetadataService: MetadataServiceProtocol, @unchecked Sendable {
    func loadMetadataEvents(from asset: PHAsset) -> AsyncStream<MetadataLoadEvent> {
        AsyncStream { continuation in
            continuation.yield(.success(Metadata(props: [:])))
            continuation.finish()
        }
    }

    func updateTimestamp(
        _ date: Date,
        in metadata: Metadata
    ) -> MetadataUpdateIntent { metadata.writeTimeOriginal(date) }
    func removeTimestamp(from metadata: Metadata) -> MetadataUpdateIntent { metadata.deleteTimeOriginal() }
    func updateLocation(
        _ location: CLLocation,
        in metadata: Metadata
    ) -> MetadataUpdateIntent { metadata.writeLocation(location) }
    func removeLocation(from metadata: Metadata) -> MetadataUpdateIntent { metadata.deleteGPS() }
    func removeAllMetadata(from metadata: Metadata) -> MetadataUpdateIntent { metadata.deleteAllExceptOrientation() }
    func updateMetadata(
        with batch: [String: Any],
        in metadata: Metadata
    ) -> MetadataUpdateIntent { metadata.write(batch: batch) }
}

private final class MockBatchImageSaveService: ImageSaveServiceProtocol, @unchecked Sendable {
    func saveImageAsNewAsset(asset: PHAsset, intent: MetadataUpdateIntent) async -> Result<PHAsset, MetaXError> {
        .failure(.unknown(underlying: nil))
    }

    func editAssetMetadata(asset: PHAsset, intent: MetadataUpdateIntent) async -> Result<PHAsset, MetaXError> {
        .failure(.unknown(underlying: nil))
    }

    func applyMetadataIntent(
        _ intent: MetadataUpdateIntent,
        to asset: PHAsset,
        mode: SaveWorkflowMode
    ) async -> Result<PHAsset, MetaXError> {
        .failure(.unknown(underlying: nil))
    }
}

private final class MockBatchSettingsService: SettingsServiceProtocol {
    var userInterfaceStyle: UIUserInterfaceStyle = .unspecified
    var launchCount: Int = 0
    var hasShownTipAlert: Bool = false
    #if DEBUG
        var debugAlwaysShowTipAlert: Bool = false
        var debugBatchProgressMode: DebugBatchProgressMode = .off
        var debugBatchProgressDelay: Double = 0
    #endif
}
