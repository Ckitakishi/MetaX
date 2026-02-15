//
//  MetadataEditTests.swift
//  MetaXTests
//
//  Created by Yuhan Chen on 2026/02/11.
//  Copyright © 2026 Yuhan Chen. All rights reserved.
//

import Foundation
@testable import MetaX
import Testing

struct MetadataEditTests {

    let viewModel = MetadataEditViewModel()

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
        ("0.5", ".", false),
        ("1/125", "s", false)
    ])
    func shutterSpeedValidation(current: String, replacement: String, expected: Bool) {
        let range = NSRange(location: current.count, length: 0)
        #expect(viewModel.validateInput(
            currentText: current,
            range: range,
            replacementString: replacement,
            for: .shutterSpeed
        ) == expected)
    }

    @Test("Exposure Bias Input", arguments: [
        ("", "+1.3", true),
        ("", "-0.7", true),
        ("1.3", "+", false), // Sign must be at start
        ("1.3", "-", false), // Sign must be at start
        ("+1.", ".", false), // Double decimal
        ("0", ".3", true),
        ("", "−0.7", false), // Unicode minus U+2212 is rejected; use ASCII toggle buttons
        ("+", "-", false) // Two signs
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

    @Test("Global Constraints", arguments: [
        (MetadataFieldType.aperture, "2.8.8", false),
        (MetadataFieldType.iso, "abc", false),
        (MetadataFieldType.gear, "Short text", true),
        (MetadataFieldType.gear, String(repeating: "A", count: 65), false), // Max 64
        (MetadataFieldType.artist, String(repeating: "A", count: 65), false), // Max 64
        (MetadataFieldType.copyright, String(repeating: "A", count: 201), false), // Max 200
        (MetadataFieldType.copyright, String(repeating: "A", count: 199), true),
        (MetadataFieldType.iso, "12345678901", false) // Max 10
    ])
    func globalConstraints(type: MetadataFieldType, input: String, expected: Bool) {
        let result = viewModel.validateInput(
            currentText: "",
            range: NSRange(location: 0, length: 0),
            replacementString: input,
            for: type
        )
        #expect(result == expected)
    }
}
