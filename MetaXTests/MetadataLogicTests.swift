import CoreLocation
import Foundation
import ImageIO
@testable import MetaX
import Testing

/// Unit tests for the Metadata model and intermediate modification intent generation.
@Suite("Metadata Model Logic")
struct MetadataLogicTests {

    static let resourceFiles = ["sample.jpg", "sample.png", "sample.heic", "sample.dng"]

    private func fixtureURL(named name: String) -> URL? {
        class BundleLocator {}
        let bundle = Bundle(for: BundleLocator.self)
        return bundle.url(
            forResource: (name as NSString).deletingPathExtension,
            withExtension: (name as NSString).pathExtension
        )
    }

    // MARK: - Update Logic

    @Test("Metadata Update Integrity", arguments: resourceFiles)
    func updateMetadata(fileName: String) throws {
        guard let url = fixtureURL(named: fileName) else { return }
        let metadata = try #require(Metadata(contentsOf: url))
        let testArtist = "Logic Test Artist"

        let intent = metadata.write(batch: [MetadataKeys.artist: testArtist])

        let tiff = intent.fileProperties[MetadataKeys.tiffDict] as? [String: Any]
        #expect(tiff?[MetadataKeys.artist] as? String == testArtist)
    }

    @Test("Metadata Deletion Intent")
    func deleteMetadata() {
        let metadata = Metadata(props: [MetadataKeys.tiffDict: [MetadataKeys.artist: "Exist"]])
        let intent = metadata.write(batch: [MetadataKeys.artist: NSNull()])

        let tiff = intent.fileProperties[MetadataKeys.tiffDict] as? [String: Any]
        #expect(tiff?[MetadataKeys.artist] is NSNull)
    }

    @Test("Live Photo Pairing Protection")
    func livePhotoIDPreservation() {
        let assetID = "PAIRING-ID-123"
        let metadata = Metadata(props: [MetadataKeys.appleDict: ["11": assetID]])
        let intent = metadata.write(batch: [MetadataKeys.artist: "Updated"])

        let apple = intent.fileProperties[MetadataKeys.appleDict] as? [String: Any]
        #expect(apple?["11"] as? String == assetID)
    }

    // MARK: - Deep Audit

    @Test("Intent Structural Audit")
    func metadataIntentDeepStructure() throws {
        let metadata = Metadata(props: [:])
        let loc = CLLocation(latitude: 31.2, longitude: 121.4)

        let intent = metadata.write(batch: [
            MetadataKeys.location: loc,
            MetadataKeys.artist: "New Artist",
        ])

        let gps = try #require(intent.fileProperties[MetadataKeys.gpsDict] as? [String: Any])
        #expect(gps[MetadataKeys.gpsLatitude] as? Double == 31.2)
        #expect(gps[MetadataKeys.gpsLatitudeRef] as? String == "N")

        let iptc = try #require(intent.fileProperties[MetadataKeys.iptcDict] as? [String: Any])
        #expect(iptc[kCGImagePropertyIPTCByline as String] as? String == "New Artist")
    }

    @Test("Physical Attribute Stripping")
    func physicalStripping() {
        let metadata = Metadata(props: [kCGImagePropertyPixelWidth as String: 4000])
        let intent = metadata.write(batch: [MetadataKeys.artist: "Cleaner"])
        #expect(intent.fileProperties[kCGImagePropertyPixelWidth as String] == nil)
    }

    @Test("Clear All Metadata Intent")
    func clearAllMetadataLogic() {
        let metadata = Metadata(props: [MetadataKeys.tiffDict: [MetadataKeys.make: "Apple"]])
        let intent = metadata.deleteAllExceptOrientation()
        let tiff = intent.fileProperties[MetadataKeys.tiffDict] as? [String: Any]
        #expect(tiff?[MetadataKeys.make] == nil)
        #expect(intent.forceReencode == true)
    }

    @Test("UI Presentation Building")
    func uIMetadataBuilding() {
        let metadata = Metadata(props: [MetadataKeys.tiffDict: [MetadataKeys.make: "Apple"]])
        #expect(metadata.metaProps.isEmpty == false)
        let gear = metadata.metaProps.first { $0.section == .gear }
        #expect(gear != nil)
    }
}
