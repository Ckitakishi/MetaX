@testable import MetaX
import Photos
import Testing
import UIKit

/// Integration and logic tests for the image saving engine and persistence policies.
@Suite("Image Save Service Integration")
struct ImageSaveServiceTests {

    static let resourceFiles = ["sample.jpg", "sample.png", "sample.heic", "sample.dng"]

    private func fixtureURL(named name: String) -> URL? {
        class BundleLocator {}
        let bundle = Bundle(for: BundleLocator.self)
        return bundle.url(
            forResource: (name as NSString).deletingPathExtension,
            withExtension: (name as NSString).pathExtension
        ) ??
            bundle.url(
                forResource: (name as NSString).deletingPathExtension,
                withExtension: (name as NSString).pathExtension,
                subdirectory: "Resources"
            )
    }

    // MARK: - Integration Tests

    @Test("Physical File Save Workflow", arguments: resourceFiles)
    func saveWorkflow(fileName: String) throws {
        guard let url = fixtureURL(named: fileName) else { return }
        let service = ImageSaveService(photoLibraryService: StubPhotoLibraryService())
        let sourceMetadata = try #require(Metadata(contentsOf: url))
        let testArtist = "Persistence Test \(UUID().uuidString)"

        var batch: [String: Any] = [MetadataKeys.artist: testArtist]
        if fileName.lowercased().hasSuffix("dng") == false {
            batch[kCGImagePropertyPixelWidth as String] = 9999
        }

        let intent = sourceMetadata.write(batch: batch)
        let destinationURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "test_output_\(UUID().uuidString).\(fileName.lowercased().hasSuffix("dng") ? "JPG" : (fileName as NSString).pathExtension)"
            )
        defer { try? FileManager.default.removeItem(at: destinationURL) }

        let success = service.writeModifiedImage(sourceURL: url, destinationURL: destinationURL, intent: intent)
        #expect(success == true)

        let outputSource = try #require(CGImageSourceCreateWithURL(destinationURL as CFURL, nil))
        let outputProps = try #require(CGImageSourceCopyPropertiesAtIndex(outputSource, 0, nil) as? [String: Any])

