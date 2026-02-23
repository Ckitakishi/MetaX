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

// MARK: - Metadata Keys & Constants

public enum MetadataKeys {
    // Dictionary Containers
    static let exifDict = kCGImagePropertyExifDictionary as String
    static let tiffDict = kCGImagePropertyTIFFDictionary as String
    static let gpsDict = kCGImagePropertyGPSDictionary as String
    static let iptcDict = kCGImagePropertyIPTCDictionary as String
    static let pngDict = kCGImagePropertyPNGDictionary as String
    static let appleDict = kCGImagePropertyMakerAppleDictionary as String
    static let iccProfile = "{ICCProfile}"

    // TIFF Properties
    static let make = kCGImagePropertyTIFFMake as String
    static let model = kCGImagePropertyTIFFModel as String
    static let software = kCGImagePropertyTIFFSoftware as String
    static let artist = kCGImagePropertyTIFFArtist as String
    static let copyright = kCGImagePropertyTIFFCopyright as String
    static let dateTime = kCGImagePropertyTIFFDateTime as String

    // IPTC Properties
    static let iptcByline = kCGImagePropertyIPTCByline as String
    static let iptcCopyright = kCGImagePropertyIPTCCopyrightNotice as String

    // EXIF Properties
    static let dateTimeOriginal = kCGImagePropertyExifDateTimeOriginal as String
    static let dateTimeDigitized = kCGImagePropertyExifDateTimeDigitized as String
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

    // GPS Properties
    static let gpsLatitude = kCGImagePropertyGPSLatitude as String
    static let gpsLatitudeRef = kCGImagePropertyGPSLatitudeRef as String
    static let gpsLongitude = kCGImagePropertyGPSLongitude as String
    static let gpsLongitudeRef = kCGImagePropertyGPSLongitudeRef as String

    static let location = "Location"
}

public enum SaveWorkflowMode: Equatable, Sendable {
    case updateOriginal
    case saveAsCopy(deleteOriginal: Bool)
}

// MARK: - Metadata Schema & Mapping

private enum MetadataContainer {
    case topLevel, exif, tiff, gps, iptc
}

private struct MetadataFieldPolicy {
    let container: MetadataContainer
    let key: String
    let syncedFields: [(MetadataContainer, String)]?

    init(_ container: MetadataContainer, _ key: String, syncedFields: [(MetadataContainer, String)]? = nil) {
        self.container = container
        self.key = key
        self.syncedFields = syncedFields
    }
}

private enum MetadataSchema {
    /// Essential keys to preserve during "Clear All" to keep the file structure valid.
    static let structuralKeys: Set<String> = [
        kCGImagePropertyPixelWidth as String,
        kCGImagePropertyPixelHeight as String,
        kCGImagePropertyOrientation as String,
        kCGImagePropertyColorModel as String,
        kCGImagePropertyDepth as String,
        kCGImagePropertyProfileName as String,
        kCGImagePropertyDPIWidth as String,
        kCGImagePropertyDPIHeight as String,
        MetadataKeys.appleDict,
        kCGImagePropertyHasAlpha as String,
        kCGImagePropertyExifColorSpace as String,
        kCGImagePropertyPNGGamma as String,
        kCGImagePropertyPNGChromaticities as String,
        kCGImagePropertyTIFFXResolution as String,
        kCGImagePropertyTIFFYResolution as String,
        kCGImagePropertyTIFFResolutionUnit as String,
        MetadataKeys.iccProfile,
        "BitsPerComponent",
        "BitsPerSample",
        "SamplesPerPixel",
        "NamedColorSpace",
        "PrimaryImage",
        "AuxiliaryImage",
        "AuxiliaryData",
        "PixelWidth",
        "PixelHeight",
        "Orientation",
    ]

    private static let policies: [String: MetadataFieldPolicy] = [
        MetadataKeys.make: .init(.tiff, MetadataKeys.make),
        MetadataKeys.model: .init(.tiff, MetadataKeys.model),
        MetadataKeys.software: .init(.tiff, MetadataKeys.software),
        MetadataKeys.dateTime: .init(.tiff, MetadataKeys.dateTime),
        MetadataKeys.artist: .init(.tiff, MetadataKeys.artist, syncedFields: [(.iptc, MetadataKeys.iptcByline)]),
        MetadataKeys.copyright: .init(
            .tiff,
            MetadataKeys.copyright,
            syncedFields: [(.iptc, MetadataKeys.iptcCopyright)]
        ),
        MetadataKeys.lensMake: .init(.exif, MetadataKeys.lensMake),
        MetadataKeys.lensModel: .init(.exif, MetadataKeys.lensModel),
        MetadataKeys.fNumber: .init(.exif, MetadataKeys.fNumber),
        MetadataKeys.exposureTime: .init(.exif, MetadataKeys.exposureTime),
        MetadataKeys.isoSpeedRatings: .init(.exif, MetadataKeys.isoSpeedRatings),
        MetadataKeys.focalLength: .init(.exif, MetadataKeys.focalLength),
        MetadataKeys.exposureBiasValue: .init(.exif, MetadataKeys.exposureBiasValue),
        MetadataKeys.focalLenIn35mmFilm: .init(.exif, MetadataKeys.focalLenIn35mmFilm),
        MetadataKeys.exposureProgram: .init(.exif, MetadataKeys.exposureProgram),
        MetadataKeys.meteringMode: .init(.exif, MetadataKeys.meteringMode),
        MetadataKeys.whiteBalance: .init(.exif, MetadataKeys.whiteBalance),
        MetadataKeys.flash: .init(.exif, MetadataKeys.flash),
        MetadataKeys.dateTimeOriginal: .init(.exif, MetadataKeys.dateTimeOriginal),
        MetadataKeys.dateTimeDigitized: .init(.exif, MetadataKeys.dateTimeDigitized),
        MetadataKeys.location: .init(.gps, MetadataKeys.location),
    ]

