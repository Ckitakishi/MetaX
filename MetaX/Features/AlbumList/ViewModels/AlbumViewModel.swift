//
//  AlbumViewModel.swift
//  MetaX
//
//  Created by Chen Yuhan on 2026/02/03.
//  Copyright © 2026 Chen Yuhan. All rights reserved.
//

import Observation
import Photos
import UIKit

/// Section types for album list
enum AlbumSection: Int, CaseIterable {
    case allPhotos = 0
    case userCollections
    case smartAlbums

    static var count: Int {
        allCases.count
    }
}

enum AlbumSortOption: CaseIterable {
    case `default`
    case name

    var title: String {
        switch self {
        case .default: return String(localized: .sortDefault)
        case .name: return String(localized: .sortName)
        }
    }
}

/// ViewModel for AlbumViewController
@Observable @MainActor
final class AlbumViewModel: NSObject {

    // MARK: - Properties

    private(set) var allPhotos: PHFetchResult<PHAsset>?
    private(set) var smartAlbums: PHFetchResult<PHAssetCollection>?
    private(set) var userCollections: PHFetchResult<PHCollection>?

    // Raw data
    private var userAssetCollections: [PHAssetCollection] = []
    private var nonEmptySmartAlbums: [PHAssetCollection] = []

    // Display data (filtered + sorted)
    private(set) var displayedUserCollections: [PHAssetCollection] = []
    private(set) var displayedSmartAlbums: [PHAssetCollection] = []

    // Lazy per-cell cache — keyed by PHAssetCollection.localIdentifier.
    // Data is loaded on demand when cells appear, avoiding bulk Photos DB
    // queries that block the main thread or cause multiple reloadData flickers.
    private var coverCache: [String: PHAsset?] = [:]
    private var countCache: [String: Int] = [:]
    private var pendingLoads: Set<String> = []
    private var loadCompletions: [String: [(Int, UIImage?) -> Void]] = [:]
    /// Incremented in invalidateCaches() so in-flight Task.detached blocks can
    /// detect that their results are stale and discard them.
    private var cacheGeneration: Int = 0

    var searchText: String = "" {
        didSet { applySearchAndSort() }
    }

    var sortOption: AlbumSortOption = .default {
        didSet { applySearchAndSort() }
    }

    private(set) var isAuthorized: Bool = true
    private(set) var reloadToken: Int = 0

    /// Returns true if there are albums available to be searched.
    var isSearchAvailable: Bool {
        isAuthorized && (!userAssetCollections.isEmpty || !nonEmptySmartAlbums.isEmpty)
    }

    /// Number of in-flight loadCellDataIfNeeded DB queries.
    /// Observed by AlbumViewController to know when all initial data is loaded.
    private(set) var pendingLoadsCount: Int = 0

    // MARK: - Dependencies

    private let photoLibraryService: PhotoLibraryServiceProtocol

    // MARK: - Initialization

    init(photoLibraryService: PhotoLibraryServiceProtocol) {
        self.photoLibraryService = photoLibraryService
        super.init()
    }

    // MARK: - Public Methods

    /// Checks authorization, loads albums if granted.
    /// Returns true if authorized, false if denied.
    func authorizeAndLoad() async -> Bool {
        let result = await photoLibraryService.checkAuthorization()
        switch result {
        case .success:
            isAuthorized = true
            loadAlbums()
            registerPhotoLibraryObserver()
            return true
        case .failure:
            isAuthorized = false
            return false
        }
    }

    func guideToSettings() {
        photoLibraryService.guideToSettings()
    }

    func loadAlbums() {
        allPhotos = photoLibraryService.fetchAllPhotos()

        userCollections = photoLibraryService.fetchUserCollections()
        userAssetCollections = updatedUserAssetCollections()

        smartAlbums = photoLibraryService.fetchSmartAlbums()
        nonEmptySmartAlbums = updatedNonEmptyAlbums()

        applySearchAndSort()
    }

    func registerPhotoLibraryObserver() {
        photoLibraryService.registerChangeObserver(self)
    }

    func unregisterPhotoLibraryObserver() {
        photoLibraryService.unregisterChangeObserver(self)
    }

    // MARK: - Section Data Access

    func numberOfRows(in section: AlbumSection) -> Int {
        switch section {
        case .allPhotos:
            return searchText.isEmpty ? 1 : 0
        case .userCollections:
            return displayedUserCollections.count
        case .smartAlbums:
            return displayedSmartAlbums.count
        }
    }

    /// Returns cached album info. Count/asset are nil when not yet loaded.
    func albumInfo(at indexPath: IndexPath) -> (title: String?, count: Int?, asset: PHAsset?) {
        guard let section = AlbumSection(rawValue: indexPath.section) else {
            return (nil, nil, nil)
        }

        switch section {
        case .allPhotos:
            let count = allPhotos?.count ?? 0
            let asset = count > 0 ? allPhotos?.object(at: 0) : nil
            return (String(localized: .viewAllPhotos), count, asset)

        case .userCollections:
            guard indexPath.row < displayedUserCollections.count else { return (nil, nil, nil) }
            let collection = displayedUserCollections[indexPath.row]
            let id = collection.localIdentifier
            return (collection.localizedTitle, countCache[id], coverCache[id] ?? nil)

        case .smartAlbums:
            guard indexPath.row < displayedSmartAlbums.count else { return (nil, nil, nil) }
            let collection = displayedSmartAlbums[indexPath.row]
            let id = collection.localIdentifier
            return (collection.localizedTitle, countCache[id], coverCache[id] ?? nil)
        }
    }