        #expect((outputProps[MetadataKeys.tiffDict] as? [String: Any])?[MetadataKeys.artist] as? String == testArtist)
        #expect(outputProps[kCGImagePropertyPixelWidth as String] as? Int != 9999)
    }

    @Test("System Contract: Live Photo Identity", arguments: ["sample.heic", "sample.jpg"])
    func livePhotoSystemContract(fileName: String) throws {
        guard let url = fixtureURL(named: fileName) else { return }
        let service = ImageSaveService(photoLibraryService: StubPhotoLibraryService())

        let assetID = UUID().uuidString
        let tempDir = FileManager.default.temporaryDirectory

        // 1. Setup: Create a REAL source file that already contains a Live Photo ID.
        let initialSourceURL = tempDir.appendingPathComponent("pre_contract_\(fileName)")
        let sourceProps = [MetadataKeys.appleDict: ["11": assetID]]

        let initialSource = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        let typeID = try #require(CGImageSourceGetType(initialSource))
        let initialDest = try #require(CGImageDestinationCreateWithURL(initialSourceURL as CFURL, typeID, 1, nil))
        CGImageDestinationAddImageFromSource(initialDest, initialSource, 0, sourceProps as CFDictionary)
        CGImageDestinationFinalize(initialDest)
        defer { try? FileManager.default.removeItem(at: initialSourceURL) }

        // 2. Act: Use MetaX to update this "Live Photo"
        let metadata = try #require(Metadata(contentsOf: initialSourceURL))
        let intent = metadata.write(batch: [MetadataKeys.artist: "Contract Test"])

        let finalDestURL = tempDir.appendingPathComponent("post_contract_\(fileName)")
        defer { try? FileManager.default.removeItem(at: finalDestURL) }

        #expect(service.writeModifiedImage(sourceURL: initialSourceURL, destinationURL: finalDestURL, intent: intent))

        // 3. Assert: Byte-level audit of the resulting binary
        let outputSource = try #require(CGImageSourceCreateWithURL(finalDestURL as CFURL, nil))
        let outputProps = try #require(CGImageSourceCopyPropertiesAtIndex(outputSource, 0, nil) as? [String: Any])
        let apple = try #require(outputProps[MetadataKeys.appleDict] as? [String: Any])
        #expect(apple["11"] as? String == assetID)
    }

    @Test("Image Renderability Verification", arguments: resourceFiles)
    func imageRenderability(fileName: String) throws {
        guard let url = fixtureURL(named: fileName) else { return }
        let service = ImageSaveService(photoLibraryService: StubPhotoLibraryService())
        let metadata = try #require(Metadata(contentsOf: url))
        let intent = metadata.write(batch: [MetadataKeys.make: "MetaX Render Test"])

        // Follow format policy: RAW (DNG) must be output as JPG
        let isRAW = fileName.lowercased().hasSuffix("dng")
        let ext = isRAW ? "JPG" : (fileName as NSString).pathExtension
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("render_test_\(UUID().uuidString).\(ext)")
        defer { try? FileManager.default.removeItem(at: dest) }

        _ = service.writeModifiedImage(sourceURL: url, destinationURL: dest, intent: intent)
        let image = CIImage(contentsOf: dest)
        #expect(image != nil)
        #expect((image?.extent.width ?? 0) > 0)
    }

    @Test("Color Space Preservation: Display P3", arguments: ["sample.png", "sample.jpg"])
    func colorSpacePreservation(fileName: String) throws {
        guard let url = fixtureURL(named: fileName) else { return }
        let service = ImageSaveService(photoLibraryService: StubPhotoLibraryService())

        // 1. Setup: Load original properties
        let sourceMetadata = try #require(Metadata(contentsOf: url))
        let originalProfile = sourceMetadata.sourceProperties[kCGImagePropertyProfileName as String] as? String

        // Use the existing file's color space but force a re-encode
        let intent = MetadataUpdateIntent(
            fileProperties: sourceMetadata.write(batch: [:]).fileProperties,
            forceReencode: true
        )

        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("color_\(UUID().uuidString).\((fileName as NSString).pathExtension)")
        defer { try? FileManager.default.removeItem(at: dest) }

        // 2. Act: Write
        #expect(service.writeModifiedImage(sourceURL: url, destinationURL: dest, intent: intent))

        // 3. Assert: Verify the profile survived
        let outputSource = try #require(CGImageSourceCreateWithURL(dest as CFURL, nil))
        let outputProps = try #require(CGImageSourceCopyPropertiesAtIndex(outputSource, 0, nil) as? [String: Any])

        if let originalProfile = originalProfile {
            #expect(outputProps[kCGImagePropertyProfileName as String] as? String == originalProfile)
        } else {
            // If the sample didn't have a profile, ImageIO usually defaults to sRGB
            #expect(outputProps[kCGImagePropertyProfileName as String] != nil)
        }
    }

    // MARK: - Logic Tests

    @Test("Sync Decision Algorithm")
    func metadataSyncLogic() {
        let date1 = Date(timeIntervalSince1970: 1000)
        #expect(MetadataSyncLogic.shouldSyncDate(date1, with: date1.addingTimeInterval(0.5)) == false)
        #expect(MetadataSyncLogic.shouldSyncDate(date1, with: date1.addingTimeInterval(5.0)) == true)
        #expect(MetadataSyncLogic.shouldSyncDate(nil, with: date1) == false)
        #expect(MetadataSyncLogic.shouldSyncDate(date1, with: nil) == true)

        let tokyo = CLLocation(latitude: 35.6895, longitude: 139.6917)
        let tokyoSlightlyOff = CLLocation(latitude: 35.68950001, longitude: 139.69170001)
        let shanghai = CLLocation(latitude: 31.2304, longitude: 121.4737)
        #expect(MetadataSyncLogic.shouldSyncLocation(tokyo, with: tokyoSlightlyOff) == false)
        #expect(MetadataSyncLogic.shouldSyncLocation(tokyo, with: shanghai) == true)
        #expect(MetadataSyncLogic.shouldSyncLocation(nil, with: tokyo) == true)
        #expect(MetadataSyncLogic.shouldSyncLocation(nil, with: nil) == false)
    }

    @Test("Recursive NSNull Stripping")
    func testStripNulls() {
        let service = ImageSaveService(photoLibraryService: StubPhotoLibraryService())
        let dirtyDict: [String: Any] = ["Keep": "V", "Drop": NSNull(), "Nested": ["SubDrop": NSNull()]]
        let cleaned = service.stripNulls(from: dirtyDict)
        #expect(cleaned["Keep"] != nil)
        #expect(cleaned["Drop"] == nil)
        #expect(cleaned["Nested"] == nil)
    }

    @Test("Format Policy Enforcement")
    func savePolicy() {
        let rawPolicy = SavePolicy(sourceUTType: .rawImage, isLivePhoto: false, destinationURL: nil)
        #expect(rawPolicy.targetUTType == .jpeg)
    }
}

// MARK: - Stubs

private final class StubPhotoLibraryService: PhotoLibraryServiceProtocol, @unchecked Sendable {
    func checkAuthorization() async -> Result<Void, MetaXError> { .success(()) }
    func guideToSettings() {}
    func fetchAllPhotos(sortedBy: MetaX.PhotoSortOrder) -> PHFetchResult<PHAsset> { fatalError() }
    func fetchAssets(
        in collection: PHAssetCollection,
        sortedBy: MetaX.PhotoSortOrder
    ) -> PHFetchResult<PHAsset> { fatalError() }
    func fetchSmartAlbums() -> PHFetchResult<PHAssetCollection> { fatalError() }
    func fetchUserCollections() -> PHFetchResult<PHCollection> { fatalError() }
    func createAlbumIfNeeded(title: String) async
        -> Result<PHAssetCollection, MetaXError> { .failure(.imageSave(.albumCreationFailed)) }
    func albumExists(title: String) -> Bool { false }
    func cancelImageRequest(_ requestID: PHImageRequestID) {}
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
    func deleteAsset(_ asset: PHAsset) async -> Result<Void, MetaXError> { .success(()) }
    func revertAsset(_ asset: PHAsset) async -> Result<Void, MetaXError> { .success(()) }
    func updateAssetProperties(
        _ asset: PHAsset,
        date: Date?,
        location: CLLocation?
    ) async -> Result<Void, MetaXError> { .success(()) }
    func registerChangeObserver(_ observer: PHPhotoLibraryChangeObserver) {}
    func unregisterChangeObserver(_ observer: PHPhotoLibraryChangeObserver) {}
}
