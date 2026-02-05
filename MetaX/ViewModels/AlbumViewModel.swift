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
    case smartAlbums
    case userCollections

    static var count: Int { allCases.count }
}

/// ViewModel for AlbumViewController
@Observable @MainActor
final class AlbumViewModel: NSObject {

    // MARK: - Properties

    private(set) var allPhotos: PHFetchResult<PHAsset>?
    private(set) var smartAlbums: PHFetchResult<PHAssetCollection>?
    private(set) var nonEmptySmartAlbums: [PHAssetCollection] = []
    private(set) var userCollections: PHFetchResult<PHCollection>?
    private(set) var userAssetCollections: [PHAssetCollection] = []
    private(set) var isAuthorized: Bool = true
    private(set) var needsReload: Bool = false

    // MARK: - Dependencies

    private let photoLibraryService: PhotoLibraryServiceProtocol

    // MARK: - Initialization

    init(photoLibraryService: PhotoLibraryServiceProtocol = PhotoLibraryService.shared) {
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
        // Fetch all photos
        let allPhotosOptions = PHFetchOptions()
        allPhotosOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        allPhotos = PHAsset.fetchAssets(with: allPhotosOptions)

        // Fetch smart albums
        smartAlbums = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .albumRegular, options: nil)
        nonEmptySmartAlbums = updatedNonEmptyAlbums()

        // Fetch user collections
        userCollections = PHCollectionList.fetchTopLevelUserCollections(with: nil)
        userAssetCollections = updatedUserAssetCollections()
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
            return 1
        case .smartAlbums:
            return nonEmptySmartAlbums.count
        case .userCollections:
            return userAssetCollections.count
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
            return (R.string.localizable.viewAllPhotos(), count, asset)

        case .smartAlbums:
            guard indexPath.row < nonEmptySmartAlbums.count else { return (nil, 0, nil) }
            let collection = nonEmptySmartAlbums[indexPath.row]
            return (collection.localizedTitle, collection.imagesCount, collection.newestImage())

        case .userCollections:
            guard indexPath.row < userAssetCollections.count else { return (nil, 0, nil) }
            let collection = userAssetCollections[indexPath.row]
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
            return (allPhotos, nil, R.string.localizable.viewAllPhotos())

        case .smartAlbums:
            guard indexPath.row < nonEmptySmartAlbums.count else { return (nil, nil, nil) }
            let collection = nonEmptySmartAlbums[indexPath.row]
            let result = PHAsset.fetchAssets(in: collection, options: options)
            return (result, collection, collection.localizedTitle)

        case .userCollections:
            guard indexPath.row < userAssetCollections.count else { return (nil, nil, nil) }
            let collection = userAssetCollections[indexPath.row]
            let result = PHAsset.fetchAssets(in: collection, options: options)
            return (result, collection, collection.localizedTitle)
        }
    }

    // MARK: - Thumbnail

    func getThumbnail(for asset: PHAsset, completion: @escaping (UIImage?) -> Void) {
        let options = PHImageRequestOptions()
        options.deliveryMode = .fastFormat
        options.isSynchronous = false
        options.isNetworkAccessAllowed = false

        PHImageManager.default().requestImage(
            for: asset,
            targetSize: CGSize(width: 92.0, height: 92.0),
            contentMode: .aspectFit,
            options: options
        ) { image, _ in
            completion(image)
        }
    }

    // MARK: - Private Methods

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
            
            // Toggle to trigger UI update for table reload
            // Note: Since we are observing, setting a property triggers render.
            // But sometimes we just want to signal "reload".
            // A simple way is to use a dedicated property or ensure data properties change.
            self.needsReload = true
            // Reset it immediately if needed, or handle it in VC.
            // For withObservationTracking, simply changing it is enough.
        }
    }
}
