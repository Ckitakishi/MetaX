//
//  AlbumViewController.swift
//  MetaX
//
//  Created by Ckitakishi on 2018/3/20.
//  Copyright © 2018年 Yuhan Chen. All rights reserved.
//

import UIKit
import Photos

class AlbumViewController: UITableViewController {
    
    // MARK: Enum - Types for managing sections, cell and segue identifiers
    enum Section: Int {
        case allPhotos = 0
        case smartAlbums
        case userCollections
        
        static let count = 3
    }
    
    // MARK: Properties
    var allPhotos: PHFetchResult<PHAsset>!
    var smartAlbums: PHFetchResult<PHAssetCollection>!
    var nonEmptySmartAlbums: [PHAssetCollection] = []
    var userCollections: PHFetchResult<PHCollection>!
    var userAssetCollections: [PHAssetCollection] = []
    let sectionLocalizedTitles = ["", NSLocalizedString(R.string.localizable.viewSmartAlbums(), comment: ""), NSLocalizedString(R.string.localizable.viewMyAlbums(), comment: "")]
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        PHPhotoLibrary.checkAuthorizationStatus(completionHandler: { status in
            if !status {
                // not authorized => add a lock view
                let lockView: AuthLockView = UIView().instantiateFromNib(AuthLockView.self)
                if let topView = self.navigationController?.view {
                    lockView.frame = topView.frame
                    lockView.delegate = self
                    lockView.title = R.string.localizable.alertPhotoAccess()
                    lockView.detail = R.string.localizable.alertPhotoAccessDesc()
                    lockView.buttonTitle = R.string.localizable.alertPhotoAuth()
                    topView.addSubview(lockView)
                }
            }
        })
        
        let allPhotosOptions = PHFetchOptions()
        allPhotosOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        allPhotos = PHAsset.fetchAssets(with: allPhotosOptions)

        smartAlbums = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .albumRegular, options: nil)
        nonEmptySmartAlbums = updatedNonEmptyAlbums()
        
        userCollections = PHCollectionList.fetchTopLevelUserCollections(with: nil)
        userAssetCollections = updatedUserAssetCollection()
        
        PHPhotoLibrary.shared().register(self)
    }
    
    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }

    // MARK: Segues
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        guard let destination = (segue.destination as? UINavigationController)?.topViewController as? PhotoGridViewController else {
            fatalError("unexpected view controller for segue")
        }
        
        let cell = sender as! UITableViewCell
        
        destination.title = cell.textLabel?.text
        
        let indexPath = tableView.indexPath(for: cell)!
        let collection: PHCollection
        switch Section(rawValue: indexPath.section)! {
        case .allPhotos:
            destination.fetchResult = allPhotos
            destination.title = R.string.localizable.viewAllPhotos()
            return;
        case .smartAlbums:
            collection = nonEmptySmartAlbums[indexPath.row]
        case .userCollections:
            collection = userAssetCollections[indexPath.row]
        }
        
        guard let assetCollection = collection as? PHAssetCollection else {
            fatalError("expected asset collection")
        }
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        destination.fetchResult = PHAsset.fetchAssets(in: assetCollection, options: options)
        destination.assetCollection = assetCollection
        destination.title = collection.localizedTitle!
    }
}

