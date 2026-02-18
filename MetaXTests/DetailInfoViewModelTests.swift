//
//  DetailInfoViewModelTests.swift
//  MetaXTests
//

import CoreLocation
import Foundation
@testable import MetaX
import Photos
import Testing
import UIKit

@Suite("Detail Info Sync Logic Tests")
@MainActor
struct DetailInfoViewModelTests {

    let viewModel: DetailInfoViewModel

    init() {
        viewModel = DetailInfoViewModel(
            metadataService: MockMetadataService(),
            imageSaveService: MockImageSaveService(),
            photoLibraryService: MockPhotoLibraryService()
        )
    }

    @Test("Sync decision: Date tolerance")
    func dateSyncDecision() {
        let now = Date()

        // 1. Difference < 1s (0.5s)
        let needs1 = viewModel.calculateSyncNeeds(
            newDate: now.addingTimeInterval(0.5),
            currentDate: now,
            newLocation: nil,
            currentLocation: nil
        )
        #expect(needs1.dateChanged == false)

        // 2. Difference > 1s (1.5s)
        let needs2 = viewModel.calculateSyncNeeds(
            newDate: now.addingTimeInterval(1.5),
            currentDate: now,
            newLocation: nil,
            currentLocation: nil
        )
        #expect(needs2.dateChanged == true)

        // 3. One is nil
        let needs3 = viewModel.calculateSyncNeeds(
            newDate: now,
            currentDate: nil,
            newLocation: nil,
            currentLocation: nil
        )
        #expect(needs3.dateChanged == true)
    }

    @Test("Sync decision: Location tolerance")
    func locationSyncDecision() {
        let loc1 = CLLocation(latitude: 35.0, longitude: 139.0)

        // 1. Very small difference (same location roughly)
        let locSmallDiff = CLLocation(latitude: 35.000001, longitude: 139.000001)
        let needs1 = viewModel.calculateSyncNeeds(
            newDate: nil,
            currentDate: nil,
            newLocation: locSmallDiff,
            currentLocation: loc1
        )
        #expect(needs1.locationChanged == false)

        // 2. Significant difference
        let locBigDiff = CLLocation(latitude: 35.1, longitude: 139.1)
        let needs2 = viewModel.calculateSyncNeeds(
            newDate: nil,
            currentDate: nil,
            newLocation: locBigDiff,
            currentLocation: loc1
        )
        #expect(needs2.locationChanged == true)

        // 3. One is nil
        let needs3 = viewModel.calculateSyncNeeds(
            newDate: nil,
            currentDate: nil,
            newLocation: loc1,
            currentLocation: nil
        )
        #expect(needs3.locationChanged == true)
    }
}

class MockMetadataService: MetadataServiceProtocol, @unchecked Sendable {
    func loadMetadataEvents(from asset: PHAsset) -> AsyncStream<MetadataLoadEvent> { AsyncStream { $0.finish() } }
    func updateTimestamp(_ date: Date, in metadata: Metadata) -> [String: Any] { [:] }
    func removeTimestamp(from metadata: Metadata) -> [String: Any] { [:] }
    func updateLocation(_ location: CLLocation, in metadata: Metadata) -> [String: Any] { [:] }
    func removeLocation(from metadata: Metadata) -> [String: Any] { [:] }
    func removeAllMetadata(from metadata: Metadata) -> [String: Any] { [:] }
    func updateMetadata(with batch: [String: Any], in metadata: Metadata) -> [String: Any] { [:] }
}

class MockImageSaveService: ImageSaveServiceProtocol, @unchecked Sendable {
    func editAssetMetadata(
        asset: PHAsset,
        newProperties: [String: Any]
    ) async -> Result<PHAsset, MetaXError> { .failure(.unknown(underlying: nil)) }
    func saveImageAsNewAsset(
        asset: PHAsset,
        newProperties: [String: Any]
    ) async -> Result<PHAsset, MetaXError> { .failure(.unknown(underlying: nil)) }
}

class MockPhotoLibraryService: PhotoLibraryServiceProtocol, @unchecked Sendable {
    func checkAuthorization() async -> Result<Void, MetaXError> { .failure(.unknown(underlying: nil)) }
    func guideToSettings() {}
    func fetchAllPhotos(sortedBy: NSSortDescriptor?) -> PHFetchResult<PHAsset> { fatalError("Not called in tests") }
    func fetchAssets(
        in collection: PHAssetCollection,
        sortedBy: NSSortDescriptor?
    ) -> PHFetchResult<PHAsset> { fatalError("Not called in tests") }
    func fetchSmartAlbums() -> PHFetchResult<PHAssetCollection> { fatalError("Not called in tests") }
    func fetchUserCollections() -> PHFetchResult<PHCollection> { fatalError("Not called in tests") }
    func createAlbumIfNeeded(title: String) async
        -> Result<PHAssetCollection, MetaXError> { .failure(.unknown(underlying: nil)) }
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
