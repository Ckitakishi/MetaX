//
//  Metadata.swift
//  MetaX
//
//  Created by Ckitakishi on 2018/3/25.
//  Copyright © 2018 Yuhan Chen. All rights reserved.
//

import CoreLocation
import Foundation
import ImageIO
import Photos
import UIKit

public enum MetadataKeys {
    static let exifDict = kCGImagePropertyExifDictionary as String
    static let tiffDict = kCGImagePropertyTIFFDictionary as String
    static let gpsDict = kCGImagePropertyGPSDictionary as String

    static let location = "Location"
    static let dateTimeOriginal = kCGImagePropertyExifDateTimeOriginal as String
    static let dateTimeDigitized = kCGImagePropertyExifDateTimeDigitized as String
    static let make = kCGImagePropertyTIFFMake as String
    static let model = kCGImagePropertyTIFFModel as String
    static let software = kCGImagePropertyTIFFSoftware as String
    static let artist = kCGImagePropertyTIFFArtist as String
    static let copyright = kCGImagePropertyTIFFCopyright as String
    static let dateTime = kCGImagePropertyTIFFDateTime as String

    static let lensMake = kCGImagePropertyExifLensMake as String
    static let lensModel = kCGImagePropertyExifLensModel as String
    static let fNumber = kCGImagePropertyExifFNumber as String
    static let exposureTime = kCGImagePropertyExifExposureTime as String
    static let isoSpeedRatings = kCGImagePropertyExifISOSpeedRatings as String
    static let focalLength = kCGImagePropertyExifFocalLength as String
    static let exposureBiasValue = kCGImagePropertyExifExposureBiasValue as String
    static let focalLenIn35mmFilm = kCGImagePropertyExifFocalLenIn35mmFilm as String
    static let exposureProgram = kCGImagePropertyExifExposureProgram as String
    static let meteringMode = kCGImagePropertyExifMeteringMode as String
    static let whiteBalance = kCGImagePropertyExifWhiteBalance as String
    static let flash = kCGImagePropertyExifFlash as String

    // GPS Keys
    static let gpsLatitude = kCGImagePropertyGPSLatitude as String
    static let gpsLatitudeRef = kCGImagePropertyGPSLatitudeRef as String
    static let gpsLongitude = kCGImagePropertyGPSLongitude as String
    static let gpsLongitudeRef = kCGImagePropertyGPSLongitudeRef as String
}

public enum SaveWorkflowMode: Equatable, Sendable {
    case updateOriginal
    case saveAsCopy(deleteOriginal: Bool)
}

public enum MetadataSection: String, Sendable {
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

public struct Metadata: @unchecked Sendable {

    public let sourceProperties: [String: Any]

    /// Categorized metadata properties grouped by section.
    public let metaProps: [(section: MetadataSection, props: [[String: Any]])]

    public let rawGPS: CLLocation?

    public init?(contentsOf url: URL) {
        guard let ciimage = CIImage(contentsOf: url) else {
            return nil
        }
        self.init(ciimage: ciimage)
    }

    public init?(ciimage: CIImage, asset: PHAsset? = nil) {
        self.init(props: ciimage.properties, asset: asset)
    }

