//
//  PhotoLibraryServiceProtocol.swift
//  MetaX
//
//  Created by Chen Yuhan on 2026/02/03.
//  Copyright © 2026 Chen Yuhan. All rights reserved.
//

import Photos
import UIKit

/// Available sort orders for fetching photos from the library.
enum PhotoSortOrder: Int, CaseIterable, Sendable {
    case creationDate
    case addedDate

    var title: String {
        switch self {
        case .creationDate: return String(localized: .sortCreationDate)
        case .addedDate: return String(localized: .sortRecentlyAdded)
        }
    }

    /// The PHAsset property key used for sorting.
    var sortKey: String {
        switch self {
        case .creationDate: return "creationDate"
        case .addedDate: return "addedDate"
        }
    }
}

/// Defines the capabilities for interacting with the system Photo Library.
protocol PhotoLibraryServiceProtocol: Sendable {
    // MARK: - Authorization

    /// Checks the current photo library authorization status and requests access if it is not yet determined.
    func checkAuthorization() async -> Result<Void, MetaXError>

    /// Opens the iOS Settings app to allow the user to manually grant photo library permissions.
    @MainActor func guideToSettings()

    // MARK: - Fetch Operations

    /// Fetches all photos from the library using the specified sort order.
    func fetchAllPhotos(sortedBy sortOrder: PhotoSortOrder) -> PHFetchResult<PHAsset>

    /// Fetches all assets within a specific collection (e.g., an album).
    func fetchAssets(in collection: PHAssetCollection, sortedBy sortOrder: PhotoSortOrder)
        -> PHFetchResult<PHAsset>

    /// Fetches system smart albums (e.g., Favorites, Recents, Selfies).
    func fetchSmartAlbums() -> PHFetchResult<PHAssetCollection>

    /// Fetches top-level user-created albums and folders.
    func fetchUserCollections() -> PHFetchResult<PHCollection>

    // MARK: - Album Management

    /// Creates a new user album with the given title, or returns the existing one if it already exists.
    func createAlbumIfNeeded(title: String) async -> Result<PHAssetCollection, MetaXError>

    /// Returns true if a user-created album with the specified title exists.
    func albumExists(title: String) -> Bool

    // MARK: - Image Operations

    /// Cancels an in-flight image or live photo request.
    func cancelImageRequest(_ requestID: PHImageRequestID)

    /// Requests a thumbnail for the specified asset. The completion might fire multiple times:
    /// once with a low-quality placeholder and again with the high-quality image.
    @discardableResult
    func requestThumbnail(
        for asset: PHAsset,
        targetSize: CGSize,
        completion: @escaping (UIImage?, Bool) -> Void
    ) -> PHImageRequestID

    /// Requests a thumbnail as a stream of images, starting with a placeholder if available.
    func requestThumbnailStream(for asset: PHAsset, targetSize: CGSize) -> AsyncStream<(UIImage?, Bool)>

    /// Requests a Live Photo as a stream, providing updates as the high-quality version loads.
    func requestLivePhotoStream(for asset: PHAsset, targetSize: CGSize) -> AsyncStream<(PHLivePhoto?, Bool)>

    // MARK: - Thumbnail Caching

    /// Starts pre-caching thumbnails for the provided assets to improve scrolling performance.
    func startCachingThumbnails(for assets: [PHAsset], targetSize: CGSize)

    /// Stops pre-caching thumbnails for the specified assets.
    func stopCachingThumbnails(for assets: [PHAsset], targetSize: CGSize)

    /// Clears all cached thumbnails currently managed by the service.
    func stopCachingAllThumbnails()

    // MARK: - Asset Operations

    /// Deletes the specified asset from the photo library after user confirmation.
    func deleteAsset(_ asset: PHAsset) async -> Result<Void, MetaXError>

    /// Reverts all edits made to an asset, restoring it to its original state.
    func revertAsset(_ asset: PHAsset) async -> Result<Void, MetaXError>

    /// Updates the metadata (creation date and location) of an existing asset.
    func updateAssetProperties(_ asset: PHAsset, date: Date?, location: CLLocation?) async -> Result<Void, MetaXError>

    // MARK: - Change Observer

    /// Registers an object to receive notifications when the Photo Library content changes.
    func registerChangeObserver(_ observer: PHPhotoLibraryChangeObserver)

    /// Unregisters an object from Photo Library change notifications.
    func unregisterChangeObserver(_ observer: PHPhotoLibraryChangeObserver)
}

// MARK: - Default Parameters Extension

extension PhotoLibraryServiceProtocol {
    func fetchAllPhotos() -> PHFetchResult<PHAsset> {
        fetchAllPhotos(sortedBy: .creationDate)
    }

    func fetchAssets(in collection: PHAssetCollection) -> PHFetchResult<PHAsset> {
        fetchAssets(in: collection, sortedBy: .creationDate)
    }
}
