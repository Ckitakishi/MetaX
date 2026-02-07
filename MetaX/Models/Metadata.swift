//
//  MetaData.swift
//  MetaX
//
//  Created by Ckitakishi on 2018/3/25.
//  Copyright © 2018年 Yuhan Chen. All rights reserved.
//

import UIKit
import Foundation
import CoreLocation

public struct Metadata {
    
    public let sourceProperties: [String: Any]
    
    public let metaProps: [[String: [[String: Any]]]]

    public let timeStampProp: String?
    public let GPSProp: CLLocation?

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

        var tmpMetaProps: [[String: [[String: Any]]]] = []

        var tmpTimeProp: String?
        var tmpGPSProp: CLLocation?

        guard let path = Bundle.main.path(forResource: "MetadataPlus", ofType: "plist"),
              let dic = NSDictionary(contentsOfFile: path) else {
            return nil
        }

        let timeStampKey = dic.object(forKey: "TimeProp") as? String

        let groupPlistKeys = ["DeviceProps", "ShootingProps",
                              "ImageProps", "RightsProps"]
        let metaPropKeys = ["Device", "Shooting", "Image", "Rights"]

        let exifInfo = props["{Exif}"] as? [String: Any] ?? [:]
        let tiffInfo = props["{TIFF}"] as? [String: Any] ?? [:]

        for (idx, groupKey) in groupPlistKeys.enumerated() {
            let keys = dic.object(forKey: groupKey) as? [String] ?? []
            var groupProps: [[String: Any]] = []
            for key in keys {
                if let val = props[key] { groupProps.append([key: val]) }
                else if let val = exifInfo[key] { groupProps.append([key: val]) }
                else if let val = tiffInfo[key] { groupProps.append([key: val]) }
            }
            if !groupProps.isEmpty {
                tmpMetaProps.append([metaPropKeys[idx]: groupProps])
            }
        }

        // timestamp
        if let timeStampKey = timeStampKey, let val = exifInfo[timeStampKey] as? String {
            tmpTimeProp = val
        }

        if let gpsInfo = props["{GPS}"] as? [String: Any] {
            // gps info
            if let latitudeRef = gpsInfo["LatitudeRef"] as? String,
                let latitude = gpsInfo["Latitude"] as? Double,
                let longitudeRef = gpsInfo["LongitudeRef"] as? String,
                let longitude = gpsInfo["Longitude"] as? Double {

                tmpGPSProp = CLLocation(latitude: latitudeRef == "N" ? latitude : -latitude,
                                     longitude: longitudeRef == "E" ? longitude : -longitude)
            }
        }

        if let timeProp = tmpTimeProp, let date = DateFormatter(with: .yMdHms).getDate(from: timeProp) {
            let dateFormatter = DateFormatter(with: .yMd)
            timeStampProp = dateFormatter.getStr(from: date)
        } else {
            timeStampProp = tmpTimeProp
        }

        GPSProp = tmpGPSProp
        metaProps = tmpMetaProps
    }
    
    var timeStampKey: String? {
        get {
            guard let path = Bundle.main.path(forResource: "MetadataPlus", ofType: "plist"),
                let dic = NSDictionary(contentsOfFile: path) else {
                return nil
            }
            return dic.object(forKey: "TimeProp") as? String
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
    
    // udpate software infomation
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