    static func policy(for key: String) -> MetadataFieldPolicy {
        policies[key] ?? .init(.exif, key)
    }
}

// MARK: - Metadata Model

public struct Metadata: @unchecked Sendable {
    public let sourceProperties: [String: Any]
    public let metaProps: [(section: MetadataSection, props: [[String: Any]])]
    public let rawGPS: CLLocation?

    public init?(contentsOf url: URL) {
        guard let ciimage = CIImage(contentsOf: url) else { return nil }
        self.init(props: ciimage.properties)
    }

    public init?(ciimage: CIImage, asset: PHAsset? = nil) {
        self.init(props: ciimage.properties, asset: asset)
    }

    public init(props: [String: Any], asset: PHAsset? = nil) {
        sourceProperties = props
        var tmpGPS: CLLocation?
        if let gps = props[MetadataKeys.gpsDict] as? [String: Any],
           let latitude = gps[MetadataKeys.gpsLatitude] as? Double,
           let latitudeRef = gps[MetadataKeys.gpsLatitudeRef] as? String,
           let longitude = gps[MetadataKeys.gpsLongitude] as? Double,
           let longitudeRef = gps[MetadataKeys.gpsLongitudeRef] as? String {
            tmpGPS = CLLocation(
                latitude: latitudeRef == "N" ? latitude : -latitude,
                longitude: longitudeRef == "E" ? longitude : -longitude
            )
        }
        rawGPS = tmpGPS
        metaProps = Metadata.buildMetaProps(source: props, gps: tmpGPS)
    }

    public var dateTimeOriginal: Date? {
        let exif = sourceProperties[MetadataKeys.exifDict] as? [String: Any]
        guard let dateString = exif?[MetadataKeys.dateTimeOriginal] as? String else { return nil }
        return DateFormatter.yMdHms.date(from: dateString)
    }

    // MARK: - Modification Methods

    func writeTimeOriginal(_ date: Date) -> MetadataUpdateIntent {
        write(batch: [MetadataKeys.dateTimeOriginal: date])
    }

    func deleteTimeOriginal() -> MetadataUpdateIntent {
        write(batch: [MetadataKeys.dateTimeOriginal: NSNull()])
    }

    func writeLocation(_ location: CLLocation) -> MetadataUpdateIntent {
        write(batch: [MetadataKeys.location: location])
    }

    func deleteGPS() -> MetadataUpdateIntent {
        write(batch: [MetadataKeys.location: NSNull()])
    }

    func deleteAllExceptOrientation() -> MetadataUpdateIntent {
        let date = dateTimeOriginal

        func extractCleanMetadata(from source: [String: Any]) -> [String: Any] {
            var result = [String: Any]()
            for (key, value) in source {
                if MetadataSchema.structuralKeys.contains(key) {
                    result[key] = value
                } else if let subDictionary = value as? [String: Any] {
                    let cleanedSub = extractCleanMetadata(from: subDictionary)
                    if !cleanedSub.isEmpty { result[key] = cleanedSub }
                }
            }
            return result
        }

        var editableProps = extractCleanMetadata(from: sourceProperties)

        if let date = date {
            let dateString = DateFormatter.yMdHms.string(from: date)
            var exif = editableProps[MetadataKeys.exifDict] as? [String: Any] ?? [:]
            exif[MetadataKeys.dateTimeOriginal] = dateString
            exif[MetadataKeys.dateTimeDigitized] = dateString
            editableProps[MetadataKeys.exifDict] = exif
        }

        if editableProps[MetadataKeys.tiffDict] == nil {
            editableProps[MetadataKeys.tiffDict] = [MetadataKeys.software: "MetaX"]
        }

        return MetadataUpdateIntent(
            fileProperties: editableProps,
            dbLocation: nil,
            dbDate: date,
            forceReencode: true
        )
    }