// MARK: Fileprivate Method
fileprivate extension AlbumViewController {
    
    func getThumnail(asset: PHAsset) -> UIImage? {
        var thumnail: UIImage?
        DispatchQueue.global().sync {
            let options = PHImageRequestOptions()
            options.deliveryMode = .fastFormat
            options.isSynchronous = true
            options.isNetworkAccessAllowed = false
            PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 92.0, height: 92.0), contentMode: .aspectFit, options: options, resultHandler: { image, _ in
                if let image = image {
                    thumnail = image
                }
            })
        }
        return thumnail
    }
    
    // PHCollection => (PHCollectionList, PHAssetCollection)
    func flattenCollectionList(_ list: PHCollectionList) -> [PHAssetCollection] {
        
        var assetCollections: [PHAssetCollection] = []
        let tempCollections = PHCollectionList.fetchCollections(in: list, options: nil)
        
        tempCollections.enumerateObjects({ [weak self] (collection, start, stop) in
            if let assetCollection = collection as? PHAssetCollection {
                assetCollections.append(assetCollection)
            } else if let collectionList = collection as? PHCollectionList {
                assetCollections.append(contentsOf: self!.flattenCollectionList(collectionList))
            }
        })
        return assetCollections
    }
    
    func updatedNonEmptyAlbums() -> [PHAssetCollection] {
        var curNonEmptyAlbums: [PHAssetCollection] = []
        
        smartAlbums.enumerateObjects({ (collection, start, stop) in
            if collection.imagesCount > 0 {
                curNonEmptyAlbums.append(collection)
            }
        })
        
        return curNonEmptyAlbums
    }
    
    func updatedUserAssetCollection() -> [PHAssetCollection] {
        var curUserAssetColelctions: [PHAssetCollection] = []
        
        userCollections.enumerateObjects({ [weak self] (collection, start, stop) in
            if let assetCollection = collection as? PHAssetCollection {
                curUserAssetColelctions.append(assetCollection)
            } else if let collectionList = collection as? PHCollectionList {
                curUserAssetColelctions.append(contentsOf: self!.flattenCollectionList(collectionList))
            }
        })
        
        return curUserAssetColelctions
    }
}

// MARK: UITableViewDataSource
extension AlbumViewController {
    override func numberOfSections(in tableView: UITableView) -> Int {
        return Section.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .allPhotos: return 1
        case .smartAlbums: return nonEmptySmartAlbums.count
        case .userCollections: return userAssetCollections.count
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: AlbumTableViewCell = tableView.dequeueReusableCell(withIdentifier: String(describing: AlbumTableViewCell.self), for: indexPath) as! AlbumTableViewCell
        
        cell.thumnail = nil
        
        switch Section(rawValue: indexPath.section)! {
            
        case .allPhotos:
            cell.title = R.string.localizable.viewAllPhotos()
            cell.count = allPhotos.count
            if allPhotos.count > 0 {
                if let firstThumnail = getThumnail(asset: allPhotos.object(at: 0)) {
                     cell.thumnail = firstThumnail
                }
            }
            return cell
            
        case .smartAlbums:
            let collection = nonEmptySmartAlbums[indexPath.row]
            cell.title = collection.localizedTitle
            cell.count = collection.imagesCount
            if let firstImage = collection.newestImage() {
                cell.thumnail = getThumnail(asset: firstImage)
            }
            return cell
            
        case .userCollections:
            let assetCollection = userAssetCollections[indexPath.row]
            cell.title = assetCollection.localizedTitle
            cell.count = assetCollection.imagesCount
            if let firstImage = assetCollection.newestImage() {
                cell.thumnail = getThumnail(asset: firstImage)
            }
            return cell
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sectionLocalizedTitles[section]
    }
}

// MARK: AuthLockViewDelegates
extension AlbumViewController: AuthLockViewDelegate {
    
    func toSetting() {
        PHPhotoLibrary.guideToSetting()
    }
}

// MARK: PHPhotoLibraryChangeObserver
extension AlbumViewController: PHPhotoLibraryChangeObserver {
    
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        
        if let changeDetails = changeInstance.changeDetails(for: allPhotos) {
            allPhotos = changeDetails.fetchResultAfterChanges
        }
        
        if let changeDetails = changeInstance.changeDetails(for: smartAlbums) {
            smartAlbums = changeDetails.fetchResultAfterChanges
            nonEmptySmartAlbums = updatedNonEmptyAlbums()
        }
        
        if let changeDetails = changeInstance.changeDetails(for: userCollections) {
            userCollections = changeDetails.fetchResultAfterChanges
            userAssetCollections = updatedUserAssetCollection()
        }
        
        DispatchQueue.main.async {
           self.tableView.reloadData()
        }
    }
}
