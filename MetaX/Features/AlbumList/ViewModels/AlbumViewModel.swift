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

/// Section types for album list.
enum AlbumSection: Int, CaseIterable {
    case allPhotos = 0
    case smartAlbums
    case userCollections

    static var count: Int {
        allCases.count
    }
}

/// Sort options for the album list.
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

/// ViewModel for AlbumViewController.
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

    // Cache - Keyed by PHAssetCollection.localIdentifier.
    private var coverAssetCache: [String: PHAsset?] = [:]
    private var assetCountCache: [String: Int] = [:]
    private var pendingLoadIds: Set<String> = []
    private var loadCompletionHandlers: [String: [(Int, UIImage?) -> Void]] = [:]

    /// Incremented during invalidation to detect stale async results.
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

    /// Number of in-flight metadata DB queries.
    private(set) var pendingLoadsCount: Int = 0

    // MARK: - Dependencies

    private let photoLibraryService: PhotoLibraryServiceProtocol

    // MARK: - Initialization

    init(photoLibraryService: PhotoLibraryServiceProtocol) {
        self.photoLibraryService = photoLibraryService
        super.init()
    }

    // MARK: - Public Methods

    /// Checks authorization and loads albums if granted.
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

    // MARK: - Data Access

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

    /// Returns title, count, and cover asset for the given indexPath.
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
            guard let collection = displayedUserCollections[safe: indexPath.row] else { return (nil, nil, nil) }
            let id = collection.localIdentifier
            return (collection.localizedTitle, assetCountCache[id], coverAssetCache[id] ?? nil)

        case .smartAlbums:
            guard let collection = displayedSmartAlbums[safe: indexPath.row] else { return (nil, nil, nil) }
            let id = collection.localIdentifier
            return (collection.localizedTitle, assetCountCache[id], coverAssetCache[id] ?? nil)
        }
    }

    func collectionIdentifier(at indexPath: IndexPath) -> String? {
        guard let section = AlbumSection(rawValue: indexPath.section) else { return nil }
        switch section {
        case .allPhotos: return nil
        case .userCollections:
            return displayedUserCollections[safe: indexPath.row]?.localIdentifier
        case .smartAlbums:
            return displayedSmartAlbums[safe: indexPath.row]?.localIdentifier
        }
    }

    /// Fetches count and cover thumbnail for the collection at the given indexPath.
    func loadCellDataIfNeeded(
        at indexPath: IndexPath,
        thumbnailSize: CGSize,
        completion: @escaping (Int, UIImage?) -> Void
    ) {
        guard let section = AlbumSection(rawValue: indexPath.section), section != .allPhotos else { return }

        let collection: PHAssetCollection
        switch section {
        case .allPhotos: fatalError("unreachable")
        case .userCollections:
            guard let col = displayedUserCollections[safe: indexPath.row] else { return }
            collection = col
        case .smartAlbums:
            guard let col = displayedSmartAlbums[safe: indexPath.row] else { return }
            collection = col
        }

        let id = collection.localIdentifier
        if assetCountCache[id] != nil { return }

        loadCompletionHandlers[id, default: []].append(completion)
        guard !pendingLoadIds.contains(id) else { return }

        pendingLoadIds.insert(id)
        pendingLoadsCount += 1

        let generation = cacheGeneration
        Task { [weak self] in
            let (cover, count) = await Task.detached(priority: .userInitiated) {
                (collection.newestImage(), collection.imagesCount)
            }.value

            guard let self, self.cacheGeneration == generation else { return }
            coverAssetCache[id] = cover
            assetCountCache[id] = count

            guard let cover else {
                self.pendingLoadIds.remove(id)
                self.pendingLoadsCount -= 1
                for cb in loadCompletionHandlers.removeValue(forKey: id) ?? [] {
                    cb(count, nil)
                }
                return
            }

            let pendingCallbacks = loadCompletionHandlers.removeValue(forKey: id) ?? []
            photoLibraryService
                .requestThumbnail(for: cover, targetSize: thumbnailSize) { [weak self] image, isDegraded in
                    Task { @MainActor in
                        guard let self, self.cacheGeneration == generation else { return }

                        for cb in pendingCallbacks {
                            cb(count, image)
                        }

                        if !isDegraded || image == nil {
                            guard self.pendingLoadIds.contains(id) else { return }
                            self.pendingLoadIds.remove(id)
                            self.pendingLoadsCount -= 1
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

        switch section {
        case .allPhotos:
            return (allPhotos, nil, String(localized: .viewAllPhotos))

        case .userCollections:
            guard let collection = displayedUserCollections[safe: indexPath.row] else { return (nil, nil, nil) }
            return (
                photoLibraryService.fetchAssets(in: collection, sortedBy: .creationDate),
                collection,
                collection.localizedTitle
            )

        case .smartAlbums:
            guard let collection = displayedSmartAlbums[safe: indexPath.row] else { return (nil, nil, nil) }
            return (
                photoLibraryService.fetchAssets(in: collection, sortedBy: .creationDate),
                collection,
                collection.localizedTitle
            )
        }
    }

    // MARK: - Thumbnail Operations

    func requestThumbnailStream(for asset: PHAsset, targetSize: CGSize? = nil) -> AsyncStream<(UIImage?, Bool)> {
        let size = targetSize ?? CGSize(width: 100.0, height: 100.0)
        return photoLibraryService.requestThumbnailStream(for: asset, targetSize: size)
    }

    func stopCachingThumbnails(for indexPaths: [IndexPath], targetSize: CGSize) {
        let assets: [PHAsset] = indexPaths.compactMap { indexPath in
            guard let section = AlbumSection(rawValue: indexPath.section), section != .allPhotos else { return nil }
            let id: String
            switch section {
            case .allPhotos: return nil
            case .userCollections:
                guard let col = displayedUserCollections[safe: indexPath.row] else { return nil }
                id = col.localIdentifier
            case .smartAlbums:
                guard let col = displayedSmartAlbums[safe: indexPath.row] else { return nil }
                id = col.localIdentifier
            }
            return coverAssetCache[id] ?? nil
        }
        guard !assets.isEmpty else { return }
        photoLibraryService.stopCachingThumbnails(for: assets, targetSize: targetSize)
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

    private func invalidateCaches() {
        photoLibraryService.stopCachingAllThumbnails()
        cacheGeneration += 1
        coverAssetCache.removeAll()
        assetCountCache.removeAll()
        pendingLoadIds.removeAll()
        pendingLoadsCount = 0
        loadCompletionHandlers.removeAll()
    }

    private func updatedNonEmptyAlbums() -> [PHAssetCollection] {
        guard let smartAlbums else { return [] }

        var result: [PHAssetCollection] = []
        smartAlbums.enumerateObjects { collection, _, _ in
            // Filter out "Recents" as it's redundant with the "All Photos" section.
            if collection.assetCollectionSubtype == .smartAlbumUserLibrary {
                return
            }

            if collection.hasImages {
                result.append(collection)
            }
        }
        return result
    }

    private func updatedUserAssetCollections() -> [PHAssetCollection] {
        guard let userCollections else { return [] }

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

    /// Returns true when structural changes occurred (insertion/removal).
    private func isStructural<T: PHObject>(_ details: PHFetchResultChangeDetails<T>) -> Bool {
        !details.hasIncrementalChanges
            || details.insertedIndexes?.isEmpty == false
            || details.removedIndexes?.isEmpty == false
    }

    nonisolated func photoLibraryDidChange(_ changeInstance: PHChange) {
        Task { @MainActor in
            var needsReload = false

            if let allPhotos, let details = changeInstance.changeDetails(for: allPhotos) {
                self.allPhotos = details.fetchResultAfterChanges
                if isStructural(details) { needsReload = true }
            }

            if let smartAlbums, let details = changeInstance.changeDetails(for: smartAlbums) {
                self.smartAlbums = details.fetchResultAfterChanges
                if isStructural(details) {
                    nonEmptySmartAlbums = updatedNonEmptyAlbums()
                    needsReload = true
                }
            }

            if let userCollections, let details = changeInstance.changeDetails(for: userCollections) {
                self.userCollections = details.fetchResultAfterChanges
                if isStructural(details) {
                    userAssetCollections = updatedUserAssetCollections()
                    needsReload = true
                }
            }

            if needsReload {
                invalidateCaches()
                applySearchAndSort()
            }
        }
    }
}
