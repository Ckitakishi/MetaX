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

    private struct MetadataGroup: Codable {
        let title: String
        let props: [String]

        enum CodingKeys: String, CodingKey {
            case title = "Title"
            case props = "Props"
        }
    }

    private static let metadataGroups: [MetadataGroup] = {
        guard let url = Bundle.main.url(forResource: "MetadataPlus", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let groups = try? PropertyListDecoder().decode([MetadataGroup].self, from: data)
        else {
            return []
        }
        return groups
    }()

    public init?(props: [String: Any], asset: PHAsset? = nil) {
        var sourceProperties = props

        // Priority: PHAsset values overwrite EXIF/GPS if they exist.
        if let asset = asset {
            if let creationDate = asset.creationDate {
                var exifInfo = sourceProperties[MetadataKeys.exifDict] as? [String: Any] ?? [:]
                let dateStr = DateFormatter.yMdHms.string(from: creationDate)
                exifInfo[MetadataKeys.dateTimeOriginal] = dateStr
                exifInfo[MetadataKeys.dateTimeDigitized] = dateStr
                sourceProperties[MetadataKeys.exifDict] = exifInfo
            }
            if let location = asset.location {
                sourceProperties[MetadataKeys.gpsDict] = Metadata.makeGpsDictionary(for: location)
            }
        }

        self.sourceProperties = sourceProperties

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

        for group in Metadata.metadataGroups {
            guard let section = MetadataSection(rawValue: group.title) else { continue }

            var groupProps: [[String: Any]] = []

            for key in group.props {
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

/// Encapsulates a complete metadata update request, specifying both file-level
/// properties and high-level database fields (Location, Creation Date).
struct MetadataUpdateIntent: @unchecked Sendable {
    /// The full dictionary of properties to be written into the image file.
    let fileProperties: [String: Any]

    /// The specific location to be synchronized with the PHAsset database.
    /// If nil, it suggests that the location should be cleared from the database.
    let dbLocation: CLLocation?

    /// The specific date to be synchronized with the PHAsset database.
    /// If nil, the existing asset creation date should be preserved.
    let dbDate: Date?
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
    func writeTimeOriginal(_ date: Date) -> MetadataUpdateIntent {
        var editableProps = sourceProperties
        var exifInfo = editableProps[MetadataKeys.exifDict] as? [String: Any] ?? [:]
        let dateStr = DateFormatter.yMdHms.string(from: date)
        exifInfo[MetadataKeys.dateTimeOriginal] = dateStr
        exifInfo[MetadataKeys.dateTimeDigitized] = dateStr
        editableProps[MetadataKeys.exifDict] = exifInfo
        let finalProps = updateTiff(with: editableProps)
        return MetadataUpdateIntent(fileProperties: finalProps, dbLocation: rawGPS, dbDate: date)
    }

    func deleteTimeOriginal() -> MetadataUpdateIntent {
        var editableProps: [String: Any] = [:]
        var exifInfo: [String: Any] = [:]
        exifInfo[MetadataKeys.dateTimeOriginal] = NSNull()
        exifInfo[MetadataKeys.dateTimeDigitized] = NSNull()
        editableProps[MetadataKeys.exifDict] = exifInfo
        let finalProps = updateTiff(with: editableProps)
        return MetadataUpdateIntent(fileProperties: finalProps, dbLocation: rawGPS, dbDate: nil)
    }

    func writeLocation(_ location: CLLocation) -> MetadataUpdateIntent {
        var editableProps = sourceProperties
        editableProps[MetadataKeys.gpsDict] = Metadata.makeGpsDictionary(for: location)
        let finalProps = updateTiff(with: editableProps)
        return MetadataUpdateIntent(fileProperties: finalProps, dbLocation: location, dbDate: nil)
    }

    func deleteGPS() -> MetadataUpdateIntent {
        var editableProps: [String: Any] = [:]
        editableProps[MetadataKeys.gpsDict] = NSNull()
        let finalProps = updateTiff(with: editableProps)
        return MetadataUpdateIntent(fileProperties: finalProps, dbLocation: nil, dbDate: nil)
    }

    func deleteAllExceptOrientation() -> MetadataUpdateIntent {
        var editableProps: [String: Any] = [:]
        editableProps[MetadataKeys.exifDict] = NSNull()
        editableProps[MetadataKeys.gpsDict] = NSNull()
        editableProps[kCGImagePropertyIPTCDictionary as String] = NSNull()

        var tiffInfo: [String: Any] = [:]
        tiffInfo[MetadataKeys.artist] = NSNull()
        tiffInfo[MetadataKeys.copyright] = NSNull()
        tiffInfo[MetadataKeys.make] = NSNull()
        tiffInfo[MetadataKeys.model] = NSNull()
        editableProps[MetadataKeys.tiffDict] = tiffInfo

        editableProps["Orientation"] = sourceProperties["Orientation"]
        let finalProps = updateTiff(with: editableProps)
        return MetadataUpdateIntent(fileProperties: finalProps, dbLocation: nil, dbDate: nil)
    }

    func write(batch: [String: Any]) -> MetadataUpdateIntent {
        var editableProps: [String: Any] = [:]

        let tiffKeys = [
            MetadataKeys.make, MetadataKeys.model, MetadataKeys.artist,
            MetadataKeys.copyright, MetadataKeys.software, MetadataKeys.dateTime,
        ]

        var tiffInfo: [String: Any] = [:]
        var exifInfo: [String: Any] = [:]
        var gpsInfo: [String: Any]?

        var newDate: Date?
        var newLocation: CLLocation?
        var isLocationCleared = false

        for (key, value) in batch {
            let isRemoval = value is NSNull

            if tiffKeys.contains(key) {
                tiffInfo[key] = value
            } else if key == MetadataKeys.dateTimeOriginal {
                if isRemoval {
                    exifInfo[key] = NSNull()
                    exifInfo[MetadataKeys.dateTimeDigitized] = NSNull()
                } else if let date = value as? Date {
                    let dateStr = DateFormatter.yMdHms.string(from: date)
                    exifInfo[key] = dateStr
                    exifInfo[MetadataKeys.dateTimeDigitized] = dateStr
                    newDate = date
                }
            } else if key == MetadataKeys.location {
                if isRemoval {
                    gpsInfo = nil // Will set to NSNull below
                    isLocationCleared = true
                } else if let loc = value as? CLLocation {
                    gpsInfo = Metadata.makeGpsDictionary(for: loc)
                    newLocation = loc
                }
            } else {
                exifInfo[key] = value
            }
        }

        if !tiffInfo.isEmpty {
            editableProps[MetadataKeys.tiffDict] = tiffInfo
        }
        if !exifInfo.isEmpty {
            editableProps[MetadataKeys.exifDict] = exifInfo
        }

        if let gps = gpsInfo {
            editableProps[MetadataKeys.gpsDict] = gps
        } else if batch.keys.contains(MetadataKeys.location) {
            editableProps[MetadataKeys.gpsDict] = NSNull()
        }

        let finalProps = updateTiff(with: editableProps)
        let finalLocation = isLocationCleared ? nil : (newLocation ?? rawGPS)

        return MetadataUpdateIntent(
            fileProperties: finalProps,
            dbLocation: finalLocation,
            dbDate: newDate
        )
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
