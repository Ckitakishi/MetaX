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

@Suite("Detail Info Logic Tests")
struct DetailInfoViewModelTests {

    let viewModel: DetailInfoViewModel

    @MainActor
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

        // 1. Difference < 1s (0.5s) -> No sync
        #expect(MetadataSyncLogic.shouldSyncDate(now.addingTimeInterval(0.5), with: now) == false)

        // 2. Difference > 1s (1.5s) -> Sync
        #expect(MetadataSyncLogic.shouldSyncDate(now.addingTimeInterval(1.5), with: now) == true)

        // 3. New date vs nil current -> Sync
        #expect(MetadataSyncLogic.shouldSyncDate(now, with: nil as Date?) == true)

        // 4. Nil new date -> No sync
        #expect(MetadataSyncLogic.shouldSyncDate(nil as Date?, with: now) == false)
    }

    @Test("Sync decision: Location tolerance")
    func locationSyncDecision() {
        let loc1 = CLLocation(latitude: 35.0, longitude: 139.0)

        // 1. Very small difference (same location roughly) -> No sync
        let locSmallDiff = CLLocation(latitude: 35.000001, longitude: 139.000001)
        #expect(MetadataSyncLogic.shouldSyncLocation(locSmallDiff, with: loc1) == false)

        // 2. Significant difference -> Sync
        let locBigDiff = CLLocation(latitude: 35.1, longitude: 139.1)
        #expect(MetadataSyncLogic.shouldSyncLocation(locBigDiff, with: loc1) == true)

        // 3. New location vs nil current -> Sync
        #expect(MetadataSyncLogic.shouldSyncLocation(loc1, with: nil as CLLocation?) == true)

        // 4. Nil new location vs existing current (Deletion) -> Sync
        #expect(MetadataSyncLogic.shouldSyncLocation(nil as CLLocation?, with: loc1) == true)
    }
}

class MockMetadataService: MetadataServiceProtocol, @unchecked Sendable {
    func loadMetadataEvents(from asset: PHAsset) -> AsyncStream<MetadataLoadEvent> { AsyncStream { $0.finish() } }
    func updateTimestamp(_ date: Date, in metadata: Metadata) -> MetadataUpdateIntent {
        MetadataUpdateIntent(fileProperties: [:], dbLocation: nil, dbDate: date)
    }

    func removeTimestamp(from metadata: Metadata) -> MetadataUpdateIntent {
        MetadataUpdateIntent(fileProperties: [:], dbLocation: nil, dbDate: nil)
    }

    func updateLocation(_ location: CLLocation, in metadata: Metadata) -> MetadataUpdateIntent {
        MetadataUpdateIntent(fileProperties: [:], dbLocation: location, dbDate: nil)
    }

    func removeLocation(from metadata: Metadata) -> MetadataUpdateIntent {
        MetadataUpdateIntent(fileProperties: [:], dbLocation: nil, dbDate: nil)
    }

    func removeAllMetadata(from metadata: Metadata) -> MetadataUpdateIntent {
        MetadataUpdateIntent(fileProperties: [:], dbLocation: nil, dbDate: nil)
    }

    func updateMetadata(with batch: [String: Any], in metadata: Metadata) -> MetadataUpdateIntent {
        MetadataUpdateIntent(fileProperties: [:], dbLocation: nil, dbDate: nil)
    }
}

class MockImageSaveService: ImageSaveServiceProtocol, @unchecked Sendable {
    func editAssetMetadata(
        asset: PHAsset,
        intent: MetadataUpdateIntent
    ) async -> Result<PHAsset, MetaXError> { .failure(.unknown(underlying: nil)) }
    func saveImageAsNewAsset(
        asset: PHAsset,
        intent: MetadataUpdateIntent
    ) async -> Result<PHAsset, MetaXError> { .failure(.unknown(underlying: nil)) }
    func applyMetadataIntent(
        _ intent: MetadataUpdateIntent,
        to asset: PHAsset,
        mode: SaveWorkflowMode
    ) async -> Result<PHAsset, MetaXError> { .failure(.unknown(underlying: nil)) }
}

class MockPhotoLibraryService: PhotoLibraryServiceProtocol, @unchecked Sendable {
    func checkAuthorization() async -> Result<Void, MetaXError> { .failure(.unknown(underlying: nil)) }
    func guideToSettings() {}
    func fetchAllPhotos(sortedBy: PhotoSortOrder) -> PHFetchResult<PHAsset> { fatalError("Not called in tests") }
    func fetchAssets(
        in collection: PHAssetCollection,
        sortedBy: PhotoSortOrder
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