    public init?(props: [String: Any], asset: PHAsset? = nil) {
        var sourceProperties = props

        // Priority: PHAsset values overwrite EXIF/GPS if they exist.
        // If PHAsset values are nil, we keep the original EXIF/GPS (Scenario 2-D).
        if let asset = asset {
            // Handle Timestamp
            if let creationDate = asset.creationDate {
                var exifInfo = sourceProperties[MetadataKeys.exifDict] as? [String: Any] ?? [:]
                let dateStr = DateFormatter.yMdHms.string(from: creationDate)
                exifInfo[MetadataKeys.dateTimeOriginal] = dateStr
                exifInfo[MetadataKeys.dateTimeDigitized] = dateStr
                sourceProperties[MetadataKeys.exifDict] = exifInfo
            }

            // Handle Location
            if let location = asset.location {
                sourceProperties[MetadataKeys.gpsDict] = Metadata.makeGpsDictionary(for: location)
            }
        }

        self.sourceProperties = sourceProperties

        guard let path = Bundle.main.path(forResource: "MetadataPlus", ofType: "plist"),
              let groups = NSArray(contentsOfFile: path) as? [[String: Any]]
        else {
            return nil
        }

        var tmpMetaProps: [(section: MetadataSection, props: [[String: Any]])] = []
        var tmpGPSProp: CLLocation?

        let exifInfo = sourceProperties[MetadataKeys.exifDict] as? [String: Any] ?? [:]
        let tiffInfo = sourceProperties[MetadataKeys.tiffDict] as? [String: Any] ?? [:]

        // Extract GPS first for internal use
        if let gpsInfo = sourceProperties[MetadataKeys.gpsDict] as? [String: Any],
           let latitudeRef = gpsInfo[MetadataKeys.gpsLatitudeRef] as? String,
           let latitude = gpsInfo[MetadataKeys.gpsLatitude] as? Double,
           let longitudeRef = gpsInfo[MetadataKeys.gpsLongitudeRef] as? String,
           let longitude = gpsInfo[MetadataKeys.gpsLongitude] as? Double {
            tmpGPSProp = CLLocation(
                latitude: latitudeRef == "N" ? latitude : -latitude,
                longitude: longitudeRef == "E" ? longitude : -longitude
            )
        }
        rawGPS = tmpGPSProp

        for group in groups {
            guard let title = group["Title"] as? String,
                  let section = MetadataSection(rawValue: title),
                  let keys = group["Props"] as? [String] else { continue }

            var groupProps: [[String: Any]] = []

            for key in keys {
                if key == MetadataKeys.location {
                    if let gps = tmpGPSProp {
                        groupProps.append([key: gps])
                    }
                } else if let val = exifInfo[key] {
                    groupProps.append([key: val])
                } else if let val = tiffInfo[key] {
                    groupProps.append([key: val])
                } else if let val = sourceProperties[key] {
                    groupProps.append([key: val])
                }
            }

            if !groupProps.isEmpty {
                tmpMetaProps.append((section: section, props: groupProps))
            }
        }

        metaProps = tmpMetaProps
    }

    var timeStampKey: String {
        MetadataKeys.dateTimeOriginal
    }
}

// MARK: - MetadataLoadEvent

/// Events emitted during the metadata loading process.
enum MetadataLoadEvent: Sendable {
    /// Indicates iCloud download progress (0.0 to 1.0).
    case progress(Double)
    /// Metadata loaded successfully.
    case success(Metadata)
    /// Loading failed with a specific error.
    case failure(MetaXError)
}

// MARK: - MetadataFieldValue

public enum MetadataFieldValue: Sendable {
    case null
    case string(String)
    case double(Double)
    case int(Int)
    case intArray([Int])
    case date(Date)
    case location(CLLocation)

    /// Converts back to `Any` for the metadata service layer.
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

// MARK: - MetadataField

public enum MetadataField: CaseIterable, Sendable {
    case make, model, lensMake, lensModel
    case aperture, shutter, iso, focalLength, focalLength35, exposureBias
    case exposureProgram, meteringMode, whiteBalance, flash
    case artist, copyright
    case pixelWidth, pixelHeight, profileName // Read-only
    case dateTimeOriginal, location // Special handling

