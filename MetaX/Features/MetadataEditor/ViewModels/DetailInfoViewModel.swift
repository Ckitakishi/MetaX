//
//  DetailInfoViewModel.swift
//  MetaX
//
//  Created by Chen Yuhan on 2026/02/03.
//  Copyright © 2026 Chen Yuhan. All rights reserved.
//

import CoreLocation
import Observation
import os
import Photos
import UIKit

enum HeroContent {
    case photo(UIImage)
    case livePhoto(PHLivePhoto)
}

struct SaveWarning {
    let title: String
    let message: String
}

/// ViewModel for DetailInfoViewController
@Observable @MainActor
final class DetailInfoViewModel: NSObject {

    enum ViewState: Equatable {
        case loading
        case success
        case failure(MetaXError)

        static func == (lhs: ViewState, rhs: ViewState) -> Bool {
            switch (lhs, rhs) {
            case (.loading, .loading): return true
            case (.success, .success): return true
            case (.failure, .failure): return true
            default: return false
            }
        }
    }

    struct RowModel: Identifiable {
        let id: String // Use raw key as ID
        let type: RowType
        let model: DetailCellModel

        enum RowType {
            case standard
            case location(CLLocation)
        }
    }

    struct SectionModel: Sendable {
        let section: MetadataSection
        var rows: [RowModel]
    }

    struct UIModel {
        var heroContent: HeroContent?
        var fileName: String = ""
        var currentLocation: CLLocation?
        var sections: [SectionModel] = []
    }

    // MARK: - Properties (Consolidated)

    private(set) var state: ViewState = .loading
    private(set) var ui = UIModel()

    private(set) var isSaving: Bool = false
    private(set) var hasMetaXEdit: Bool = false
    private(set) var metadata: Metadata?
    private(set) var isDeleted: Bool = false

    /// iCloud download progress and status
    private(set) var loadingProgress: Double = 0
    private(set) var isDownloadingFromICloud: Bool = false

    /// Separate error for transient actions (save/revert) to avoid wiping content state
    private(set) var actionError: MetaXError?

    // MARK: - Computed Properties (Compatibility Layer)

    var heroContent: HeroContent? { ui.heroContent }
    var fileName: String { ui.fileName }
    var currentLocation: CLLocation? { ui.currentLocation }
    var sections: [SectionModel] { ui.sections }

    var isLoading: Bool { state == .loading }
    var error: MetaXError? {
        if case let .failure(e) = state { return e }
        return actionError
    }

    var isLivePhoto: Bool {
        asset?.mediaSubtypes.contains(.photoLive) ?? false
    }

    func warning(for mode: SaveWorkflowMode) -> SaveWarning? {
        if case .saveAsCopy = mode, isLivePhoto {
            return SaveWarning(
                title: "Live Photo",
                message: String(localized: .alertLivePhotoCopyMessage)
            )
        }
        return nil
    }

    // MARK: - Dependencies

    private let metadataService: MetadataServiceProtocol
    private let imageSaveService: ImageSaveServiceProtocol
    private let photoLibraryService: PhotoLibraryServiceProtocol

    // MARK: - State

    private(set) var asset: PHAsset?
    private(set) var assetCollection: PHAssetCollection?
    private var heroLoadTask: Task<Void, Never>?
    private let geocoder = CLGeocoder()
    private var geocodingTask: Task<Void, Never>?

    // MARK: - Initialization

    init(
        metadataService: MetadataServiceProtocol,
        imageSaveService: ImageSaveServiceProtocol,
        photoLibraryService: PhotoLibraryServiceProtocol
    ) {
        self.metadataService = metadataService
        self.imageSaveService = imageSaveService
        self.photoLibraryService = photoLibraryService
    }

    // MARK: - Configuration

    func configure(with asset: PHAsset, collection: PHAssetCollection?) {
        self.asset = asset
        assetCollection = collection
    }

    func updateAsset(_ asset: PHAsset?) {
        self.asset = asset
    }

    // MARK: - Load Methods

    func loadHeroContent(targetSize: CGSize) {
        guard let asset = asset else { return }

        heroLoadTask?.cancel()
        heroLoadTask = Task { @MainActor in
            if isLivePhoto {
                for await (livePhoto, _) in photoLibraryService.requestLivePhotoStream(
                    for: asset,
                    targetSize: targetSize
                ) {
                    guard !Task.isCancelled else { break }
                    if let livePhoto { self.ui.heroContent = .livePhoto(livePhoto) }
                }
            } else {
                for await (image, _) in photoLibraryService.requestThumbnailStream(for: asset, targetSize: targetSize) {
                    guard !Task.isCancelled else { break }
                    if let image { self.ui.heroContent = .photo(image) }
                }
            }
        }
    }

