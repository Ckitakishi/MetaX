//
//  PHAssetCollectionExtension.swift
//  MetaX
//
//  Created by Ckitakishi on 2018/3/22.
//  Copyright © 2018 Yuhan Chen. All rights reserved.
//

import Photos

extension PHAssetCollection {

    /// Returns the total count of images in the collection.
    var imagesCount: Int {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
        return PHAsset.fetchAssets(in: self, options: options).count
    }

    /// Returns true if the collection contains at least one image.
    var hasImages: Bool {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
        options.fetchLimit = 1
        return PHAsset.fetchAssets(in: self, options: options).count > 0
    }

    /// Returns the most recently created image in the collection.
    func newestImage() -> PHAsset? {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = 1
        return PHAsset.fetchAssets(in: self, options: options).firstObject
    }
}