    /// Returns the collection's localIdentifier for the given indexPath (nil for allPhotos).
    func collectionIdentifier(at indexPath: IndexPath) -> String? {
        guard let section = AlbumSection(rawValue: indexPath.section) else { return nil }
        switch section {
        case .allPhotos: return nil
        case .userCollections:
            guard indexPath.row < displayedUserCollections.count else { return nil }
            return displayedUserCollections[indexPath.row].localIdentifier
        case .smartAlbums:
            guard indexPath.row < displayedSmartAlbums.count else { return nil }
            return displayedSmartAlbums[indexPath.row].localIdentifier
        }
    }

    /// Loads count + thumbnail for the cell at `indexPath` if not already cached.
    /// The completion fires on the main actor with `(count, image)` once both are
    /// ready — image is nil only when the collection has no cover asset.
    /// No-op for the allPhotos section (always available synchronously).
    func loadCellDataIfNeeded(
        at indexPath: IndexPath,
        thumbnailSize: CGSize,
        completion: @escaping (Int, UIImage?) -> Void
    ) {
        guard let section = AlbumSection(rawValue: indexPath.section), section != .allPhotos else { return }

        let collection: PHAssetCollection
        switch section {
        case .allPhotos: fatalError("unreachable — guarded above")
        case .userCollections:
            guard indexPath.row < displayedUserCollections.count else { return }
            collection = displayedUserCollections[indexPath.row]
        case .smartAlbums:
            guard indexPath.row < displayedSmartAlbums.count else { return }
            collection = displayedSmartAlbums[indexPath.row]
        }

        let id = collection.localIdentifier

        // Already cached — nothing to do (cellForRowAt already got the data via albumInfo).
        if countCache[id] != nil { return }

        // Queue the completion; avoid duplicate Tasks for the same collection.
        loadCompletions[id, default: []].append(completion)
        guard !pendingLoads.contains(id) else { return }
        pendingLoads.insert(id)
        pendingLoadsCount += 1

        // Capture the current generation so the task can discard stale results
        // if invalidateCaches() fires while the fetch is in flight.
        let generation = cacheGeneration
        Task.detached { [weak self] in
            let cover = collection.newestImage()
            let count = collection.imagesCount
            await MainActor.run { [weak self] in
                guard let self, self.cacheGeneration == generation else { return }
                self.coverCache[id] = cover
                self.countCache[id] = count

                guard let cover else {
                    // No cover — fire completions immediately with nil image.
                    self.pendingLoads.remove(id)
                    self.pendingLoadsCount -= 1
                    for cb in self.loadCompletions.removeValue(forKey: id) ?? [] {
                        cb(count, nil)
                    }
                    return
                }

                // Thumbnail request keeps pendingLoadsCount elevated until HQ arrives.
                // Degraded delivery updates cells immediately; final delivery unblocks splash.
                let pendingCallbacks = self.loadCompletions.removeValue(forKey: id) ?? []
                self.photoLibraryService
                    .requestThumbnail(for: cover, targetSize: thumbnailSize) { [weak self] image, isDegraded in
                        Task { @MainActor in
                            guard let self, self.cacheGeneration == generation else { return }

                            // Update cell UI with what we have
                            for cb in pendingCallbacks {
                                cb(count, image)
                            }

                            // Only decrement and clean up when we have the final result
                            if !isDegraded || image == nil {
                                guard self.pendingLoads.contains(id) else { return }
                                self.pendingLoads.remove(id)
                                self.pendingLoadsCount -= 1
                            }
                        }
                    }
            }
        }
    }

    func fetchResult(for indexPath: IndexPath)
        -> (fetchResult: PHFetchResult<PHAsset>?, collection: PHAssetCollection?, title: String?) {
        guard let section = AlbumSection(rawValue: indexPath.section) else {
            return (nil, nil, nil)
        }

        let sortDescriptor = NSSortDescriptor(key: "creationDate", ascending: false)

        switch section {
        case .allPhotos:
            return (allPhotos, nil, String(localized: .viewAllPhotos))

        case .userCollections:
            guard indexPath.row < displayedUserCollections.count else { return (nil, nil, nil) }
            let collection = displayedUserCollections[indexPath.row]
            return (
                photoLibraryService.fetchAssets(in: collection, sortedBy: sortDescriptor),
                collection,
                collection.localizedTitle
            )

        case .smartAlbums:
            guard indexPath.row < displayedSmartAlbums.count else { return (nil, nil, nil) }
            let collection = displayedSmartAlbums[indexPath.row]
            return (
                photoLibraryService.fetchAssets(in: collection, sortedBy: sortDescriptor),
                collection,
                collection.localizedTitle
            )
        }
    }