    func loadMetadata() async {
        guard let asset = asset else { return }

        // Validate media type
        guard asset.mediaType == .image else {
            state = .failure(.metadata(.unsupportedMediaType))
            return
        }

        state = .loading
        isDownloadingFromICloud = false
        loadingProgress = 0

        // Use event-based loading to track progress and handle potential multiple callbacks safely.
        for await event in metadataService.loadMetadataEvents(from: asset) {
            switch event {
            case let .progress(progress):
                isDownloadingFromICloud = true
                loadingProgress = progress
            case let .success(metadata):
                isDownloadingFromICloud = false
                self.metadata = metadata
                updateDisplayData(from: metadata)
                state = .success
                await refreshMetaXEditStatus()
            case let .failure(error):
                isDownloadingFromICloud = false
                state = .failure(error)
            }
        }
    }

    // MARK: - Revert

    func revertToOriginal() async {
        guard let asset else { return }
        isSaving = true
        defer { isSaving = false }

        let result = await photoLibraryService.revertAsset(asset)
        switch result {
        case .success:
            await loadMetadata()
            if let metadata {
                await syncAssetProperties(from: metadata.sourceProperties, for: asset)
            }
        case let .failure(error):
            actionError = error
        }
    }

    private func refreshMetaXEditStatus() async {
        guard let asset else { hasMetaXEdit = false; return }
        hasMetaXEdit = await Self.fetchMetaXEditStatus(for: asset)
    }

    private nonisolated static func fetchMetaXEditStatus(for asset: PHAsset) async -> Bool {
        let options = PHContentEditingInputRequestOptions()
        options.isNetworkAccessAllowed = false
        options.canHandleAdjustmentData = { adjustmentData in
            adjustmentData.formatIdentifier == Bundle.main.bundleIdentifier
        }

        do {
            let input = try await asset.fetchContentEditingInput(with: options)
            return input.adjustmentData?.formatIdentifier == Bundle.main.bundleIdentifier
        } catch {
            return false
        }
    }

    // MARK: - Edit Methods

    @discardableResult
    func clearAllMetadata(
        saveMode: SaveWorkflowMode,
        confirm: ((SaveWarning) async -> Bool)? = nil
    ) async -> Bool {
        if hasMetaXEdit, case .updateOriginal = saveMode, asset != nil {
            isSaving = true
            let revertResult = await photoLibraryService.revertAsset(asset!)
            if case let .failure(error) = revertResult {
                isSaving = false
                actionError = error
                return false
            }
        }

        guard let metadata = metadata else { return false }
        let newProps = metadataService.removeAllMetadata(from: metadata)
        return await performSaveOperation(properties: newProps, mode: saveMode, confirm: confirm)
    }

    @discardableResult
    func applyMetadataFields(
        _ fields: [MetadataField: MetadataFieldValue],
        saveMode: SaveWorkflowMode,
        confirm: ((SaveWarning) async -> Bool)? = nil
    ) async -> Bool {
        guard let metadata = metadata else { return false }
        let batch = Dictionary(uniqueKeysWithValues: fields.map { ($0.key.key, $0.value.rawValue) })
        let newProps = metadataService.updateMetadata(with: batch, in: metadata)
        return await performSaveOperation(properties: newProps, mode: saveMode, confirm: confirm)
    }

    // MARK: - Cancel Requests

    func cancelRequests() {
        heroLoadTask?.cancel()
        heroLoadTask = nil
        geocodingTask?.cancel()
    }

    func clearError() {
        if case .failure = state {
            state = .success
        }
        actionError = nil
    }

    // MARK: - Private Methods

    @discardableResult
    private func performSaveOperation(
        properties: [String: Any],
        mode: SaveWorkflowMode,
        confirm: ((SaveWarning) async -> Bool)? = nil
    ) async -> Bool {
        if let warning = warning(for: mode), let confirm = confirm {
            guard await confirm(warning) else { return false }
        }

        guard let asset = asset else { return false }

        isSaving = true
        defer { isSaving = false }

        let result: Result<PHAsset, MetaXError>
        let originalToDelete: PHAsset?

        switch mode {
        case .updateOriginal:
            result = await imageSaveService.editAssetMetadata(asset: asset, newProperties: properties)
            originalToDelete = nil
        case let .saveAsCopy(deleteOriginal):
            result = await imageSaveService.saveImageAsNewAsset(asset: asset, newProperties: properties)
            originalToDelete = deleteOriginal ? asset : nil
        }

        switch result {
        case let .success(newAsset):
            await syncAssetProperties(from: properties, for: newAsset)
            self.asset = newAsset

            if let oldAsset = originalToDelete {
                _ = await photoLibraryService.deleteAsset(oldAsset)
            }

        case let .failure(error):
            actionError = error
        }

        if case .success = result {
            await loadMetadata()
            return true
        }

        return false
    }

