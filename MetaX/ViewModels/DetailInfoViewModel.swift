//
//  DetailInfoViewModel.swift
//  MetaX
//
//  Created by Chen Yuhan on 2026/02/03.
//  Copyright © 2026 Chen Yuhan. All rights reserved.
//

import UIKit
import Photos
import Observation
import CoreLocation

/// ViewModel for DetailInfoViewController
@Observable @MainActor
final class DetailInfoViewModel {

    // MARK: - Properties

    private(set) var image: UIImage?
    private(set) var metadata: Metadata?
    private(set) var fileName: String = ""
    private(set) var currentLocation: CLLocation?
    private(set) var tableViewDataSource: [(section: MetadataSection, rows: [DetailCellModel])] = []
    private(set) var isLoading: Bool = false
    private(set) var isSaving: Bool = false
    private(set) var error: MetaXError?

    // MARK: - Computed Properties

    var hasLocation: Bool {
        currentLocation != nil
    }

    var hasTimeStamp: Bool {
        let exif = metadata?.sourceProperties["{Exif}"] as? [String: Any]
        return exif?[MetadataKeys.dateTimeOriginal] != nil
    }

    var timeStamp: String? {
        let exif = metadata?.sourceProperties["{Exif}"] as? [String: Any]
        return exif?[MetadataKeys.dateTimeOriginal] as? String
    }

    var isLivePhoto: Bool {
        asset?.mediaSubtypes == .photoLive
    }

    // MARK: - Dependencies

    private let metadataService: MetadataServiceProtocol
    private let imageSaveService: ImageSaveServiceProtocol
    private let photoLibraryService: PhotoLibraryServiceProtocol

    // MARK: - State

    private(set) var asset: PHAsset?
    private(set) var assetCollection: PHAssetCollection?
    private var imageRequestId: PHImageRequestID?
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
        self.assetCollection = collection
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
        ) { [weak self] image, isDegraded in
            Task { @MainActor in
                self?.image = image
            }
        }
    }

    func loadMetadata() async {
        guard let asset = asset, !isLoading else { return }

        // Validate media type
        guard asset.mediaType == .image, asset.mediaSubtypes.rawValue != 32 else {
            self.error = .metadata(.unsupportedMediaType)
            return
        }

        self.isLoading = true

        let result = await metadataService.loadMetadata(from: asset)

        self.isLoading = false

        switch result {
        case .success(let metadata):
            self.metadata = metadata
            self.updateDisplayData(from: metadata)
        case .failure(let error):
            self.error = error
        }
    }

    // MARK: - Edit Methods

    func addTimeStamp(_ date: Date, deleteOriginal: Bool) async {
        guard let metadata = metadata, let asset = asset else { return }

        let newProps = metadataService.updateTimestamp(date, in: metadata)
        let success = await saveImageWithProperties(newProps, deleteOriginal: deleteOriginal)

        if success {
            // Update PHAsset creation date
            try? await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetChangeRequest(for: asset)
                request.creationDate = date
            }
        }
    }

    func clearTimeStamp(deleteOriginal: Bool) async {
        guard let metadata = metadata else { return }

        let newProps = metadataService.removeTimestamp(from: metadata)
        await saveImageWithProperties(newProps, deleteOriginal: deleteOriginal)
    }

    func addLocation(_ location: CLLocation, deleteOriginal: Bool) async {
        guard let metadata = metadata, let asset = asset else { return }

        let newProps = metadataService.updateLocation(location, in: metadata)
        let success = await saveImageWithProperties(newProps, deleteOriginal: deleteOriginal)

        if success {
            // Update PHAsset location
            try? await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetChangeRequest(for: asset)
                request.location = location
            }
        }
    }

    func clearLocation(deleteOriginal: Bool) async {
        guard let metadata = metadata, let asset = asset else { return }

        let newProps = metadataService.removeLocation(from: metadata)
        let success = await saveImageWithProperties(newProps, deleteOriginal: deleteOriginal)

        if success {
            // Clear PHAsset location
            try? await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetChangeRequest(for: asset)
                request.location = nil
            }
        }
    }

    func clearAllMetadata(deleteOriginal: Bool) async {
        guard let metadata = metadata else { return }

        let newProps = metadataService.removeAllMetadata(from: metadata)
        await saveImageWithProperties(newProps, deleteOriginal: deleteOriginal)
    }
    
    func applyMetadataTemplate(fields: [String: Any], deleteOriginal: Bool) async {
        guard let metadata = metadata else { return }
        
        let newProps = metadataService.updateMetadata(with: fields, in: metadata)
        await saveImageWithProperties(newProps, deleteOriginal: deleteOriginal)
    }

    // MARK: - Cancel Requests

    func cancelRequests() {
        if let imageRequestId = imageRequestId {
            photoLibraryService.cancelImageRequest(imageRequestId)
        }
        geocodingTask?.cancel()
    }

    func clearError() {
        error = nil
    }

    // MARK: - Private Methods

    @discardableResult
    private func saveImageWithProperties(_ properties: [String: Any], deleteOriginal: Bool) async -> Bool {
        guard let asset = asset else { return false }

        self.isSaving = true

        let result = await imageSaveService.saveImage(
            asset: asset,
            newProperties: properties,
            deleteOriginal: deleteOriginal
        )

        self.isSaving = false

        switch result {
        case .success(let newAsset):
            self.asset = newAsset
        case .failure(let error):
            self.error = error
        }

        if case .success = result {
            await self.loadMetadata()
            return true
        }
        return false
    }

    private func updateDisplayData(from metadata: Metadata) {
        // Update local state
        self.currentLocation = metadata.rawGPS

        // Build table view data source
        self.tableViewDataSource = metadata.metaProps.map { (section, props) in
            (section: section, rows: props.map { DetailCellModel(propValue: $0) })
        }

        // Reverse geocode location if present
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
        self.fileName = name
    }
}
