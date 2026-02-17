//
//  PhotoGridViewModel.swift
//  MetaX
//
//  Created by Chen Yuhan on 2026/02/03.
//  Copyright © 2026 Chen Yuhan. All rights reserved.
//

import Observation
import Photos
import UIKit

@Observable @MainActor
final class PhotoGridViewModel: NSObject {

    struct CellModel {
        let asset: PHAsset
        let identifier: String
        let isLivePhoto: Bool
    }

    // MARK: - Properties

    private(set) var fetchResult: PHFetchResult<PHAsset>?

    private(set) var assetCollection: PHAssetCollection?
    private var previousPreheatRect = CGRect.zero
    private var thumbnailSize: CGSize = .zero

    private var pendingFetchResult: PHFetchResult<PHAsset>?
    private var libraryChangeTask: Task<Void, Never>?

    // MARK: - Dependencies

    private let photoLibraryService: PhotoLibraryServiceProtocol

    // MARK: - Initialization

    init(photoLibraryService: PhotoLibraryServiceProtocol) {
        self.photoLibraryService = photoLibraryService
        super.init()
    }

    // MARK: - Configuration

    func configure(with fetchResult: PHFetchResult<PHAsset>?, collection: PHAssetCollection?) {
        libraryChangeTask?.cancel()
        pendingFetchResult = nil
        self.fetchResult = fetchResult
        assetCollection = collection
    }

    func setThumbnailSize(_ size: CGSize) {
        thumbnailSize = size
    }

    // MARK: - Public Methods

    func loadDefaultPhotosIfNeeded() {
        guard fetchResult == nil else {
            resetCachedAssets()
            return
        }
        fetchResult = photoLibraryService.fetchAllPhotos()
    }

    func registerPhotoLibraryObserver() {
        photoLibraryService.registerChangeObserver(self)
    }

    func unregisterPhotoLibraryObserver() {
        photoLibraryService.unregisterChangeObserver(self)
    }

    // MARK: - Data Access

    var numberOfItems: Int {
        fetchResult?.count ?? 0
    }

    func cellModel(at index: Int) -> CellModel? {
        guard let asset = asset(at: index) else { return nil }
        return CellModel(
            asset: asset,
            identifier: asset.localIdentifier,
            isLivePhoto: asset.mediaSubtypes.contains(.photoLive)
        )
    }

    func asset(at index: Int) -> PHAsset? {
        guard let fetchResult = fetchResult, index < fetchResult.count else { return nil }
        return fetchResult.object(at: index)
    }

    // MARK: - Image Loading

    func requestImageStream(for asset: PHAsset, targetSize: CGSize) -> AsyncStream<(UIImage?, Bool)> {
        photoLibraryService.requestThumbnailStream(for: asset, targetSize: targetSize)
    }

    // MARK: - Caching

    func resetCachedAssets() {
        photoLibraryService.stopCachingAllThumbnails()
        previousPreheatRect = .zero
    }

    func updateCachedAssets(
        visibleRect: CGRect,
        viewBoundsHeight: CGFloat,
        indexPathsProvider: (CGRect) -> [IndexPath]
    ) {
        guard thumbnailSize != .zero else { return }

        let preheatRect = visibleRect.insetBy(dx: 0, dy: -0.5 * visibleRect.height)

        let delta = abs(preheatRect.midY - previousPreheatRect.midY)
        guard delta > viewBoundsHeight / 3 else { return }

        let (addedRects, removedRects) = differencesBetweenRects(previousPreheatRect, preheatRect)

        let addedAssets = addedRects
            .flatMap { indexPathsProvider($0) }
            .compactMap { asset(at: $0.item) }

        let removedAssets = removedRects
            .flatMap { indexPathsProvider($0) }
            .compactMap { asset(at: $0.item) }

        photoLibraryService.startCachingThumbnails(for: addedAssets, targetSize: thumbnailSize)
        photoLibraryService.stopCachingThumbnails(for: removedAssets, targetSize: thumbnailSize)

        previousPreheatRect = preheatRect
    }

    // MARK: - Private Methods

    private func differencesBetweenRects(_ old: CGRect, _ new: CGRect) -> (added: [CGRect], removed: [CGRect]) {
        if old.intersects(new) {
            var added = [CGRect]()
            if new.maxY > old.maxY {
                added.append(CGRect(x: new.origin.x, y: old.maxY, width: new.width, height: new.maxY - old.maxY))
            }
            if old.minY > new.minY {
                added.append(CGRect(x: new.origin.x, y: new.minY, width: new.width, height: old.minY - new.minY))
            }

            var removed = [CGRect]()
            if new.maxY < old.maxY {
                removed.append(CGRect(x: new.origin.x, y: new.maxY, width: new.width, height: old.maxY - new.maxY))
            }
            if old.minY < new.minY {
                removed.append(CGRect(x: new.origin.x, y: old.minY, width: new.width, height: new.minY - old.minY))
            }
            return (added, removed)
        } else {
            return ([new], [old])
        }
    }
}

// MARK: - PHPhotoLibraryChangeObserver

extension PhotoGridViewModel: PHPhotoLibraryChangeObserver {

    nonisolated func photoLibraryDidChange(_ changeInstance: PHChange) {
        Task { @MainActor in
            // Always diff against the latest accumulated result, not the last committed one.
            guard let base = self.pendingFetchResult ?? self.fetchResult,
                  let changes = changeInstance.changeDetails(for: base) else { return }

            self.pendingFetchResult = changes.fetchResultAfterChanges

            // Debounce: coalesce rapid notifications into a single reloadData.
            libraryChangeTask?.cancel()
            libraryChangeTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled, let pending = self.pendingFetchResult else { return }
                self.fetchResult = pending
                self.pendingFetchResult = nil
            }
        }
    }
}