    func write(batch: [String: Any]) -> MetadataUpdateIntent {
        var finalProperties = sourceProperties
        var newDate: Date?
        var newLocation: CLLocation?
        var isLocationCleared = false

        let getDict = { (key: String) in finalProperties[key] as? [String: Any] ?? [:] }

        for (key, value) in batch {
            let policy = MetadataSchema.policy(for: key)

            switch key {
            case MetadataKeys.location:
                isLocationCleared = value is NSNull
                newLocation = value as? CLLocation
            case MetadataKeys.dateTimeOriginal:
                var exif = getDict(MetadataKeys.exifDict)
                if let date = value as? Date {
                    let dateStr = DateFormatter.yMdHms.string(from: date)
                    exif[MetadataKeys.dateTimeOriginal] = dateStr
                    exif[MetadataKeys.dateTimeDigitized] = dateStr
                    newDate = date
                } else {
                    exif[MetadataKeys.dateTimeOriginal] = NSNull()
                    exif[MetadataKeys.dateTimeDigitized] = NSNull()
                }
                finalProperties[MetadataKeys.exifDict] = exif
            default:
                let dictKey: String
                switch policy.container {
                case .exif: dictKey = MetadataKeys.exifDict
                case .tiff: dictKey = MetadataKeys.tiffDict
                case .iptc: dictKey = MetadataKeys.iptcDict
                default: finalProperties[policy.key] = value; continue
                }

                var dict = getDict(dictKey)
                dict[policy.key] = value

                policy.syncedFields?.forEach { container, syncedKey in
                    let syncDictKey = container == .iptc ? MetadataKeys.iptcDict : MetadataKeys.tiffDict
                    var syncDict = getDict(syncDictKey)
                    syncDict[syncedKey] = value
                    finalProperties[syncDictKey] = syncDict
                }
                finalProperties[dictKey] = dict
            }
        }

        if let location = newLocation {
            finalProperties[MetadataKeys.gpsDict] = Metadata.makeGpsDictionary(for: location)
        } else if isLocationCleared {
            finalProperties[MetadataKeys.gpsDict] = NSNull()
        }

        // Final Safety Scrub: Remove physical attributes that must be managed by the encoder.
        let physicalKeys: [String] = [
            kCGImagePropertyPixelWidth as String, kCGImagePropertyPixelHeight as String,
            kCGImagePropertyOrientation as String, "PixelWidth", "PixelHeight", "Orientation",
        ]
        physicalKeys.forEach { finalProperties.removeValue(forKey: $0) }

        // Ensure identity and color keys are preserved in the final output
        let criticalKeys = [MetadataKeys.appleDict, MetadataKeys.pngDict, MetadataKeys.iccProfile]
        for key in criticalKeys {
            if let val = sourceProperties[key] { finalProperties[key] = val }
        }

        return MetadataUpdateIntent(
            fileProperties: finalProperties,
            dbLocation: isLocationCleared ? nil : (newLocation ?? rawGPS),
            dbDate: batch.keys.contains(MetadataKeys.dateTimeOriginal) ? newDate : dateTimeOriginal
        )
    }

    static func makeGpsDictionary(for location: CLLocation) -> [String: Any] {
        let latitude = location.coordinate.latitude
        let longitude = location.coordinate.longitude
        return [
            MetadataKeys.gpsLatitudeRef: latitude < 0 ? "S" : "N",
            MetadataKeys.gpsLatitude: abs(latitude),
            MetadataKeys.gpsLongitudeRef: longitude < 0 ? "W" : "E",
            MetadataKeys.gpsLongitude: abs(longitude),
        ]
    }

    private static func buildMetaProps(source: [String: Any], gps: CLLocation?) -> [(
        section: MetadataSection,
        props: [[String: Any]]
    )] {
        guard let url = Bundle.main.url(forResource: "MetadataPlus", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let groups = try? PropertyListDecoder().decode([MetadataGroup].self, from: data) else { return [] }

        let exif = source[MetadataKeys.exifDict] as? [String: Any] ?? [:]
        let tiff = source[MetadataKeys.tiffDict] as? [String: Any] ?? [:]

        return groups.compactMap { group in
            guard let section = MetadataSection(rawValue: group.title) else { return nil }
            let props = group.props.compactMap { key -> [String: Any]? in
                if key == MetadataKeys.location { return gps.map { [key: $0] } }
                if let val = exif[key] ?? tiff[key] ?? source[key] { return [key: val] }
                return nil
            }
            return props.isEmpty ? nil : (section: section, props: props)
        }
    }

    private struct MetadataGroup: Codable {
        let title: String, props: [String]
        enum CodingKeys: String, CodingKey { case title = "Title", props = "Props" }
    }
}

// MARK: - MetadataUpdateIntent

struct MetadataUpdateIntent: @unchecked Sendable {
    let fileProperties: [String: Any]
    let dbLocation: CLLocation?
    let dbDate: Date?
    let forceReencode: Bool

    init(
        fileProperties: [String: Any],
        dbLocation: CLLocation? = nil,
        dbDate: Date? = nil,
        forceReencode: Bool = false
    ) {
        self.fileProperties = fileProperties
        self.dbLocation = dbLocation
        self.dbDate = dbDate
        self.forceReencode = forceReencode
    }
}
