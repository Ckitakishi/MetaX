//
//  AlbumViewModel.swift
//  MetaX
//
//  Created by Chen Yuhan on 2026/02/03.
//  Copyright © 2026 Chen Yuhan. All rights reserved.
//

import UIKit
import Photos
import Observation

/// Section types for album list
enum AlbumSection: Int, CaseIterable {
    case allPhotos = 0
    case userCollections
    case smartAlbums

    static var count: Int { allCases.count }
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
    private var loadCompletions: [String: [(Int, PHAsset?) -> Void]] = [:]
    // Incremented in invalidateCaches() so in-flight Task.detached blocks can
    // detect that their results are stale and discard them.
    private var cacheGeneration: Int = 0

    var searchText: String = "" { didSet { applySearchAndSort() } }
    var sortOption: AlbumSortOption = .default { didSet { applySearchAndSort() } }

    private(set) var isAuthorized: Bool = true
    private(set) var reloadToken: Int = 0

    // MARK: - Dependencies

    private let photoLibraryService: PhotoLibraryServiceProtocol

    // MARK: - Initialization

    init(photoLibraryService: PhotoLibraryServiceProtocol) {
        self.photoLibraryService = photoLibraryService
        super.init()
    }

    // MARK: - Public Methods

    func checkAuthorization() async {
        let result = await photoLibraryService.checkAuthorization()
        switch result {
        case .success:
            self.isAuthorized = true
        case .failure:
            self.isAuthorized = false
        }
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

    /// Loads count + cover asset for the cell at `indexPath` if not already cached.
    /// The completion fires on the main actor once the data is ready.
    /// No-op for the allPhotos section (always available synchronously).
    func loadCellDataIfNeeded(at indexPath: IndexPath, completion: @escaping (Int, PHAsset?) -> Void) {
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
                self.pendingLoads.remove(id)
                for cb in self.loadCompletions.removeValue(forKey: id) ?? [] {
                    cb(count, cover)
                }
            }
        }
    }

    func fetchResult(for indexPath: IndexPath) -> (fetchResult: PHFetchResult<PHAsset>?, collection: PHAssetCollection?, title: String?) {
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
            return (photoLibraryService.fetchAssets(in: collection, sortedBy: sortDescriptor), collection, collection.localizedTitle)

        case .smartAlbums:
            guard indexPath.row < displayedSmartAlbums.count else { return (nil, nil, nil) }
            let collection = displayedSmartAlbums[indexPath.row]
            return (photoLibraryService.fetchAssets(in: collection, sortedBy: sortDescriptor), collection, collection.localizedTitle)
        }
    }

    // MARK: - Thumbnail

    func getThumbnail(for asset: PHAsset, targetSize: CGSize? = nil, completion: @escaping (UIImage?) -> Void) {
        let size = targetSize ?? CGSize(width: 100.0, height: 100.0)
        let service = photoLibraryService
        Task.detached {
            let image = service.requestThumbnail(for: asset, targetSize: size)
            await MainActor.run { completion(image) }
        }
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
        cacheGeneration += 1
        coverCache.removeAll()
        countCache.removeAll()
        pendingLoads.removeAll()
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
                result.append(assetCollection)
            } else if let collectionList = collection as? PHCollectionList {
                result.append(contentsOf: self.flattenCollectionList(collectionList))
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
            if let allPhotos = allPhotos, let changeDetails = changeInstance.changeDetails(for: allPhotos) {
                self.allPhotos = changeDetails.fetchResultAfterChanges
            }

            if let smartAlbums = smartAlbums, let changeDetails = changeInstance.changeDetails(for: smartAlbums) {
                self.smartAlbums = changeDetails.fetchResultAfterChanges
                self.nonEmptySmartAlbums = updatedNonEmptyAlbums()
            }

            if let userCollections = userCollections, let changeDetails = changeInstance.changeDetails(for: userCollections) {
                self.userCollections = changeDetails.fetchResultAfterChanges
                self.userAssetCollections = updatedUserAssetCollections()
            }

            invalidateCaches()
            applySearchAndSort()
        }
    }
}
