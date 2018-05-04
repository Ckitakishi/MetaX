//
//  PHAssetCollectionExtension.swift
//  MetaX
//
//  Created by Ckitakishi on 2018/3/22.
//  Copyright © 2018年 Yuhan Chen. All rights reserved.
//

import Photos

extension PHAssetCollection {
    var imagesCount: Int {
        return PHAsset.fetchAssets(in: self, options: nil).count
    }
    
    func newestImage() -> PHAsset? {
        let images: PHFetchResult = PHAsset.fetchAssets(in: self, options: nil)
        if images.count > 0 {
            return images.lastObject
        }
        return nil
    }
}
