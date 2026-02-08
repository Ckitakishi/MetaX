//
//  PHPhotoLibraryExtension.swift
//  MetaX
//
//  Created by Ckitakishi on 2018/04/19.
//  Copyright © 2018 Yuhan Chen. All rights reserved.
//

import Photos
import UIKit

extension PHPhotoLibrary {

    class func checkAuthorizationStatus(completionHandler: @escaping (Bool) -> Void) {
        let status = PHPhotoLibrary.authorizationStatus()
        switch status {
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization { status in
                DispatchQueue.main.async {
                    completionHandler(status == .authorized)
                }
            }
        case .denied:
            completionHandler(false)
        default:
            completionHandler(true)
        }
    }

    class func guideToSetting() {
        DispatchQueue.main.async {
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
}
