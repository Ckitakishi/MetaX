//
//  PhotoGridViewModelTests.swift
//  MetaXTests
//

import CoreLocation
@testable import MetaX
import Photos
import Testing
import UIKit

@Suite("Photo Grid View Model Tests")
@MainActor
struct PhotoGridViewModelTests {

    @Test("Toggle selection adds and removes identifiers")
    func toggleSelectionAddsAndRemovesIdentifiers() {
        let viewModel = makeViewModel(assetCount: 2)

        #expect(viewModel.selectedCount == 0)

        #expect(viewModel.toggleSelection(at: 0) == true)
        #expect(viewModel.selectedCount == 1)
        #expect(viewModel.isSelected(at: 0) == true)

        #expect(viewModel.toggleSelection(at: 0) == true)
        #expect(viewModel.selectedCount == 0)
        #expect(viewModel.isSelected(at: 0) == false)
    }

    @Test("Clearing selection mode removes all selections")
    func leavingSelectionModeClearsSelectedIdentifiers() {
        let viewModel = makeViewModel(assetCount: 3)
        viewModel.isSelecting = true

        #expect(viewModel.setSelected(true, at: 0) == true)
        #expect(viewModel.setSelected(true, at: 1) == true)
        #expect(viewModel.selectedCount == 2)

        viewModel.isSelecting = false

        #expect(viewModel.selectedCount == 0)
        #expect(viewModel.isSelecting == false)
        #expect(viewModel.isSelected(at: 0) == false)
        #expect(viewModel.isSelected(at: 1) == false)
    }

    @Test("clearSelection exits selection mode and clears state")
    func clearSelectionResetsSelectionState() {
        let viewModel = makeViewModel(assetCount: 2)
        viewModel.isSelecting = true
        #expect(viewModel.setSelected(true, at: 0) == true)

        viewModel.clearSelection()

        #expect(viewModel.isSelecting == false)
        #expect(viewModel.selectedCount == 0)
    }

    @Test("Selection limit blocks adding the one-hundredth asset")
    func selectionLimitIsEnforced() {
        let viewModel = makeViewModel(assetCount: PhotoGridViewModel.maxSelectionCount + 1)
        viewModel.isSelecting = true

        for index in 0..<PhotoGridViewModel.maxSelectionCount {
            #expect(viewModel.setSelected(true, at: index) == true)
        }

        #expect(viewModel.selectedCount == PhotoGridViewModel.maxSelectionCount)
        #expect(viewModel.isAtSelectionLimit == true)
        #expect(viewModel.setSelected(true, at: PhotoGridViewModel.maxSelectionCount) == false)
        #expect(viewModel.toggleSelection(at: PhotoGridViewModel.maxSelectionCount) == false)
        #expect(viewModel.selectedCount == PhotoGridViewModel.maxSelectionCount)
    }

    @Test("Out-of-range selection requests are ignored")
    func outOfRangeSelectionRequestsFailSafely() {
        let viewModel = makeViewModel(assetCount: 1)

        #expect(viewModel.setSelected(true, at: 10) == false)
        #expect(viewModel.toggleSelection(at: 10) == false)
        #expect(viewModel.isSelected(at: 10) == false)
        #expect(viewModel.selectedCount == 0)
    }

    @Test("Refreshing without collection fetches all photos using current sort order")
    func refreshWithoutCollectionUsesGlobalFetch() {
        let service = SpyPhotoLibraryService()
        let expectedFetchResult = makeFetchResult(assetCount: 2)
        service.fetchAllPhotosResult = expectedFetchResult
        let viewModel = PhotoGridViewModel(photoLibraryService: service)

        viewModel.currentSortOrder = .addedDate

        #expect(service.fetchAllPhotosCallCount == 1)
        #expect(service.lastFetchAllPhotosSortOrder == .addedDate)
        #expect(viewModel.numberOfItems == 2)
    }

    @Test("Refreshing with collection fetches assets from that collection")
    func refreshWithCollectionUsesCollectionFetch() {
        let service = SpyPhotoLibraryService()
        let collection = makeAssetCollection(localIdentifier: "collection-1")
        let initialFetchResult = makeFetchResult(assetCount: 1)
        let refreshedFetchResult = makeFetchResult(assetCount: 3)
        service.fetchAssetsResult = refreshedFetchResult
        let viewModel = PhotoGridViewModel(photoLibraryService: service)

        viewModel.configure(with: initialFetchResult, collection: collection)
        viewModel.refreshPhotos()

        #expect(service.fetchAssetsCallCount == 1)
        #expect(service.lastFetchAssetsCollection?.localIdentifier == collection.localIdentifier)
        #expect(service.lastFetchAssetsSortOrder == .creationDate)
        #expect(viewModel.numberOfItems == 3)
    }

    @Test("Registering and unregistering photo library observer delegates to service")
    func observerRegistrationDelegatesToService() {
        let service = SpyPhotoLibraryService()
        let viewModel = PhotoGridViewModel(photoLibraryService: service)

        viewModel.registerPhotoLibraryObserver()
        viewModel.unregisterPhotoLibraryObserver()

        #expect(service.registeredObserver === viewModel)
        #expect(service.unregisteredObserver === viewModel)
    }

    private func makeViewModel(assetCount: Int) -> PhotoGridViewModel {
        let service = SpyPhotoLibraryService()
        let viewModel = PhotoGridViewModel(photoLibraryService: service)
        viewModel.configure(with: makeFetchResult(assetCount: assetCount), collection: nil)
        return viewModel
    }

