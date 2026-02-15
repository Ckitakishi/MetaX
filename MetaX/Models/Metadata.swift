//
//  MetaData.swift
//  MetaX
//
//  Created by Ckitakishi on 2018/3/25.
//  Copyright © 2018 Yuhan Chen. All rights reserved.
//

import UIKit
import Foundation
import CoreLocation

import ImageIO

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

public enum SaveWorkflowMode {
    case updateOriginal
    case saveAsCopy(deleteOriginal: Bool)
}

public enum MetadataSection: String {
    case basicInfo  = "BASIC INFO"
    case gear       = "GEAR"
    case exposure   = "EXPOSURE"
    case fileInfo   = "FILE INFO"
    case copyright  = "COPYRIGHT"

    var localizedTitle: String {
        switch self {
        case .basicInfo:  return String(localized: .editGroupBasicInfo)
        case .gear:       return String(localized: .editGroupGear)
        case .exposure:   return String(localized: .shooting)
        case .fileInfo:   return String(localized: .editGroupFileInfo)
        case .copyright:  return String(localized: .editGroupCopyright)
        }
    }
}

public struct Metadata {

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

    public init?(ciimage: CIImage) {
        self.init(props: ciimage.properties)
    }
    
    public init?(props: [String: Any]) {
        sourceProperties = props

        guard let path = Bundle.main.path(forResource: "MetadataPlus", ofType: "plist"),
              let groups = NSArray(contentsOfFile: path) as? [[String: Any]] else {
            return nil
        }

        var tmpMetaProps: [(section: MetadataSection, props: [[String: Any]])] = []
        var tmpGPSProp: CLLocation?

        let exifInfo = props[MetadataKeys.exifDict] as? [String: Any] ?? [:]
        let tiffInfo = props[MetadataKeys.tiffDict] as? [String: Any] ?? [:]
        
        // Extract GPS first for internal use
        if let gpsInfo = props[MetadataKeys.gpsDict] as? [String: Any],
           let latitudeRef = gpsInfo[MetadataKeys.gpsLatitudeRef] as? String,
           let latitude = gpsInfo[MetadataKeys.gpsLatitude] as? Double,
           let longitudeRef = gpsInfo[MetadataKeys.gpsLongitudeRef] as? String,
           let longitude = gpsInfo[MetadataKeys.gpsLongitude] as? Double {
            tmpGPSProp = CLLocation(latitude: latitudeRef == "N" ? latitude : -latitude,
                                 longitude: longitudeRef == "E" ? longitude : -longitude)
        }
        self.rawGPS = tmpGPSProp

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
                } else if let val = props[key] {
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

// Mark: Helper
extension Metadata {
    // {Exif}.DateTimeOriginal
    func writeTimeOriginal(_ date: Date) -> [String: Any] {
        var editableProps = sourceProperties
        var exifInfo = editableProps[MetadataKeys.exifDict] as? [String: Any] ?? [:]
        let dateStr = DateFormatter(with: .yMdHms).getStr(from: date)
        exifInfo[MetadataKeys.dateTimeOriginal] = dateStr
        exifInfo[MetadataKeys.dateTimeDigitized] = dateStr
        editableProps[MetadataKeys.exifDict] = exifInfo
        return updateTiff(with: editableProps)
    }

    func deleteTimeOriginal() -> [String: Any] {
        var editableProps = self.sourceProperties
        var exifInfo = editableProps[MetadataKeys.exifDict] as? [String: Any] ?? [:]
        exifInfo.removeValue(forKey: MetadataKeys.dateTimeOriginal)
        exifInfo.removeValue(forKey: MetadataKeys.dateTimeDigitized)
        editableProps[MetadataKeys.exifDict] = exifInfo
        return updateTiff(with: editableProps)
    }

    func writeLocation(_ location: CLLocation) -> [String: Any] {
        var editableProps = sourceProperties
        editableProps[MetadataKeys.gpsDict] = makeGpsDictionary(for: location)
        return updateTiff(with: editableProps)
    }

    func deleteGPS() -> [String: Any]? {
        var editableProps = self.sourceProperties
        if editableProps[MetadataKeys.gpsDict] != nil {
            editableProps.removeValue(forKey: MetadataKeys.gpsDict)
            return updateTiff(with: editableProps)
        }
        return self.sourceProperties
    }
    
    func deleteAllExceptOrientation() -> [String: Any]? {
        var editableProps: [String: Any] = [:]
        editableProps["Orientation"] = self.sourceProperties["Orientation"]
        return self.updateTiff(with: editableProps)
    }
    
    func write(batch: [String: Any]) -> [String: Any] {
        var editableProps = sourceProperties
        
        let tiffKeys = [
            MetadataKeys.make, MetadataKeys.model, MetadataKeys.artist,
            MetadataKeys.copyright, MetadataKeys.software, MetadataKeys.dateTime
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
                    let dateStr = DateFormatter(with: .yMdHms).getStr(from: date)
                    exifInfo[key] = dateStr
                    exifInfo[MetadataKeys.dateTimeDigitized] = dateStr
                }
            } else if key == MetadataKeys.location {
                if isRemoval {
                    gpsInfo = [:]
                } else if let loc = value as? CLLocation {
                    gpsInfo = makeGpsDictionary(for: loc)
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
    
    private func makeGpsDictionary(for location: CLLocation) -> [String: Any] {
        var dict: [String: Any] = [:]
        let latitude = location.coordinate.latitude
        let longitude = location.coordinate.longitude
        
        dict[MetadataKeys.gpsLatitudeRef] = latitude < 0 ? "S" : "N"
        dict[MetadataKeys.gpsLatitude] = abs(latitude)
        
        dict[MetadataKeys.gpsLongitudeRef] = longitude < 0 ? "W" : "E"
        dict[MetadataKeys.gpsLongitude] = abs(longitude)
        
        return dict
    }
    
    // update software infomation
    func updateTiff(with source: [String: Any]) -> [String: Any]  {
        var editableProps = source
        var tiffInfo = editableProps[MetadataKeys.tiffDict] as? [String: Any] ?? [:]
        
        // Only set default if Software is not already provided by user or original data
        if tiffInfo[MetadataKeys.software] == nil {
            tiffInfo[MetadataKeys.software] = "MetaX"
        }
        
        // Metadata DateTime should be a formatted string, matching the behavior of DateTimeOriginal
        tiffInfo[MetadataKeys.dateTime] = DateFormatter(with: .yMdHms).getStr(from: Date())
        
        editableProps[MetadataKeys.tiffDict] = tiffInfo
        return editableProps
    }
}

