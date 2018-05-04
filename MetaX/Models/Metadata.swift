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
    
    public let metaPropKeys = ["Photo", "Camera", "Lens"]
    
    public let metaProps: [[String: [[String: Any]]]]
    public let photoProps: [[String: Any]]
    public let cameraProps: [[String: Any]]
    public let lensProps: [[String: Any]]
    
    public let timeStampProp: String?
    public let GPSProp: CLLocation?

    public init?(contentsOf url: URL) {
        guard let ciimage = CIImage(contentsOf: url) else {
            return nil
        }
        self.init(ciimage: ciimage)
    }
    
    public init(ciimage: CIImage) {
        self.init(props: ciimage.properties)
    }
    
    public init(props: [String: Any]) {
        
        sourceProperties = props
        
        var tmpPhotoProps: [[String: Any]] = []
        var tmpCameraProps: [[String: Any]] = []
        var tmpLensProps: [[String: Any]] = []
        var tmpMetaProps: [[String: [[String: Any]]]] = []
        
        var tmpTimeProp: String?
        var tmpGPSProp: CLLocation?
        
        guard let path = Bundle.main.path(forResource: "MetadataPlus", ofType: "plist") else {
            fatalError("MetadataPlus.plist is not exist.")
        }

        if let dic = NSDictionary(contentsOfFile: path) {

            let photoKeys = dic.object(forKey: "PhotoProps") as! [String]
            let cameraKeys = dic.object(forKey: "CameraProps") as! [String]
            let lensKeys = dic.object(forKey: "LensProps") as! [String]
            let timeStampKey = dic.object(forKey: "TimeProp") as! String
            
            for pKey in photoKeys {
                if let val = props[pKey] {
                    tmpPhotoProps.append([pKey: val])
                }
            }
            
            if let exifInfo = props["{Exif}"] as? [String: Any],
                let tiffInfo = props["{TIFF}"] as? [String: Any] {
                
                for cKey in cameraKeys {
                    if let val = exifInfo[cKey] {
                        tmpCameraProps.append([cKey: val])
                        continue
                    }
                    if let val = tiffInfo[cKey] {
                        tmpCameraProps.append([cKey: val])
                    }
                }
            }
            
            if let exifInfo = props["{Exif}"] as? [String: Any] {
                // lens info
                for lKey in lensKeys {
                    if let val = exifInfo[lKey] {
                        tmpLensProps.append([lKey: val])
                    }
                }
                // timestamp
                if let val = exifInfo[timeStampKey] as? String {
                    tmpTimeProp = val
                }
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
        }
        
        photoProps = tmpPhotoProps
        cameraProps = tmpCameraProps
        lensProps = tmpLensProps
        
        if let timeProp = tmpTimeProp, let date = DateFormatter(with: .yMdHms).getDate(from: timeProp) {
            let dateFormatter = DateFormatter(with: .yMd)
            timeStampProp = dateFormatter.getStr(from: date)
        } else {
             timeStampProp = tmpTimeProp
        }

        GPSProp = tmpGPSProp
        
        
        for (idx, ary) in[photoProps, cameraProps, lensProps].enumerated() {
            if ary.count > 0 {
                tmpMetaProps.append([metaPropKeys[idx]: ary])
            }
        }

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