    public var key: String {
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

    public var label: String {
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

    public var unit: String? {
        switch self {
        case .focalLength, .focalLength35: return "mm"
        case .exposureBias: return "EV"
        case .shutter: return "s"
        case .pixelWidth, .pixelHeight: return "px"
        default: return nil
        }
    }

    public var keyboardType: UIKeyboardType {
        switch self {
        case .iso, .focalLength35: return .numberPad
        case .aperture, .focalLength, .exposureBias, .shutter: return .decimalPad
        default: return .default
        }
    }

    public var placeholder: String? {
        switch self {
        case .artist: return "Artist name"
        case .copyright: return "Copyright notice"
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

// MARK: Helper

extension Metadata {
    /// {Exif}.DateTimeOriginal
    func writeTimeOriginal(_ date: Date) -> [String: Any] {
        var editableProps = sourceProperties
        var exifInfo = editableProps[MetadataKeys.exifDict] as? [String: Any] ?? [:]
        let dateStr = DateFormatter.yMdHms.string(from: date)
        exifInfo[MetadataKeys.dateTimeOriginal] = dateStr
        exifInfo[MetadataKeys.dateTimeDigitized] = dateStr
        editableProps[MetadataKeys.exifDict] = exifInfo
        return updateTiff(with: editableProps)
    }

    func deleteTimeOriginal() -> [String: Any] {
        var editableProps = sourceProperties
        var exifInfo = editableProps[MetadataKeys.exifDict] as? [String: Any] ?? [:]
        exifInfo.removeValue(forKey: MetadataKeys.dateTimeOriginal)
        exifInfo.removeValue(forKey: MetadataKeys.dateTimeDigitized)
        editableProps[MetadataKeys.exifDict] = exifInfo
        return updateTiff(with: editableProps)
    }

    func writeLocation(_ location: CLLocation) -> [String: Any] {
        var editableProps = sourceProperties
        editableProps[MetadataKeys.gpsDict] = Metadata.makeGpsDictionary(for: location)
        return updateTiff(with: editableProps)
    }

    func deleteGPS() -> [String: Any]? {
        var editableProps = sourceProperties
        if editableProps[MetadataKeys.gpsDict] != nil {
            editableProps.removeValue(forKey: MetadataKeys.gpsDict)
            return updateTiff(with: editableProps)
        }
        return sourceProperties
    }

    func deleteAllExceptOrientation() -> [String: Any]? {
        var editableProps: [String: Any] = [:]
        editableProps["Orientation"] = sourceProperties["Orientation"]
        return updateTiff(with: editableProps)
    }

    func write(batch: [String: Any]) -> [String: Any] {
        var editableProps = sourceProperties

        let tiffKeys = [
            MetadataKeys.make, MetadataKeys.model, MetadataKeys.artist,
            MetadataKeys.copyright, MetadataKeys.software, MetadataKeys.dateTime,
        ]

        var tiffInfo = editableProps[MetadataKeys.tiffDict] as? [String: Any] ?? [:]
        var exifInfo = editableProps[MetadataKeys.exifDict] as? [String: Any] ?? [:]
        var gpsInfo = editableProps[MetadataKeys.gpsDict] as? [String: Any] ?? [:]

        for (key, value) in batch {
            let isRemoval = value is NSNull

            if tiffKeys.contains(key) {
                if isRemoval {
                    tiffInfo.removeValue(forKey: key)
                } else {
                    tiffInfo[key] = value
                }
            } else if key == MetadataKeys.dateTimeOriginal {
                if isRemoval {
                    exifInfo.removeValue(forKey: key)
                    exifInfo.removeValue(forKey: MetadataKeys.dateTimeDigitized)
                } else if let date = value as? Date {
                    let dateStr = DateFormatter.yMdHms.string(from: date)
                    exifInfo[key] = dateStr
                    exifInfo[MetadataKeys.dateTimeDigitized] = dateStr
                }
            } else if key == MetadataKeys.location {
                if isRemoval {
                    gpsInfo = [:]
                } else if let loc = value as? CLLocation {
                    gpsInfo = Metadata.makeGpsDictionary(for: loc)
                }
            } else {
                if isRemoval {
                    exifInfo.removeValue(forKey: key)
                } else {
                    exifInfo[key] = value
                }
            }
        }

        editableProps[MetadataKeys.tiffDict] = tiffInfo
        editableProps[MetadataKeys.exifDict] = exifInfo

        // Ensure GPS dict is updated even if it becomes empty (removal)
        if gpsInfo.isEmpty {
            editableProps.removeValue(forKey: MetadataKeys.gpsDict)
        } else {
            editableProps[MetadataKeys.gpsDict] = gpsInfo
        }

        return updateTiff(with: editableProps)
    }

    static func makeGpsDictionary(for location: CLLocation) -> [String: Any] {
        var dict: [String: Any] = [:]
        let latitude = location.coordinate.latitude
        let longitude = location.coordinate.longitude

        dict[MetadataKeys.gpsLatitudeRef] = latitude < 0 ? "S" : "N"
        dict[MetadataKeys.gpsLatitude] = abs(latitude)

        dict[MetadataKeys.gpsLongitudeRef] = longitude < 0 ? "W" : "E"
        dict[MetadataKeys.gpsLongitude] = abs(longitude)

        return dict
    }

    /// update software infomation
    func updateTiff(with source: [String: Any]) -> [String: Any] {
        var editableProps = source
        var tiffInfo = editableProps[MetadataKeys.tiffDict] as? [String: Any] ?? [:]

        // Only set default if Software is not already provided by user or original data
        if tiffInfo[MetadataKeys.software] == nil {
            tiffInfo[MetadataKeys.software] = "MetaX"
        }

        // Metadata DateTime should be a formatted string, matching the behavior of DateTimeOriginal
        tiffInfo[MetadataKeys.dateTime] = DateFormatter.yMdHms.string(from: Date())

        editableProps[MetadataKeys.tiffDict] = tiffInfo
        return editableProps
    }
}
