//
//  PhotoLibraryService.swift
//  MetaX
//
//  Created by Chen Yuhan on 2026/02/03.
//  Copyright © 2026 Chen Yuhan. All rights reserved.
//

import Photos
import UIKit

/// Service for photo library operations
/// @unchecked Sendable: only holds `let imageManager` (PHCachingImageManager is thread-safe).
final class PhotoLibraryService: PhotoLibraryServiceProtocol, @unchecked Sendable {

    // MARK: - Properties

    private let imageManager: PHCachingImageManager

    // MARK: - Initialization

    init() {
        imageManager = PHCachingImageManager()
    }

    // MARK: - Authorization

    func checkAuthorization() async -> Result<Void, MetaXError> {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)

        switch status {
        case .authorized, .limited:
            return .success(())
        case .notDetermined:
            let newStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            if newStatus == .authorized || newStatus == .limited {
                return .success(())
            } else {
                return .failure(.photoLibrary(.accessDenied))
            }
        case .denied, .restricted:
            return .failure(.photoLibrary(.accessDenied))
        @unknown default:
            return .failure(.photoLibrary(.unavailable))
        }
    }

    @MainActor func guideToSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - Fetch Operations

    func fetchAllPhotos(sortedBy sortDescriptor: NSSortDescriptor?) -> PHFetchResult<PHAsset> {
        let options = imageFetchOptions()
        if let sortDescriptor = sortDescriptor {
            options.sortDescriptors = [sortDescriptor]
        }
        return PHAsset.fetchAssets(with: options)
    }

    func fetchAssets(
        in collection: PHAssetCollection,
        sortedBy sortDescriptor: NSSortDescriptor?
    ) -> PHFetchResult<PHAsset> {
        let options = imageFetchOptions()
        if let sortDescriptor = sortDescriptor {
            options.sortDescriptors = [sortDescriptor]
        }
        return PHAsset.fetchAssets(in: collection, options: options)
    }

    func fetchSmartAlbums() -> PHFetchResult<PHAssetCollection> {
        PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .any, options: nil)
    }

    private func imageFetchOptions() -> PHFetchOptions {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        return options
    }

    func fetchUserCollections() -> PHFetchResult<PHCollection> {
        PHCollectionList.fetchTopLevelUserCollections(with: nil)
    }

    // MARK: - Album Management

    func createAlbumIfNeeded(title: String) async -> Result<PHAssetCollection, MetaXError> {
        // Check if album already exists
        if let existingAlbum = findAlbum(title: title) {
            return .success(existingAlbum)
        }

        // Create new album
        do {
            var albumPlaceholder: PHObjectPlaceholder?
            try await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: title)
                albumPlaceholder = request.placeholderForCreatedAssetCollection
            }

            guard let placeholder = albumPlaceholder,
                  let album = PHAssetCollection.fetchAssetCollections(
                      withLocalIdentifiers: [placeholder.localIdentifier],
                      options: nil
                  ).firstObject
            else {
                return .failure(.imageSave(.albumCreationFailed))
            }

            return .success(album)
        } catch {
            return .failure(.imageSave(.albumCreationFailed))
        }
    }

    func albumExists(title: String) -> Bool {
        findAlbum(title: title) != nil
    }

    private func findAlbum(title: String) -> PHAssetCollection? {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "title = %@", title)
        let collection = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)
        return collection.firstObject
    }

    // MARK: - Image Operations

    @discardableResult
    func requestThumbnail(
        for asset: PHAsset,
        targetSize: CGSize,
        completion: @escaping (UIImage?, Bool) -> Void
    ) -> PHImageRequestID {
        return imageManager.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: .standard
        ) { image, info in
            let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
            completion(image, isDegraded)
        }
    }

    func startCachingThumbnails(for assets: [PHAsset], targetSize: CGSize) {
        imageManager.startCachingImages(
            for: assets,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: .standard
        )
    }

    func stopCachingThumbnails(for assets: [PHAsset], targetSize: CGSize) {
        imageManager.stopCachingImages(
            for: assets,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: .standard
        )
    }

    func stopCachingAllThumbnails() {
        imageManager.stopCachingImagesForAllAssets()
    }

    @discardableResult
    func requestLivePhoto(
        for asset: PHAsset,
        targetSize: CGSize,
        completion: @escaping (PHLivePhoto?, Bool) -> Void
    ) -> PHImageRequestID {
        let options = PHLivePhotoRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        return imageManager.requestLivePhoto(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFit,
            options: options
        ) { livePhoto, info in
            let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
            completion(livePhoto, isDegraded)
        }
    }

    func requestThumbnailStream(for asset: PHAsset, targetSize: CGSize) -> AsyncStream<(UIImage?, Bool)> {
        AsyncStream { continuation in
            let requestID = requestThumbnail(for: asset, targetSize: targetSize) { image, isDegraded in
                continuation.yield((image, isDegraded))
                if !isDegraded {
                    continuation.finish()
                }
            }

            continuation.onTermination = { [weak self] _ in
                self?.imageManager.cancelImageRequest(requestID)
            }
        }
    }

    func requestLivePhotoStream(for asset: PHAsset, targetSize: CGSize) -> AsyncStream<(PHLivePhoto?, Bool)> {
        AsyncStream { continuation in
            let requestID = requestLivePhoto(for: asset, targetSize: targetSize) { livePhoto, isDegraded in
                continuation.yield((livePhoto, isDegraded))
                if !isDegraded {
                    continuation.finish()
                }
            }

            continuation.onTermination = { [weak self] _ in
                self?.imageManager.cancelImageRequest(requestID)
            }
        }
    }

    func cancelImageRequest(_ requestID: PHImageRequestID) {
        imageManager.cancelImageRequest(requestID)
    }

    // MARK: - Asset Operations

    func deleteAsset(_ asset: PHAsset) async -> Result<Void, MetaXError> {
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets([asset] as NSFastEnumeration)
            }
            return .success(())
        } catch {
            return .failure(.photoLibrary(.assetFetchFailed(underlying: error)))
        }
    }

    func revertAsset(_ asset: PHAsset) async -> Result<Void, MetaXError> {
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest(for: asset).revertAssetContentToOriginal()
            }
            return .success(())
        } catch {
            return .failure(.imageSave(.editionFailed))
        }
    }

    func updateAssetProperties(_ asset: PHAsset, date: Date?, location: CLLocation?) async -> Result<Void, MetaXError> {
        do {
            try await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetChangeRequest(for: asset)
                if let date = date { request.creationDate = date }
                request.location = location
            }
            return .success(())
        } catch {
            return .failure(.imageSave(.editionFailed))
        }
    }

    // MARK: - Change Observer

    func registerChangeObserver(_ observer: PHPhotoLibraryChangeObserver) {
        PHPhotoLibrary.shared().register(observer)
    }

    func unregisterChangeObserver(_ observer: PHPhotoLibraryChangeObserver) {
        PHPhotoLibrary.shared().unregisterChangeObserver(observer)
    }
}
