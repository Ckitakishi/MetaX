//
//  DetailInfoViewModel.swift
//  MetaX
//
//  Created by Chen Yuhan on 2026/02/03.
//  Copyright © 2026 Chen Yuhan. All rights reserved.
//

import CoreLocation
import Observation
import Photos
import UIKit

enum HeroContent {
    case photo(UIImage)
    case livePhoto(PHLivePhoto)
}

/// ViewModel for DetailInfoViewController
@Observable @MainActor
final class DetailInfoViewModel {

    // MARK: - Properties

    private(set) var heroContent: HeroContent?
    private(set) var metadata: Metadata?
    private(set) var fileName: String = ""
    private(set) var currentLocation: CLLocation?
    private(set) var tableViewDataSource: [(section: MetadataSection, rows: [DetailCellModel])] = []
    private(set) var isLoading: Bool = false
    private(set) var isSaving: Bool = false
    private(set) var error: MetaXError?
    private(set) var hasMetaXEdit: Bool = false

    // MARK: - Computed Properties

    var hasLocation: Bool {
        currentLocation != nil
    }

    var hasTimeStamp: Bool {
        let exif = metadata?.sourceProperties[MetadataKeys.exifDict] as? [String: Any]
        return exif?[MetadataKeys.dateTimeOriginal] != nil
    }

    var timeStamp: String? {
        let exif = metadata?.sourceProperties[MetadataKeys.exifDict] as? [String: Any]
        return exif?[MetadataKeys.dateTimeOriginal] as? String
    }

    var isLivePhoto: Bool {
        asset?.mediaSubtypes.contains(.photoLive) ?? false
    }

    // MARK: - Dependencies

    private let metadataService: MetadataServiceProtocol
    private let imageSaveService: ImageSaveServiceProtocol
    private let photoLibraryService: PhotoLibraryServiceProtocol

    // MARK: - State

    private(set) var asset: PHAsset?
    private(set) var assetCollection: PHAssetCollection?
    private var imageRequestId: PHImageRequestID?
    private var livePhotoRequestId: PHImageRequestID?
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

