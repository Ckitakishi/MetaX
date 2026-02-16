//
//  MetadataEditTests.swift
//  MetaXTests
//

import CoreLocation
import Foundation
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
        let metadata = Metadata(props: initialProps)!
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
        #expect(viewModel.getPreparedFields()[.shutter] as? Double == 0.001)

        viewModel.updateValue("0.5", for: .shutter)
        #expect(viewModel.getPreparedFields()[.shutter] as? Double == 0.5)
    }

    @Test("ISO numeric extraction as Array")
    func isoArrayFormatting() {
        viewModel.updateValue("400", for: .iso)
        #expect(viewModel.getPreparedFields()[.iso] as? [Int] == [400])
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

        #expect(prepared[.make] is NSNull)
        #expect(prepared[.aperture] is NSNull)
        #expect(prepared[.shutter] is NSNull)
    }
}
