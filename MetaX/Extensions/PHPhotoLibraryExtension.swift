//
//  PHPhotoLibraryExtension.swift
//  MetaX
//
//  Created by Ckitakishi on 2018/04/19.
//  Copyright © 2018年 Yuhan Chen. All rights reserved.
//

import Photos

extension PHPhotoLibrary {
    
    class func checkAuthorizationStatus(completionHandler: @escaping (Bool) -> Void) {
        let status = PHPhotoLibrary.authorizationStatus()
        switch status {
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization { status -> Void in
                
                DispatchQueue.main.async {
                    if status != .authorized {
                        completionHandler(false)
                    }
                }
            }
            break
        case .denied:
            completionHandler(false)
        default:
            completionHandler(true)
            break
        }
    }
    
    class func guideToSetting() {
        DispatchQueue.main.async {
            let url = URL(string: UIApplicationOpenSettingsURLString)
            UIApplication.shared.open(url!, options: [:], completionHandler: nil)
        }
    }
}
