//
//  MetadataEditorModels.swift
//  MetaX
//
//  Created by Yuhan Chen on 2026/02/22.
//  Copyright © 2026 Yuhan Chen. All rights reserved.
//

import CoreLocation
import UIKit

// MARK: - Metadata Section

/// UI grouping for metadata fields.
enum MetadataSection: String, Sendable {
    case basicInfo = "BASIC INFO"
    case gear = "GEAR"
    case exposure = "EXPOSURE"
    case fileInfo = "FILE INFO"
    case copyright = "COPYRIGHT"

    var localizedTitle: String {
        switch self {
        case .basicInfo: return String(localized: .editGroupBasicInfo)
        case .gear: return String(localized: .editGroupGear)
        case .exposure: return String(localized: .shooting)
        case .fileInfo: return String(localized: .editGroupFileInfo)
        case .copyright: return String(localized: .editGroupCopyright)
        }
    }
}

// MARK: - Metadata Load Event

enum MetadataLoadEvent: Sendable {
    case progress(Double)
    case success(Metadata)
    case failure(MetaXError)
}

// MARK: - Metadata Field Value

/// Container for transferring metadata values between layers.
enum MetadataFieldValue: Sendable {
    case null
    case string(String)
    case double(Double)
    case int(Int)
    case intArray([Int])
    case date(Date)
    case location(CLLocation)

    /// Converts back to Any for low-level ImageIO operations.
    var rawValue: Any {
        switch self {
        case .null: return NSNull()
        case let .string(s): return s
        case let .double(d): return d
        case let .int(i): return i
        case let .intArray(a): return a
        case let .date(d): return d
        case let .location(l): return l
        }
    }
}

// MARK: - Metadata Field

/// Configuration for individual metadata fields in the UI.
enum MetadataField: CaseIterable, Sendable {
    case make, model, lensMake, lensModel
    case aperture, shutter, iso, focalLength, focalLength35, exposureBias
    case exposureProgram, meteringMode, whiteBalance, flash
    case artist, copyright
    case pixelWidth, pixelHeight, profileName // Read-only
    case dateTimeOriginal, location // Special handling

    var key: String {
        switch self {
        case .make: return MetadataKeys.make
        case .model: return MetadataKeys.model
        case .lensMake: return MetadataKeys.lensMake
        case .lensModel: return MetadataKeys.lensModel
        case .aperture: return MetadataKeys.fNumber
        case .shutter: return MetadataKeys.exposureTime
        case .iso: return MetadataKeys.isoSpeedRatings
        case .focalLength: return MetadataKeys.focalLength
        case .focalLength35: return MetadataKeys.focalLenIn35mmFilm
        case .exposureBias: return MetadataKeys.exposureBiasValue
        case .exposureProgram: return MetadataKeys.exposureProgram
        case .meteringMode: return MetadataKeys.meteringMode
        case .whiteBalance: return MetadataKeys.whiteBalance
        case .flash: return MetadataKeys.flash
        case .artist: return MetadataKeys.artist
        case .copyright: return MetadataKeys.copyright
        case .pixelWidth: return "PixelWidth"
        case .pixelHeight: return "PixelHeight"
        case .profileName: return "ProfileName"
        case .dateTimeOriginal: return MetadataKeys.dateTimeOriginal
        case .location: return MetadataKeys.location
        }
    }

    var label: String {
        switch self {
        case .make: return String(localized: .make)
        case .model: return String(localized: .model)
        case .lensMake: return String(localized: .lensMake)
        case .lensModel: return String(localized: .lensModel)
        case .aperture: return String(localized: .fnumber)
        case .shutter: return String(localized: .exposureTime)
        case .iso: return String(localized: .isospeedRatings)
        case .focalLength: return String(localized: .focalLength)
        case .focalLength35: return String(localized: .focalLenIn35MmFilm)
        case .exposureBias: return String(localized: .exposureBiasValue)
        case .exposureProgram: return String(localized: .exposureProgram)
        case .meteringMode: return String(localized: .meteringMode)
        case .whiteBalance: return String(localized: .whiteBalance)
        case .flash: return String(localized: .flash)
        case .artist: return String(localized: .artist)
        case .copyright: return String(localized: .copyright)
        case .pixelWidth: return String(localized: .pixelWidth)
        case .pixelHeight: return String(localized: .pixelHeight)
        case .profileName: return String(localized: .profileName)
        case .dateTimeOriginal: return String(localized: .viewAddDate)
        case .location: return String(localized: .viewAddLocation)
        }
    }

    var unit: String? {
        switch self {
        case .focalLength, .focalLength35: return "mm"
        case .exposureBias: return "EV"
        case .shutter: return "s"
        case .pixelWidth, .pixelHeight: return "px"
        default: return nil
        }
    }

    var keyboardType: UIKeyboardType {
        switch self {
        case .iso, .focalLength35: return .numberPad
        case .aperture, .focalLength, .exposureBias, .shutter: return .decimalPad
        default: return .default
        }
    }

    var placeholder: String? {
        switch self {
        case .artist: return "e.g. \(AppConstants.appName)"
        case .copyright: return "e.g. © 2026 \(AppConstants.appName)"
        case .make, .lensMake: return "SONY"
        case .model: return "ILCE-7C"
        case .lensModel: return "FE 50mm F1.4 GM"
        case .aperture: return "e.g. 2.8"
        case .shutter: return "e.g. 1/125"
        case .iso: return "e.g. 400"
        case .focalLength: return "e.g. 35"
        case .exposureBias: return "e.g. 1.3"
        case .focalLength35: return "e.g. 28"
        default: return nil
        }
    }
}
