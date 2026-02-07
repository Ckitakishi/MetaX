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
final class PhotoLibraryService: PhotoLibraryServiceProtocol {

    // MARK: - Properties

    private let imageManager: PHCachingImageManager

    // MARK: - Initialization

    init() {
        self.imageManager = PHCachingImageManager()
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

    func guideToSettings() {
        DispatchQueue.main.async {
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }

    // MARK: - Fetch Operations

    func fetchAllPhotos(sortedBy sortDescriptor: NSSortDescriptor?) -> PHFetchResult<PHAsset> {
        let options = PHFetchOptions()
        if let sortDescriptor = sortDescriptor {
            options.sortDescriptors = [sortDescriptor]
        } else {
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        }
        return PHAsset.fetchAssets(with: options)
    }

    func fetchAssets(in collection: PHAssetCollection, sortedBy sortDescriptor: NSSortDescriptor?) -> PHFetchResult<PHAsset> {
        let options: PHFetchOptions?
        if let sortDescriptor = sortDescriptor {
            let fetchOptions = PHFetchOptions()
            fetchOptions.sortDescriptors = [sortDescriptor]
            options = fetchOptions
        } else {
            options = nil
        }
        return PHAsset.fetchAssets(in: collection, options: options)
    }

    func fetchSmartAlbums() -> PHFetchResult<PHAssetCollection> {
        PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .albumRegular, options: nil)
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
                  ).firstObject else {
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

    func requestImage(
        for asset: PHAsset,
        targetSize: CGSize,
        contentMode: PHImageContentMode,
        options: PHImageRequestOptions?
    ) async -> Result<UIImage, MetaXError> {
        await withCheckedContinuation { continuation in
            let requestOptions = options ?? {
                let opts = PHImageRequestOptions()
                opts.deliveryMode = .opportunistic
                opts.isNetworkAccessAllowed = true
                return opts
            }()

            imageManager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: contentMode,
                options: requestOptions
            ) { image, info in
                // Check if this is the final result (not a degraded thumbnail)
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if isDegraded {
                    return // Wait for full quality image
                }

                if let image = image {
                    continuation.resume(returning: .success(image))
                } else {
                    continuation.resume(returning: .failure(.photoLibrary(.assetFetchFailed(underlying: nil))))
                }
            }
        }
    }

    func requestThumbnail(for asset: PHAsset, targetSize: CGSize) -> UIImage? {
        var resultImage: UIImage?

        let options = PHImageRequestOptions()
        options.deliveryMode = .fastFormat
        options.isSynchronous = true
        options.isNetworkAccessAllowed = false

        imageManager.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            resultImage = image
        }

        return resultImage
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

    // MARK: - Change Observer

    func registerChangeObserver(_ observer: PHPhotoLibraryChangeObserver) {
        PHPhotoLibrary.shared().register(observer)
    }

    func unregisterChangeObserver(_ observer: PHPhotoLibraryChangeObserver) {
        PHPhotoLibrary.shared().unregisterChangeObserver(observer)
    }
}