    /// Compares new metadata values with current PHAsset properties to decide if sync is needed.
    /// Internal for unit testing without Mock PHAsset.
    func calculateSyncNeeds(
        newDate: Date?,
        currentDate: Date?,
        newLocation: CLLocation?,
        currentLocation: CLLocation?
    ) -> (dateChanged: Bool, locationChanged: Bool) {
        let dateChanged: Bool = {
            if let newDate, let current = currentDate {
                return abs(newDate.timeIntervalSince(current)) > 1
            }
            return (newDate == nil) != (currentDate == nil)
        }()

        let locationChanged: Bool = {
            if let newLoc = newLocation, let curLoc = currentLocation {
                // Use coordinate comparison for stability in tests
                return abs(newLoc.coordinate.latitude - curLoc.coordinate.latitude) > 0.00001
                    || abs(newLoc.coordinate.longitude - curLoc.coordinate.longitude) > 0.00001
            }
            return (newLocation == nil) != (currentLocation == nil)
        }()

        return (dateChanged, locationChanged)
    }

    private func syncAssetProperties(from properties: [String: Any], for asset: PHAsset) async {
        let exif = properties[MetadataKeys.exifDict] as? [String: Any]
        let gps = properties[MetadataKeys.gpsDict] as? [String: Any]

        let newDate: Date?
        if let dateStr = exif?[MetadataKeys.dateTimeOriginal] as? String {
            newDate = DateFormatter.yMdHms.date(from: dateStr)
        } else {
            newDate = asset.creationDate
        }

        let newLocation: CLLocation?
        if let gps,
           let lat = gps[MetadataKeys.gpsLatitude] as? Double,
           let latRef = gps[MetadataKeys.gpsLatitudeRef] as? String,
           let lon = gps[MetadataKeys.gpsLongitude] as? Double,
           let lonRef = gps[MetadataKeys.gpsLongitudeRef] as? String {
            newLocation = CLLocation(
                latitude: latRef == "N" ? lat : -lat,
                longitude: lonRef == "E" ? lon : -lon
            )
        } else {
            newLocation = nil
        }

        let needs = calculateSyncNeeds(
            newDate: newDate,
            currentDate: asset.creationDate,
            newLocation: newLocation,
            currentLocation: asset.location
        )

        guard needs.dateChanged || needs.locationChanged else { return }

        _ = await photoLibraryService.updateAssetProperties(
            asset,
            date: needs.dateChanged ? newDate : nil,
            location: needs.locationChanged ? newLocation : asset.location
        )
    }

    private func updateDisplayData(from metadata: Metadata) {
        ui.currentLocation = metadata.rawGPS
        ui.sections = metadata.metaProps.map { section, props in
            SectionModel(
                section: section,
                rows: props.map { propDict in
                    let cellModel = DetailCellModel(propValue: propDict)
                    let type: RowModel
                        .RowType = (cellModel.rawKey == MetadataKeys.location && ui.currentLocation != nil)
                        ? .location(ui.currentLocation!)
                        : .standard
                    return RowModel(id: cellModel.rawKey, type: type, model: cellModel)
                }
            )
        }

        if let location = ui.currentLocation {
            reverseGeocodeLocation(location)
        }
    }

    private func reverseGeocodeLocation(_ location: CLLocation) {
        geocodingTask?.cancel()
        geocoder.cancelGeocode() // Cancel the underlying CLGeocoder request, not just the Swift Task
        geocodingTask = Task {
            guard let placemarks = try? await geocoder.reverseGeocodeLocation(location),
                  !Task.isCancelled,
                  let placemark = placemarks.first else { return }

            let infos = [placemark.thoroughfare, placemark.locality, placemark.administrativeArea, placemark.country]
            let displayText = infos.compactMap { $0 }.joined(separator: ", ")
            if displayText.isEmpty { return }

            updateLocationTextInDataSource(displayText)
        }
    }

    private func updateLocationTextInDataSource(_ text: String) {
        for sIdx in ui.sections.indices {
            guard ui.sections[sIdx].section == .basicInfo else { continue }

            for rIdx in ui.sections[sIdx].rows.indices {
                let row = ui.sections[sIdx].rows[rIdx]
                if row.id == MetadataKeys.location {
                    let newModel = DetailCellModel(prop: row.model.prop, value: text, rawKey: row.model.rawKey)
                    ui.sections[sIdx].rows[rIdx] = RowModel(id: row.id, type: row.type, model: newModel)
                    return
                }
            }
        }
    }

    func setFileName(_ name: String) {
        ui.fileName = name
    }

    // MARK: - Photo Library Observer

    func registerPhotoLibraryObserver() {
        photoLibraryService.registerChangeObserver(self)
    }

    func unregisterPhotoLibraryObserver() {
        photoLibraryService.unregisterChangeObserver(self)
    }
}

// MARK: - PHPhotoLibraryChangeObserver

extension DetailInfoViewModel: PHPhotoLibraryChangeObserver {
    nonisolated func photoLibraryDidChange(_ changeInstance: PHChange) {
        Task { @MainActor in
            guard let curAsset = self.asset,
                  let details = changeInstance.changeDetails(for: curAsset) else { return }

            let newAsset = details.objectAfterChanges
            self.updateAsset(newAsset)

            if details.objectWasDeleted || self.asset == nil {
                self.isDeleted = true
                return
            }

            if details.assetContentChanged {
                await self.loadMetadata()
            }
        }
    }
}
