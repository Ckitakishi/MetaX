//
//  PhotoLibraryServiceProtocol.swift
//  MetaX
//
//  Created by Chen Yuhan on 2026/02/03.
//  Copyright © 2026 Chen Yuhan. All rights reserved.
//

import Photos
import UIKit

/// Protocol defining photo library operations
protocol PhotoLibraryServiceProtocol {
    // MARK: - Authorization

    /// Check current authorization status and request if needed
    func checkAuthorization() async -> Result<Void, MetaXError>

    /// Guide user to Settings app to enable photo access
    func guideToSettings()

    // MARK: - Fetch Operations

    /// Fetch all photos with optional sort descriptor
    func fetchAllPhotos(sortedBy sortDescriptor: NSSortDescriptor?) -> PHFetchResult<PHAsset>

    /// Fetch assets in a specific collection
    func fetchAssets(in collection: PHAssetCollection, sortedBy sortDescriptor: NSSortDescriptor?)
        -> PHFetchResult<PHAsset>

    /// Fetch smart albums
    func fetchSmartAlbums() -> PHFetchResult<PHAssetCollection>

    /// Fetch user collections (top level)
    func fetchUserCollections() -> PHFetchResult<PHCollection>

    // MARK: - Album Management

    /// Create album if it doesn't exist, return existing one if it does
    func createAlbumIfNeeded(title: String) async -> Result<PHAssetCollection, MetaXError>

    /// Check if album with given title exists
    func albumExists(title: String) -> Bool

    // MARK: - Image Operations

    /// Cancels a pending image request.
    func cancelImageRequest(_ requestID: PHImageRequestID)

    /// Request a thumbnail asynchronously. The completion may fire twice when using
    /// opportunistic delivery: once with a fast degraded image, then again with the
    /// full-quality result. Callers should guard against cell reuse.
    /// Returns a request ID that can be used to cancel the request.
    @discardableResult
    func requestThumbnail(
        for asset: PHAsset,
        targetSize: CGSize,
        completion: @escaping (UIImage?, Bool) -> Void
    ) -> PHImageRequestID

    /// Request a thumbnail as an AsyncStream. Yields multiple results (degraded image first, then high-quality).
    func requestThumbnailStream(for asset: PHAsset, targetSize: CGSize) -> AsyncStream<(UIImage?, Bool)>

    /// Request a live photo as an AsyncStream.
    func requestLivePhotoStream(for asset: PHAsset, targetSize: CGSize) -> AsyncStream<(PHLivePhoto?, Bool)>

    // MARK: - Thumbnail Caching

    /// Pre-warms the image cache for the given assets at the specified thumbnail size.
    /// Call this when assets are about to become visible (e.g. during prefetch).
    func startCachingThumbnails(for assets: [PHAsset], targetSize: CGSize)

    /// Releases cached thumbnails for assets that are no longer needed.
    /// Options must match those passed to startCachingThumbnails.
    func stopCachingThumbnails(for assets: [PHAsset], targetSize: CGSize)

    /// Releases all cached thumbnails managed by this service.
    func stopCachingAllThumbnails()

    // MARK: - Asset Operations

    /// Delete an asset from the library
    func deleteAsset(_ asset: PHAsset) async -> Result<Void, MetaXError>

    /// Revert an edited asset to its original state
    func revertAsset(_ asset: PHAsset) async -> Result<Void, MetaXError>

    /// Update an asset's creation date and location
    func updateAssetProperties(_ asset: PHAsset, date: Date?, location: CLLocation?) async -> Result<Void, MetaXError>

    // MARK: - Change Observer

    /// Register a change observer
    func registerChangeObserver(_ observer: PHPhotoLibraryChangeObserver)

    /// Unregister a change observer
    func unregisterChangeObserver(_ observer: PHPhotoLibraryChangeObserver)
}

// MARK: - Default Parameters Extension

extension PhotoLibraryServiceProtocol {
    func fetchAllPhotos() -> PHFetchResult<PHAsset> {
        fetchAllPhotos(sortedBy: NSSortDescriptor(key: "creationDate", ascending: false))
    }

    func fetchAssets(in collection: PHAssetCollection) -> PHFetchResult<PHAsset> {
        fetchAssets(in: collection, sortedBy: nil)
    }
}
