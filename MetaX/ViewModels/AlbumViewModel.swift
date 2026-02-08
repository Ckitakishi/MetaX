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
        let allPhotosOptions = PHFetchOptions()
        allPhotosOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        allPhotos = PHAsset.fetchAssets(with: allPhotosOptions)

        userCollections = PHCollectionList.fetchTopLevelUserCollections(with: nil)
        userAssetCollections = updatedUserAssetCollections()

        smartAlbums = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .any, options: nil)
        nonEmptySmartAlbums = updatedNonEmptyAlbums()

        applySearchAndSort()
    }

    func registerPhotoLibraryObserver() {
        PHPhotoLibrary.shared().register(self)
    }

    func unregisterPhotoLibraryObserver() {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
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

    func albumInfo(at indexPath: IndexPath) -> (title: String?, count: Int, asset: PHAsset?) {
        guard let section = AlbumSection(rawValue: indexPath.section) else {
            return (nil, 0, nil)
        }

        switch section {
        case .allPhotos:
            let count = allPhotos?.count ?? 0
            let asset = count > 0 ? allPhotos?.object(at: 0) : nil
            return (String(localized: .viewAllPhotos), count, asset)

        case .userCollections:
            guard indexPath.row < displayedUserCollections.count else { return (nil, 0, nil) }
            let collection = displayedUserCollections[indexPath.row]
            return (collection.localizedTitle, collection.imagesCount, collection.newestImage())

        case .smartAlbums:
            guard indexPath.row < displayedSmartAlbums.count else { return (nil, 0, nil) }
            let collection = displayedSmartAlbums[indexPath.row]
            return (collection.localizedTitle, collection.imagesCount, collection.newestImage())
        }
    }

    func fetchResult(for indexPath: IndexPath) -> (fetchResult: PHFetchResult<PHAsset>?, collection: PHAssetCollection?, title: String?) {
        guard let section = AlbumSection(rawValue: indexPath.section) else {
            return (nil, nil, nil)
        }

        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        switch section {
        case .allPhotos:
            return (allPhotos, nil, String(localized: .viewAllPhotos))

        case .userCollections:
            guard indexPath.row < displayedUserCollections.count else { return (nil, nil, nil) }
            let collection = displayedUserCollections[indexPath.row]
            return (PHAsset.fetchAssets(in: collection, options: options), collection, collection.localizedTitle)

        case .smartAlbums:
            guard indexPath.row < displayedSmartAlbums.count else { return (nil, nil, nil) }
            let collection = displayedSmartAlbums[indexPath.row]
            return (PHAsset.fetchAssets(in: collection, options: options), collection, collection.localizedTitle)
        }
    }

    // MARK: - Thumbnail

    func getThumbnail(for asset: PHAsset, targetSize: CGSize? = nil, completion: @escaping (UIImage?) -> Void) {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isSynchronous = false
        options.isNetworkAccessAllowed = true

        let size = targetSize ?? CGSize(width: 100.0, height: 100.0)

        PHImageManager.default().requestImage(
            for: asset,
            targetSize: size,
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            completion(image)
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

    private func updatedNonEmptyAlbums() -> [PHAssetCollection] {
        guard let smartAlbums = smartAlbums else { return [] }

        var result: [PHAssetCollection] = []
        smartAlbums.enumerateObjects { collection, _, _ in
            if collection.imagesCount > 0 {
                result.append(collection)
            }
        }
        return result
    }

    private func updatedUserAssetCollections() -> [PHAssetCollection] {
        guard let userCollections = userCollections else { return [] }

        var result: [PHAssetCollection] = []
        userCollections.enumerateObjects { [weak self] collection, _, _ in
            if let assetCollection = collection as? PHAssetCollection {
                result.append(assetCollection)
            } else if let collectionList = collection as? PHCollectionList {
                result.append(contentsOf: self?.flattenCollectionList(collectionList) ?? [])
            }
        }
        return result
    }

    private func flattenCollectionList(_ list: PHCollectionList) -> [PHAssetCollection] {
        var assetCollections: [PHAssetCollection] = []
        let tempCollections = PHCollectionList.fetchCollections(in: list, options: nil)

        tempCollections.enumerateObjects { [weak self] collection, _, _ in
            if let assetCollection = collection as? PHAssetCollection {
                assetCollections.append(assetCollection)
            } else if let collectionList = collection as? PHCollectionList {
                assetCollections.append(contentsOf: self?.flattenCollectionList(collectionList) ?? [])
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

            applySearchAndSort()
        }
    }
}
