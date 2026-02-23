//
//  PHImageRequestOptionsExtension.swift
//  MetaX
//
//  Created by Chen Yuhan on 2026/02/10.
//  Copyright © 2026 Chen Yuhan. All rights reserved.
//

import Photos

extension PHImageRequestOptions {

    /// Standard options used for Photo Library requests.
    static var standard: PHImageRequestOptions {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = true
        return options
    }
}