    // MARK: - Thumbnail

    func requestThumbnailStream(for asset: PHAsset, targetSize: CGSize? = nil) -> AsyncStream<(UIImage?, Bool)> {
        let size = targetSize ?? CGSize(width: 100.0, height: 100.0)
        return photoLibraryService.requestThumbnailStream(for: asset, targetSize: size)
    }

    // MARK: - Private Methods

    private func applySearchAndSort() {
        var users = userAssetCollections
        var smarts = nonEmptySmartAlbums

        if !searchText.isEmpty {
            users = users.filter { $0.localizedTitle?.localizedCaseInsensitiveContains(searchText) ?? false }
            smarts = smarts.filter { $0.localizedTitle?.localizedCaseInsensitiveContains(searchText) ?? false }
        }

        switch sortOption {
        case .default:
            break
        case .name:
            users.sort { ($0.localizedTitle ?? "") < ($1.localizedTitle ?? "") }
            smarts.sort { ($0.localizedTitle ?? "") < ($1.localizedTitle ?? "") }
        }

        displayedUserCollections = users
        displayedSmartAlbums = smarts
        reloadToken += 1
    }

    func stopCachingThumbnails(for indexPaths: [IndexPath], targetSize: CGSize) {
        let assets: [PHAsset] = indexPaths.compactMap { indexPath in
            guard let section = AlbumSection(rawValue: indexPath.section), section != .allPhotos else { return nil }
            let id: String
            switch section {
            case .allPhotos: return nil
            case .userCollections:
                guard indexPath.row < displayedUserCollections.count else { return nil }
                id = displayedUserCollections[indexPath.row].localIdentifier
            case .smartAlbums:
                guard indexPath.row < displayedSmartAlbums.count else { return nil }
                id = displayedSmartAlbums[indexPath.row].localIdentifier
            }
            // Only stop caching assets whose cover we've already resolved.
            return coverCache[id] ?? nil
        }
        guard !assets.isEmpty else { return }
        photoLibraryService.stopCachingThumbnails(for: assets, targetSize: targetSize)
    }

    private func invalidateCaches() {
        // Release PHCachingImageManager entries before clearing the cover references.
        photoLibraryService.stopCachingAllThumbnails()
        cacheGeneration += 1
        coverCache.removeAll()
        countCache.removeAll()
        pendingLoads.removeAll()
        pendingLoadsCount = 0
        loadCompletions.removeAll()
    }

    private func updatedNonEmptyAlbums() -> [PHAssetCollection] {
        guard let smartAlbums = smartAlbums else { return [] }

        var result: [PHAssetCollection] = []
        smartAlbums.enumerateObjects { collection, _, _ in
            if collection.hasImages {
                result.append(collection)
            }
        }
        return result
    }

    private func updatedUserAssetCollections() -> [PHAssetCollection] {
        guard let userCollections = userCollections else { return [] }

        var result: [PHAssetCollection] = []
        userCollections.enumerateObjects { collection, _, _ in
            if let assetCollection = collection as? PHAssetCollection {
                if assetCollection.hasImages {
                    result.append(assetCollection)
                }
            } else if let collectionList = collection as? PHCollectionList {
                let flattened = self.flattenCollectionList(collectionList)
                result.append(contentsOf: flattened.filter { $0.hasImages })
            }
        }
        return result
    }

    private func flattenCollectionList(_ list: PHCollectionList) -> [PHAssetCollection] {
        var assetCollections: [PHAssetCollection] = []
        let tempCollections = PHCollectionList.fetchCollections(in: list, options: nil)

        tempCollections.enumerateObjects { collection, _, _ in
            if let assetCollection = collection as? PHAssetCollection {
                assetCollections.append(assetCollection)
            } else if let collectionList = collection as? PHCollectionList {
                assetCollections.append(contentsOf: self.flattenCollectionList(collectionList))
            }
        }
        return assetCollections
    }
}

// MARK: - PHPhotoLibraryChangeObserver

extension AlbumViewModel: PHPhotoLibraryChangeObserver {

    nonisolated func photoLibraryDidChange(_ changeInstance: PHChange) {
        Task { @MainActor in
            var hasChanges = false

            if let allPhotos = allPhotos, let changeDetails = changeInstance.changeDetails(for: allPhotos) {
                self.allPhotos = changeDetails.fetchResultAfterChanges
                hasChanges = true
            }

            if let smartAlbums = smartAlbums, let changeDetails = changeInstance.changeDetails(for: smartAlbums) {
                self.smartAlbums = changeDetails.fetchResultAfterChanges
                self.nonEmptySmartAlbums = updatedNonEmptyAlbums()
                hasChanges = true
            }

            if let userCollections = userCollections,
               let changeDetails = changeInstance.changeDetails(for: userCollections) {
                self.userCollections = changeDetails.fetchResultAfterChanges
                self.userAssetCollections = updatedUserAssetCollections()
                hasChanges = true
            }

            if hasChanges {
                invalidateCaches()
                applySearchAndSort()
            }
        }
    }
}
