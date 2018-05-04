//
//  CLLocationExtension.swift
//  MetaX
//
//  Created by Ckitakishi on 2018/4/12.
//  Copyright © 2018年 Yuhan Chen. All rights reserved.
//

import MapKit

extension CLLocation {
    
    func mapToDictionary() -> [String: Any] {
        var mutableDic: [String: Any] = [:]
        let latitude = coordinate.latitude
        let longitude = coordinate.longitude
        
        if latitude < 0 {
            mutableDic["LatitudeRef"] = "S"
            mutableDic["Latitude"] = -latitude
        } else {
            mutableDic["LatitudeRef"] = "N"
            mutableDic["Latitude"] = latitude
        }
        
        if longitude < 0 {
            mutableDic["LongitudeRef"] = "W"
            mutableDic["Longitude"] = -longitude
        } else {
            mutableDic["LongitudeRef"] = "E"
            mutableDic["Longitude"] = longitude
        }

        return mutableDic
    }
}