    private func makeFetchResult(assetCount: Int) -> PHFetchResult<PHAsset> {
        let assets = (0..<assetCount).map { index in
            unsafeBitCast(FakePHAsset(localIdentifier: "asset-\(index)"), to: PHAsset.self)
        }
        return unsafeBitCast(FakePHFetchResult(objects: assets), to: PHFetchResult<PHAsset>.self)
    }

    private func makeAssetCollection(localIdentifier: String) -> PHAssetCollection {
        unsafeBitCast(FakePHAssetCollection(localIdentifier: localIdentifier), to: PHAssetCollection.self)
    }
}

private final class FakePHAsset: NSObject {
    private let storedIdentifier: String

    init(localIdentifier: String) {
        storedIdentifier = localIdentifier
        super.init()
    }

    @objc override var description: String {
        storedIdentifier
    }

    @objc var localIdentifier: String {
        storedIdentifier
    }

    @objc var mediaSubtypes: PHAssetMediaSubtype {
        []
    }
}

private final class FakePHFetchResult: NSObject {
    private let objects: [PHAsset]

    init(objects: [PHAsset]) {
        self.objects = objects
        super.init()
    }

    @objc var count: Int {
        objects.count
    }

    @objc(objectAtIndex:)
    func object(at index: Int) -> Any {
        objects[index]
    }
}

private final class FakePHAssetCollection: NSObject {
    private let storedIdentifier: String

    init(localIdentifier: String) {
        storedIdentifier = localIdentifier
        super.init()
    }

    @objc var localIdentifier: String {
        storedIdentifier
    }
}

private final class SpyPhotoLibraryService: PhotoLibraryServiceProtocol, @unchecked Sendable {
    var fetchAllPhotosResult: PHFetchResult<PHAsset> = unsafeBitCast(
        FakePHFetchResult(objects: []),
        to: PHFetchResult<PHAsset>.self
    )
    var fetchAssetsResult: PHFetchResult<PHAsset> = unsafeBitCast(
        FakePHFetchResult(objects: []),
        to: PHFetchResult<PHAsset>.self
    )
    private(set) var fetchAllPhotosCallCount = 0
    private(set) var fetchAssetsCallCount = 0
    private(set) var lastFetchAllPhotosSortOrder: PhotoSortOrder?
    private(set) var lastFetchAssetsSortOrder: PhotoSortOrder?
    private(set) var lastFetchAssetsCollection: PHAssetCollection?
    private(set) weak var registeredObserver: PHPhotoLibraryChangeObserver?
    private(set) weak var unregisteredObserver: PHPhotoLibraryChangeObserver?

    func checkAuthorization() async -> Result<Void, MetaXError> { .failure(.unknown(underlying: nil)) }
    func guideToSettings() {}
    func fetchAllPhotos(sortedBy sortOrder: PhotoSortOrder) -> PHFetchResult<PHAsset> {
        fetchAllPhotosCallCount += 1
        lastFetchAllPhotosSortOrder = sortOrder
        return fetchAllPhotosResult
    }

    func fetchAssets(
        in collection: PHAssetCollection,
        sortedBy sortOrder: PhotoSortOrder
    ) -> PHFetchResult<PHAsset> {
        fetchAssetsCallCount += 1
        lastFetchAssetsCollection = collection
        lastFetchAssetsSortOrder = sortOrder
        return fetchAssetsResult
    }

    func fetchSmartAlbums() -> PHFetchResult<PHAssetCollection> { fatalError("Not used") }
    func fetchUserCollections() -> PHFetchResult<PHCollection> { fatalError("Not used") }
    func createAlbumIfNeeded(title: String) async -> Result<PHAssetCollection, MetaXError> {
        .failure(.unknown(underlying: nil))
    }

    func albumExists(title: String) -> Bool { false }
    func cancelImageRequest(_ requestID: PHImageRequestID) {}
    @discardableResult
    func requestThumbnail(
        for asset: PHAsset,
        targetSize: CGSize,
        completion: @escaping (UIImage?, Bool) -> Void
    ) -> PHImageRequestID { .init(0) }
    func requestThumbnailStream(
        for asset: PHAsset,
        targetSize: CGSize
    ) -> AsyncStream<(UIImage?, Bool)> { AsyncStream { $0.finish() } }
    func requestLivePhotoStream(
        for asset: PHAsset,
        targetSize: CGSize
    ) -> AsyncStream<(PHLivePhoto?, Bool)> { AsyncStream { $0.finish() } }
    func startCachingThumbnails(for assets: [PHAsset], targetSize: CGSize) {}
    func stopCachingThumbnails(for assets: [PHAsset], targetSize: CGSize) {}
    func stopCachingAllThumbnails() {}
    func deleteAsset(_ asset: PHAsset) async -> Result<Void, MetaXError> { .failure(.unknown(underlying: nil)) }
    func revertAsset(_ asset: PHAsset) async -> Result<Void, MetaXError> { .failure(.unknown(underlying: nil)) }
    func updateAssetProperties(
        _ asset: PHAsset,
        date: Date?,
        location: CLLocation?
    ) async -> Result<Void, MetaXError> { .failure(.unknown(underlying: nil)) }
    func registerChangeObserver(_ observer: PHPhotoLibraryChangeObserver) {
        registeredObserver = observer
    }

    func unregisterChangeObserver(_ observer: PHPhotoLibraryChangeObserver) {
        unregisteredObserver = observer
    }
}
