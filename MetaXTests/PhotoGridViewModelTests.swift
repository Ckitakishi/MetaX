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

    private func makeViewModel(assetCount: Int) -> PhotoGridViewModel {
        let service = StubPhotoLibraryService()
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

private final class StubPhotoLibraryService: PhotoLibraryServiceProtocol, @unchecked Sendable {
    func checkAuthorization() async -> Result<Void, MetaXError> { .failure(.unknown(underlying: nil)) }
    func guideToSettings() {}
    func fetchAllPhotos(sortedBy sortOrder: PhotoSortOrder) -> PHFetchResult<PHAsset> { fatalError("Not used") }
    func fetchAssets(
        in collection: PHAssetCollection,
        sortedBy sortOrder: PhotoSortOrder
    ) -> PHFetchResult<PHAsset> { fatalError("Not used") }
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
    func registerChangeObserver(_ observer: PHPhotoLibraryChangeObserver) {}
    func unregisterChangeObserver(_ observer: PHPhotoLibraryChangeObserver) {}
}
