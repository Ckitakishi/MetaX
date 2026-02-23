//
//  MetadataEditTests.swift
//  MetaXTests
//

import CoreLocation
import Foundation
import ImageIO
@testable import MetaX
import Testing

@Suite("Metadata Editor Logic Tests")
@MainActor
struct MetadataEditTests {

    let viewModel: MetadataEditViewModel

    init() {
        let initialProps: [String: Any] = [
            "{TIFF}": [
                "Make": "Apple",
                "Model": "iPhone 15 Pro",
            ],
            "{Exif}": [
                "ExposureTime": 0.008,
                "FNumber": 1.8,
                "ISOSpeedRatings": [100],
            ],
        ]
        let metadata = Metadata(props: initialProps)
        viewModel = MetadataEditViewModel(metadata: metadata)
    }

    // MARK: - Happy Path: Input Validation

    @Test("Integer Input (ISO/35mm)", arguments: [
        ("", "400", true),
        ("400", "0", true),
        ("400", "a", false),
        ("400", ".", false),
        ("", "-100", false),
    ])
    func integerValidation(current: String, replacement: String, expected: Bool) {
        let range = NSRange(location: current.count, length: 0)
        #expect(viewModel
            .validateInput(currentText: current, range: range, replacementString: replacement, for: .iso) == expected)
    }

    @Test("Decimal Input (Aperture/Focal)", arguments: [
        ("", "2.8", true),
        ("2.", "8", true),
        ("2.8", ".", false),
        ("2.8", "f", false),
        ("", ".5", true)
    ])
    func decimalValidation(current: String, replacement: String, expected: Bool) {
        let range = NSRange(location: current.count, length: 0)
        #expect(viewModel.validateInput(
            currentText: current,
            range: range,
            replacementString: replacement,
            for: .aperture
        ) == expected)
    }

    @Test("Shutter Speed Input", arguments: [
        ("", "1/125", true),
        ("0", ".5", true),
        ("1/", "0.5", true),
        ("1/125", "/", false),
        ("0.5", ".", false)
    ])
    func shutterSpeedValidation(current: String, replacement: String, expected: Bool) {
        let range = NSRange(location: current.count, length: 0)
        #expect(viewModel.validateInput(
            currentText: current,
            range: range,
            replacementString: replacement,
            for: .shutter
        ) == expected)
    }

    @Test("Global Length Constraints", arguments: [
        (MetadataField.make, String(repeating: "A", count: 65), false), // Max 64
        (MetadataField.artist, String(repeating: "A", count: 65), false), // Max 64
        (MetadataField.copyright, String(repeating: "A", count: 201), false), // Max 200
        (MetadataField.copyright, String(repeating: "A", count: 199), true),
    ])
    func lengthConstraints(type: MetadataField, input: String, expected: Bool) {
        #expect(viewModel.validateInput(
            currentText: "",
            range: NSRange(location: 0, length: 0),
            replacementString: input,
            for: type
        ) == expected)
    }

    // MARK: - Business Logic & Conversion

    @Test("Modification tracking (Dirty state detection)")
    func modificationTracking() {
        #expect(viewModel.isModified == false)
        viewModel.updateValue("Sony", for: .make)
        #expect(viewModel.isModified == true)
        viewModel.updateValue("Apple", for: .make)
        #expect(viewModel.isModified == false)
    }

    @Test("Shutter speed conversion (String to Double)")
    func shutterSpeedConversion() {
        viewModel.updateValue("1/1000", for: .shutter)
        #expect(viewModel.getPreparedFields()[.shutter]?.rawValue as? Double == 0.001)

        viewModel.updateValue("0.5", for: .shutter)
        #expect(viewModel.getPreparedFields()[.shutter]?.rawValue as? Double == 0.5)
    }

    @Test("ISO numeric extraction as Array")
    func isoArrayFormatting() {
        viewModel.updateValue("400", for: .iso)
        #expect(viewModel.getPreparedFields()[.iso]?.rawValue as? [Int] == [400])
    }

    @Test("Exposure Bias Input (signed decimals)", arguments: [
        ("", "+", true),
        ("", "-", true),
        ("+1", ".5", true),
        ("+1.5", "+", false), // second sign character
        ("1.5", ".", false), // second decimal point
        ("1", "a", false), // invalid character
        ("1.5", "-", false), // sign not at start of string
    ])
    func exposureBiasValidation(current: String, replacement: String, expected: Bool) {
        let range = NSRange(location: current.count, length: 0)
        #expect(viewModel.validateInput(
            currentText: current,
            range: range,
            replacementString: replacement,
            for: .exposureBias
        ) == expected)
    }

    @Test("Empty string fields produce NSNull in prepared output")
    func preparedFieldsNullCoercion() {
        viewModel.updateValue("", for: .make)
        viewModel.updateValue("", for: .aperture)
        viewModel.updateValue("not_a_number", for: .shutter)

        let prepared = viewModel.getPreparedFields()

        #expect(prepared[.make]?.rawValue is NSNull)
        #expect(prepared[.aperture]?.rawValue is NSNull)
        #expect(prepared[.shutter]?.rawValue is NSNull)
    }

    @Test("Metadata: Nuclear Clear preserves structural keys and omits non-structural dicts")
    func nuclearClearTest() {
        // Source mixes structural top-level keys, a structural Exif key, and junk dicts.
        let source: [String: Any] = [
            kCGImagePropertyPixelWidth as String: 4000,
            kCGImagePropertyOrientation as String: 1,
            "{Exif}": ["FocalLength": 35.0, kCGImagePropertyExifColorSpace as String: 1],
            "{XMP}": ["dc:creator": "Me"],
            "{StrangeManufacturerDict}": ["SecretID": "12345"],
        ]

        let intent = Metadata(props: source).deleteAllExceptOrientation()
        let props = intent.fileProperties

        // Structural top-level keys must be preserved (positive extraction, not NSNull-marked).
        #expect(props[kCGImagePropertyPixelWidth as String] as? Int == 4000)
        #expect(props[kCGImagePropertyOrientation as String] as? Int == 1)

        // Unknown / non-structural dicts must be absent — not NSNull.
        // forceReencode=true means CGImageDestinationAddImage is used, so absent keys are never written.
        #expect(props["{XMP}"] == nil)
        #expect(props["{StrangeManufacturerDict}"] == nil)

        // Structural Exif keys (e.g. ColorSpace) must survive; non-structural Exif keys must be dropped.
        let exif = props[MetadataKeys.exifDict] as? [String: Any]
        #expect(exif?[kCGImagePropertyExifColorSpace as String] != nil)
        #expect(exif?["FocalLength"] == nil)

        #expect(intent.forceReencode == true)
    }

    // MARK: - Differential Update Tests

    @Test("Differential update: Only returns modified fields")
    func differentialUpdate() {
        // Initial state: nothing should be in prepared fields
        #expect(viewModel.getPreparedFields().isEmpty)

        // Modify one field
        viewModel.updateValue("New Artist", for: .artist)
        let prepared = viewModel.getPreparedFields()

        #expect(prepared.count == 1)
        #expect(prepared[.artist]?.rawValue as? String == "New Artist")
        #expect(prepared[.make] == nil) // Unmodified field should NOT be present
    }

    @Test("Differential update: Resetting to initial removes from prepared")
    func differentialUpdateReset() {
        viewModel.updateValue("Sony", for: .make)
        #expect(viewModel.getPreparedFields().count == 1)

        // Reset to initial "Apple"
        viewModel.updateValue("Apple", for: .make)
        #expect(viewModel.getPreparedFields().isEmpty)
    }

    // MARK: - Model Logic Tests

    @Test("Metadata: deleteAllExceptOrientation uses forceReencode and omits non-structural dicts")
    func deleteAllMetadataLogic() {
        // deleteAllExceptOrientation now uses a positive extraction approach:
        // intent.fileProperties only contains structural keys to KEEP.
        // Non-structural dicts are simply absent (not NSNull-marked) because
        // forceReencode=true drives CGImageDestinationAddImage, which writes
        // only what's in the dict — absent keys are never written to the output.
        // Note: avoid using names that appear in MetadataSchema.structuralKeys (e.g. "DPIWidth",
        // "Gamma") because extractCleanMetadata matches key names recursively across all levels.
        let source: [String: Any] = [
            "{Exif}": ["ExposureTime": 0.01, "FNumber": 1.8],
            "{GPS}": ["Latitude": 35.0, "Longitude": 139.0],
            "{PNG}": ["Title": "test"],
            "{XMP}": ["creator": "Me"],
        ]

        let metadata = Metadata(props: source)
        let intent = metadata.deleteAllExceptOrientation()
        let props = intent.fileProperties

        // Non-structural dicts must be absent (not NSNull) from fileProperties.
        #expect(props["{Exif}"] == nil)
        #expect(props["{GPS}"] == nil)
        #expect(props["{PNG}"] == nil)
        #expect(props["{XMP}"] == nil)

        // forceReencode must be true so the save layer uses CGImageDestinationAddImage,
        // not AddImageFromSource (which would need NSNull markers).
        #expect(intent.forceReencode == true)
    }
}
