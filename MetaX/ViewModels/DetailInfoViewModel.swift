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
    private(set) var tableViewDataSource: [[String: [DetailCellModel]]] = []
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

        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = true

        imageRequestId = PHImageManager.default().requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFit,
            options: options
        ) { [weak self] image, _ in
            guard let self = self, let image = image else { return }
            // Ensure UI updates happen on the MainActor
            Task { @MainActor in
                self.image = image
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
                request.location = CLLocation(latitude: 0, longitude: 0)
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
            PHImageManager.default().cancelImageRequest(imageRequestId)
        }
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
        var dataSource: [[String: [DetailCellModel]]] = []
        for doc in metadata.metaProps {
            for (key, value) in doc {
                let sectionTitle = key // e.g., "BASIC INFO"
                dataSource.append([sectionTitle: value.map { DetailCellModel(propValue: $0) }])
            }
        }
        self.tableViewDataSource = dataSource

        // Reverse geocode location if present
        if let location = currentLocation {
            reverseGeocodeLocation(location)
        }
    }

    private func reverseGeocodeLocation(_ location: CLLocation) {
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            guard let self = self, let placemark = placemarks?.first else { return }

            let infos = [placemark.thoroughfare, placemark.locality, placemark.administrativeArea, placemark.country]
            let displayText = infos.compactMap { $0 }.joined(separator: ", ")
            if displayText.isEmpty { return }

            Task { @MainActor in
                self.updateLocationTextInDataSource(displayText)
            }
        }
    }
    
    private func updateLocationTextInDataSource(_ text: String) {
        for (sIdx, section) in tableViewDataSource.enumerated() {
            guard let title = section.keys.first, title == MetadataKeys.basicInfoGroup,
                  let models = section.values.first else { continue }
            
            for (rIdx, model) in models.enumerated() {
                if model.prop == String(localized: .viewAddLocation) {
                    var newModels = models
                    newModels[rIdx] = DetailCellModel(prop: model.prop, value: text)
                    tableViewDataSource[sIdx][title] = newModels
                    return
                }
            }
        }
    }

    func setFileName(_ name: String) {
        self.fileName = name
    }
}
