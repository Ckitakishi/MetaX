//
//  PHImageRequestOptionsExtension.swift
//  MetaX
//
//  Created by Chen Yuhan on 2026/02/10.
//  Copyright © 2026 Chen Yuhan. All rights reserved.
//

import Photos

extension PHImageRequestOptions {

    /// Standard options used throughout the app for image requests.
    /// - `opportunistic`: delivers a fast degraded frame first, then replaces
    ///   it with the full-quality result once available.
    /// - `isNetworkAccessAllowed`: enables iCloud photo downloads.
    static var standard: PHImageRequestOptions {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = true
        return options
    }
}