    func loadPhoto(targetSize: CGSize) {
        guard let asset = asset else { return }

        imageRequestId = photoLibraryService.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFit
        ) { [weak self] image, _ in
            Task { @MainActor in
                if let image { self?.heroContent = .photo(image) }
            }
        }
    }

    func loadLivePhoto(targetSize: CGSize) {
        guard let asset = asset else { return }
        let options = PHLivePhotoRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        livePhotoRequestId = PHImageManager.default().requestLivePhoto(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFit,
            options: options
        ) { [weak self] livePhoto, _ in
            Task { @MainActor in
                if let livePhoto { self?.heroContent = .livePhoto(livePhoto) }
            }
        }
    }

    func loadMetadata() async {
        guard let asset = asset, !isLoading else { return }

        // Validate media type
        guard asset.mediaType == .image else {
            error = .metadata(.unsupportedMediaType)
            return
        }

        isLoading = true

        // Force reload from Photo Library to get the latest edited metadata
        let result = await metadataService.loadMetadata(from: asset)

        isLoading = false

        switch result {
        case let .success(metadata):
            self.metadata = metadata
            updateDisplayData(from: metadata)
            await refreshMetaXEditStatus()
        case let .failure(error):
            self.error = error
        }
    }

    // MARK: - Revert

    func revertToOriginal() async {
        guard let asset else { return }
        isSaving = true
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest(for: asset).revertAssetContentToOriginal()
            }
        } catch {
            self.error = .imageSave(.editionFailed)
        }
        isSaving = false
        await loadMetadata()

        // revertAssetContentToOriginal() restores image content but does NOT undo
        // PHAsset property changes (creationDate, location) made separately.
        // Re-sync from the now-restored metadata so the asset sorts correctly.
        if let metadata {
            await syncAssetProperties(from: metadata.sourceProperties, for: asset)
        }
    }

    private func refreshMetaXEditStatus() async {
        guard let asset else { hasMetaXEdit = false; return }
        hasMetaXEdit = await withCheckedContinuation { continuation in
            let options = PHContentEditingInputRequestOptions()
            options.isNetworkAccessAllowed = false
            // Without this, Photos never fills in adjustmentData on PHContentEditingInput.
            options.canHandleAdjustmentData = { adjustmentData in
                adjustmentData.formatIdentifier == Bundle.main.bundleIdentifier
            }
            asset.requestContentEditingInput(with: options) { input, _ in
                continuation.resume(
                    returning:
                    input?.adjustmentData?.formatIdentifier == Bundle.main.bundleIdentifier
                )
            }
        }
    }

    // MARK: - Edit Methods

    @discardableResult
    func addTimeStamp(_ date: Date, saveMode: SaveWorkflowMode) async -> Bool {
        guard let metadata = metadata else { return false }
        let newProps = metadataService.updateTimestamp(date, in: metadata)
        return await performSaveOperation(properties: newProps, mode: saveMode)
    }

    @discardableResult
    func clearTimeStamp(saveMode: SaveWorkflowMode) async -> Bool {
        guard let metadata = metadata else { return false }
        let newProps = metadataService.removeTimestamp(from: metadata)
        return await performSaveOperation(properties: newProps, mode: saveMode)
    }

    @discardableResult
    func addLocation(_ location: CLLocation, saveMode: SaveWorkflowMode) async -> Bool {
        guard let metadata = metadata else { return false }
        let newProps = metadataService.updateLocation(location, in: metadata)
        return await performSaveOperation(properties: newProps, mode: saveMode)
    }

    @discardableResult
    func clearLocation(saveMode: SaveWorkflowMode) async -> Bool {
        guard let metadata = metadata else { return false }
        let newProps = metadataService.removeLocation(from: metadata)
        return await performSaveOperation(properties: newProps, mode: saveMode)
    }

    @discardableResult
    func clearAllMetadata(saveMode: SaveWorkflowMode) async -> Bool {
        guard let metadata = metadata else { return false }
        let newProps = metadataService.removeAllMetadata(from: metadata)
        return await performSaveOperation(properties: newProps, mode: saveMode)
    }

    @discardableResult
    func applyMetadataFields(_ fields: [MetadataField: Any], saveMode: SaveWorkflowMode) async -> Bool {
        guard let metadata = metadata else { return false }
        let batch = Dictionary(uniqueKeysWithValues: fields.map { ($0.key, $1) })
        let newProps = metadataService.updateMetadata(with: batch, in: metadata)
        return await performSaveOperation(properties: newProps, mode: saveMode)
    }

    // MARK: - Cancel Requests

    func cancelRequests() {
        if let imageRequestId = imageRequestId {
            photoLibraryService.cancelImageRequest(imageRequestId)
        }
        if let livePhotoRequestId = livePhotoRequestId {
            PHImageManager.default().cancelImageRequest(livePhotoRequestId)
        }
        geocodingTask?.cancel()
    }

    func clearError() {
        error = nil
    }

    // MARK: - Private Methods

    @discardableResult
    private func performSaveOperation(properties: [String: Any], mode: SaveWorkflowMode) async -> Bool {
        guard let asset = asset else { return false }

        isSaving = true

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

        isSaving = false

        switch result {
        case let .success(newAsset):
            // PHContentEditingOutput only updates the rendered image file.
            // PHAsset-level properties (creationDate, location) live in Photos' own
            // database and must be synced separately for both save modes.
            await syncAssetProperties(from: properties, for: newAsset)
            self.asset = newAsset

            if let oldAsset = originalToDelete {
                _ = await photoLibraryService.deleteAsset(oldAsset)
            }

        case let .failure(error):
            self.error = error
        }

        if case .success = result {
            await loadMetadata()
            return true
        }
        return false
    }

    /// Syncs PHAsset-level properties (creationDate, location) to match the saved
    /// image metadata. Only triggers a Photos permission dialog if values actually differ.
    private func syncAssetProperties(from properties: [String: Any], for asset: PHAsset) async {
        let exif = properties[MetadataKeys.exifDict] as? [String: Any]
        let gps = properties[MetadataKeys.gpsDict] as? [String: Any]

        // Extract date from saved metadata (nil = was removed or never existed)
        let newDate: Date?
        if let dateStr = exif?[MetadataKeys.dateTimeOriginal] as? String {
            newDate = DateFormatter(with: .yMdHms).getDate(from: dateStr)
        } else {
            newDate = nil
        }

        // Extract location from saved metadata
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

        // Compare with current asset to avoid unnecessary permission dialogs
        let dateChanged: Bool = {
            if let newDate, let current = asset.creationDate {
                return abs(newDate.timeIntervalSince(current)) > 1
            }
            return (newDate == nil) != (asset.creationDate == nil)
        }()

        let locationChanged: Bool = {
            if let newLoc = newLocation, let curLoc = asset.location {
                return abs(newLoc.coordinate.latitude - curLoc.coordinate.latitude) > 0.00001
                    || abs(newLoc.coordinate.longitude - curLoc.coordinate.longitude) > 0.00001
            }
            return (newLocation == nil) != (asset.location == nil)
        }()

        guard dateChanged || locationChanged else { return }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetChangeRequest(for: asset)
                if dateChanged { request.creationDate = newDate }
                if locationChanged { request.location = newLocation }
            }
        } catch {
            print("[MetaX] syncAssetProperties: \(error)")
        }
    }

    private func updateDisplayData(from metadata: Metadata) {
        currentLocation = metadata.rawGPS
        tableViewDataSource = metadata.metaProps.map { section, props in
            (section: section, rows: props.map { DetailCellModel(propValue: $0) })
        }
        if let location = currentLocation {
            reverseGeocodeLocation(location)
        }
    }

    private func reverseGeocodeLocation(_ location: CLLocation) {
        geocodingTask?.cancel()
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
        for (sIdx, entry) in tableViewDataSource.enumerated() {
            guard entry.section == .basicInfo else { continue }

            for (rIdx, model) in entry.rows.enumerated() {
                if model.rawKey == MetadataKeys.location {
                    var newRows = entry.rows
                    newRows[rIdx] = DetailCellModel(prop: model.prop, value: text, rawKey: model.rawKey)
                    tableViewDataSource[sIdx] = (section: entry.section, rows: newRows)
                    return
                }
            }
        }
    }

    func setFileName(_ name: String) {
        fileName = name
    }
}
