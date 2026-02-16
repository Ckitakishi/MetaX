//
//  PHAssetCollectionExtension.swift
//  MetaX
//
//  Created by Ckitakishi on 2018/3/22.
//  Copyright © 2018 Yuhan Chen. All rights reserved.
//

import Photos

extension PHAssetCollection {
    var imagesCount: Int {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
        return PHAsset.fetchAssets(in: self, options: options).count
    }

    /// Cheap existence check — fetches at most 1 asset.
    var hasImages: Bool {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
        options.fetchLimit = 1
        return PHAsset.fetchAssets(in: self, options: options).count > 0
    }

    /// Returns the most recently created image, fetching only 1 asset from the DB.
    func newestImage() -> PHAsset? {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = 1
        return PHAsset.fetchAssets(in: self, options: options).firstObject
    }
}
