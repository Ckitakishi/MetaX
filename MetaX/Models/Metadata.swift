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

public enum MetadataKeys {
    static let location = "Location"
    static let dateTimeOriginal = "DateTimeOriginal"
    static let basicInfoGroup = "BASIC INFO"
}

public struct Metadata {
    
    public let sourceProperties: [String: Any]
    
    /// Categorized metadata properties: [GroupName: [Key: Value]]
    public let metaProps: [[String: [[String: Any]]]]

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

        var tmpMetaProps: [[String: [[String: Any]]]] = []
        var tmpGPSProp: CLLocation?

        let exifInfo = props["{Exif}"] as? [String: Any] ?? [:]
        let tiffInfo = props["{TIFF}"] as? [String: Any] ?? [:]
        
        // Extract GPS first for internal use
        if let gpsInfo = props["{GPS}"] as? [String: Any],
           let latitudeRef = gpsInfo["LatitudeRef"] as? String,
           let latitude = gpsInfo["Latitude"] as? Double,
           let longitudeRef = gpsInfo["LongitudeRef"] as? String,
           let longitude = gpsInfo["Longitude"] as? Double {
            tmpGPSProp = CLLocation(latitude: latitudeRef == "N" ? latitude : -latitude,
                                 longitude: longitudeRef == "E" ? longitude : -longitude)
        }
        self.rawGPS = tmpGPSProp

        for group in groups {
            guard let title = group["Title"] as? String,
                  let keys = group["Props"] as? [String] else { continue }
            
            var groupProps: [[String: Any]] = []
            
            for key in keys {
                if key == MetadataKeys.location {
                    if let gps = tmpGPSProp {
                        groupProps.append([key: gps])
                    }
                } else if let val = props[key] {
                    groupProps.append([key: val])
                } else if let val = exifInfo[key] {
                    groupProps.append([key: val])
                } else if let val = tiffInfo[key] {
                    groupProps.append([key: val])
                }
            }
            
            if !groupProps.isEmpty {
                tmpMetaProps.append([title: groupProps])
            }
        }

        metaProps = tmpMetaProps
    }
    
    var timeStampKey: String? {
        get {
            return MetadataKeys.dateTimeOriginal
        }
    }
}

// Mark: Helper
extension Metadata {
    // {Exif}.DateTimeOriginal
    func writeTimeOriginal(_ date: Date) -> [String: Any] {
        var editableProps = sourceProperties
        if let exifInfo = editableProps["{Exif}"] as? [String: Any] {
            if let timeStampKey = timeStampKey {
                
                var editableExifInfo = exifInfo
                editableExifInfo[timeStampKey] = DateFormatter(with: .yMdHms).getStr(from: date)
                editableProps["{Exif}"] = editableExifInfo
            }
        } else {
            if let timeStampKey = timeStampKey {
                editableProps["{Exif}"] = [timeStampKey: DateFormatter(with: .yMdHms).getStr(from: date)]
            }
        }
        return updateTiff(with: editableProps)
    }
    
    func deleteTimeOriginal() -> [String: Any]? {
        var editableProps = self.sourceProperties
        if let exifInfo = editableProps["{Exif}"] as? [String: Any] {
            if let timeStampKey = timeStampKey {
                
                var editableExifInfo = exifInfo
                editableExifInfo.removeValue(forKey: timeStampKey)
                editableProps["{Exif}"] = editableExifInfo
                
                return updateTiff(with: editableProps)
            }
        }
        
        return sourceProperties
    }
    
    func writeLocation(_ location: CLLocation) ->  [String: Any] {
        var editableProps = sourceProperties
        editableProps["{GPS}"] = location.mapToDictionary()
        return updateTiff(with: editableProps)
    }
    
    func deleteGPS() ->  [String: Any]? {
        var editableProps = self.sourceProperties
        if editableProps["{GPS}"] != nil {
            editableProps.removeValue(forKey: "{GPS}")
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
        
        let tiffKeys = ["Make", "Model", "Artist", "Copyright", "Software", "DateTime"]
        
        var tiffInfo = editableProps["{TIFF}"] as? [String: Any] ?? [:]
        var exifInfo = editableProps["{Exif}"] as? [String: Any] ?? [:]
        
        for (key, value) in batch {
            if tiffKeys.contains(key) {
                tiffInfo[key] = value
            } else if key == MetadataKeys.dateTimeOriginal {
                exifInfo[key] = DateFormatter(with: .yMdHms).getStr(from: value as? Date ?? Date())
            } else if key == MetadataKeys.location, let loc = value as? CLLocation {
                editableProps["{GPS}"] = loc.mapToDictionary()
            } else {
                exifInfo[key] = value
            }
        }
        
        editableProps["{TIFF}"] = tiffInfo
        editableProps["{Exif}"] = exifInfo
        
        return updateTiff(with: editableProps)
    }
    
    // update software infomation
    func updateTiff(with source: [String: Any]) -> [String: Any]  {
        var editableProps = source
        if let tiffInfo = editableProps["{TIFF}"] as? [String: Any] {
            
            var editableTIFFInfo = tiffInfo
            editableTIFFInfo["Software"] = "MetaX"
            editableTIFFInfo["DateTime"] = Date()
            editableProps["{TIFF}"] = editableTIFFInfo
        } else {
            editableProps["{TIFF}"] = ["Software": "MetaX", "DateTime": Date()]
        }
        return editableProps
    }
}

