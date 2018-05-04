//
//  DetailInfoViewController.swift
//  MetaX
//
//  Created by Ckitakishi on 2018/3/20.
//  Copyright © 2018年 Yuhan Chen. All rights reserved.
//

import UIKit
import Photos
import PhotosUI
import SkeletonView
import PromiseKit
import SVProgressHUD
import Rswift

// MARK: Enum -
enum EditAlertAction: Int {
    case add = 0
    case addAndDel = 1
    case cancel = 2
}

enum ImageSaveError: Error {
    case edition
    case creation
    case unknown
}

class DetailInfoViewController: UIViewController {
    
    var asset: PHAsset!
    var assetCollection: PHAssetCollection!
    
    fileprivate let imageManager = PHCachingImageManager()
    
    var metaData: Metadata?
    var tableViewDataSource: [[String: [DetailCellModel]]] = []
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var deleteButton: UIButton!
    @IBOutlet weak var infoTableView: UITableView!
    @IBOutlet weak var timeStampButton: EditableButton!
    @IBOutlet weak var locationButton: EditableButton!
    @IBOutlet weak var locationEditButton: UIButton!
    @IBOutlet weak var timeStampEditButton: UIButton!
    weak var datePickerPopover: DetailDatePickerPopover?
    
    @IBOutlet weak var imageViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var tableViewHeightConstraint: NSLayoutConstraint!
    
    fileprivate let sectionTitleHeight = 60
    fileprivate let rowHeight = 48
    
    fileprivate var imageRequestId: PHImageRequestID?
    fileprivate var editingInputRequestId: PHContentEditingInputRequestID?
    
    
    // Mark: Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let skeletonableViews: [UIView] = [imageView]
        for view in skeletonableViews {
            view.isSkeletonable = true
            view.showAnimatedGradientSkeleton()
        }
        
        infoTableView.dataSource = self
        infoTableView.delegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        adjustImageView()
        loadPhoto()
        updateInfos()
        PHPhotoLibrary.shared().register(self)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            adjustImageView()
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        coordinator.animate(alongsideTransition: nil, completion: { _ in
            self.adjustImageView()
        })
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if let imageReqID = imageRequestId, let inputReqId = editingInputRequestId {
            PHImageManager.default().cancelImageRequest(imageReqID)
            asset.cancelContentEditingInputRequest(inputReqId)
        }
    }
    
    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }
    
    // Mark: Methods
    func loadPhoto() {
        // Prepare the options to pass when fetching the (photo, or video preview) image.
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = true
        
        imageRequestId = PHImageManager.default().requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFit, options: options, resultHandler: { image, _ in

            guard let image = image else {
                return
            }

            self.imageView.isHidden = false
            self.imageView.image = image
            self.imageView.hideSkeleton()
        })
    }
    
    func updateInfos() {
        // Update exif info
        if asset.mediaType.rawValue != 1 || asset.mediaSubtypes.rawValue == 32 {
            // not supported mediatype...or submediatype(gif)
            SVProgressHUD.showCustomInfoHUD(with: R.string.localizable.infoNotSupport())
            self.navigationController?.popViewController(animated: true)
            return
        }
        
        let options = PHContentEditingInputRequestOptions()
        // Download asset metadata from iCloud if needed
        options.isNetworkAccessAllowed = true
        options.progressHandler = {(progress: Double, _) in
            DispatchQueue.main.async {
                SVProgressHUD.showCustomProgress(Float(progress), status: R.string.localizable.viewLoading())
            }
        }
        
        view.isUserInteractionEnabled = false
        
        editingInputRequestId = asset.requestContentEditingInput(with: options, completionHandler: { contentEditingInput, result in
            
            if let imageURL = contentEditingInput?.fullSizeImageURL {
                let ciimage = CIImage(contentsOf: imageURL)
                self.metaData = Metadata(ciimage: ciimage!)
                
                self.updateNavTitle(imageURL.lastPathComponent)
                
                SVProgressHUD.dismiss()
                
                self.updateInfosOfComponents()
                self.infoTableView.reloadData()
                self.tableViewHeightConstraint.constant = self.heightOfTableView()
                
            } else {
                SVProgressHUD.dismiss()
                
                if let iCloudKey = result[PHContentEditingInputResultIsInCloudKey] {
                    if iCloudKey as! Int == 1 {
                        SVProgressHUD.showCustomErrorHUD(with: R.string.localizable.errorICloud())
                        self.navigationController?.popViewController(animated: true)
                        return
                    }
                }
                
                if let err = result[PHContentEditingInputErrorKey] as? Error {
                    SVProgressHUD.showCustomErrorHUD(with: err.localizedDescription)
                }
                
                self.navigationController?.popViewController(animated: true)
            }
            
            self.editingInputRequestId = nil
            self.view.isUserInteractionEnabled = true
        })
    }
    
    func updateNavTitle(_ title: String) {
        navigationItem.title = title
    }
    
    func updateInfosOfComponents() {
        // init
        tableViewDataSource = []
        // update
        updateInfoOfTime()
        updateInfoOfLocation()
        
        for doc in metaData!.metaProps {
            for (key, value) in doc {
                tableViewDataSource.append(
                    [key: value.map {
                        DetailCellModel.init(propValue: $0)
                        }]
                )
            }
        }
    }
    
    func updateInfoOfTime() {
        timeStamp = metaData?.timeStampProp
    }
    
    func updateInfoOfLocation() {
        location = metaData?.GPSProp
    }
    
    var targetSize: CGSize {
        let scale = UIScreen.main.scale
        return CGSize(width: imageView.bounds.width * scale,
                      height: imageView.bounds.height * scale)
    }
    
    func adjustImageView() {
        imageViewHeightConstraint.constant = imageView.bounds.width * CGFloat(asset.pixelHeight) / CGFloat(asset.pixelWidth)
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            UIView.animate(withDuration: 0.2, animations: {
                self.view.layoutIfNeeded()
            })
        }
    }
    
    // Mark: GPS & Timestamp
    var location: CLLocation? = nil {
        didSet {
            guard let location = location else {
                locationButton.titleText = R.string.localizable.viewAddLocation()
                locationButton.isEmpty = true
                updateLocationStatus()
                return
            }
            locationButton.titleText = "\(location.coordinate.latitude), \(location.coordinate.longitude)"
            locationButton.isEmpty = false
            updateLocationStatus()
            
            CLGeocoder().reverseGeocodeLocation(location) { (placemarks, error) in
                guard let placemarks = placemarks else {
                    return
                }
                
                if let placemark = placemarks.first {
                    let infos = [placemark.thoroughfare, placemark.locality, placemark.administrativeArea, placemark.country]
                    
                    self.locationButton.titleText = infos.reduce("") { (locaitonText: String, info) in
                        guard let infoText = info else {
                            return ""
                        }
                        return "\(locaitonText)" + (locaitonText != "" ? "," : "") + "\(infoText)"
                    }
                }
                self.updateLocationStatus()
            }
        }
    }
    
    func updateLocationStatus() {
        locationEditButton.isHidden = locationButton.isEmpty
    }
    
    var timeStamp: String? = nil {
        didSet {
            guard let timeStamp = timeStamp else {
                timeStampButton.titleText = R.string.localizable.viewAddDate()
                timeStampButton.isEmpty = true
                updateTimeStampStatus()
                return
            }
            timeStampButton.titleText = timeStamp
            timeStampButton.isEmpty = false
            updateTimeStampStatus()
        }
    }
    
    func updateTimeStampStatus() {
        timeStampEditButton.isHidden = timeStampButton.isEmpty
    }
    
    // Mark: Action
    @IBAction func editTimeStamp(_ sender: UIButton) {
        clearTimeStamp()
    }
    
    @IBAction func editLocation(_ sender: UIButton) {
        clearLocation()
    }
    
    @IBAction func clearAllMetadata(_ sender: UIButton) {
        
        let newProps = metaData?.deleteAllExceptOrientation()
        
        deleteAlert(completionHandler: { action -> Void in
            if action != .cancel {
                self.saveImage(newProps: newProps!, doDelete: action == .addAndDel, completionHandler: {
                    self.metaData = Metadata(props: newProps!)
                })
            }
        })
    }
    
    
    // MARK: Prepare
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == R.segue.detailInfoViewController.detailPickDate.identifier {
            datePickerPopover = segue.destination as? DetailDatePickerPopover
            if let popover = datePickerPopover?.popoverPresentationController {
                popover.delegate = self;
            }
        } else if segue.identifier == R.segue.detailInfoViewController.detailSearchLocation.identifier {
            let searchView = segue.destination as! LocationSearchViewController
            searchView.delegate = self
        }
    }
    
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }
}

// MARK: ileprivate Methods
fileprivate extension DetailInfoViewController {
    
    func heightOfTableView() -> CGFloat {
        
        return tableViewDataSource.reduce(0) { height, dic in
            return height + CGFloat(dic.map { $0.1 } [0].count * rowHeight + sectionTitleHeight)
        }
    }
    
    func addTimeStamp(_ date: Date) {
        let newProps = metaData?.writeTimeOriginal(date)
        
        deleteAlert(completionHandler: { action -> Void in
            if action != .cancel {
                self.saveImage(newProps: newProps!, doDelete: action == .addAndDel, completionHandler: {
                    
                    self.metaData = Metadata(props: newProps!)
                    
                    PHPhotoLibrary.shared().performChanges({
                        let request = PHAssetChangeRequest(for: self.asset)
                        request.creationDate = date
                    })
                })
            }
        })
    }
    
    func clearTimeStamp() {
        let newProps = metaData?.deleteTimeOriginal()
        
        deleteAlert(completionHandler: { action -> Void in
            if action != .cancel {
                self.saveImage(newProps: newProps!, doDelete: action == .addAndDel, completionHandler: {
                    self.metaData = Metadata(props: newProps!)
                })
            }
        })
    }
    
    func addLocation(_ location: CLLocation) {
        let newProps = metaData?.writeLocation(location)
        
        deleteAlert(completionHandler: { action -> Void in
            if action != .cancel {
                self.saveImage(newProps: newProps!, doDelete: action == .addAndDel, completionHandler: {
                    
                    self.metaData = Metadata(props: newProps!)
                    
                    PHPhotoLibrary.shared().performChanges({
                        
                        let request = PHAssetChangeRequest(for: self.asset)
                        request.location = location
                    })
                })
            }
        })
    }
    
    func clearLocation() {

        let newProps = metaData?.deleteGPS()
        
        deleteAlert(completionHandler: { action -> Void in
            if action != .cancel {
                self.saveImage(newProps: newProps!, doDelete: action == .addAndDel, completionHandler: {
                    
                    self.metaData = Metadata(props: newProps!)
                    
                    PHPhotoLibrary.shared().performChanges({
                        let request = PHAssetChangeRequest(for: self.asset)
                        request.location = CLLocation.init(latitude: 0, longitude: 0)
                    })
                })
            }
        })
    }
    
    
    func createNewAlbum(albumTitle: String) -> Promise<Bool> {
        return Promise { seal in
            if self.checkAlbumExists(albumTitle) {
                seal.fulfill(true)
            } else {
                PHPhotoLibrary.shared().performChanges({
                    PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: albumTitle)
                }) { (isSuccess, error) in
                    isSuccess ? seal.fulfill(isSuccess) : seal.reject(error!)
                }
            }
        }
    }
    
    func requestContentEditingInput(with options: PHContentEditingInputRequestOptions, newProps: [String: Any]) -> Promise<URL> {
        
        return Promise { seal in
            asset.requestContentEditingInput(with: options, completionHandler: { contentEditingInput, _ in
                
                guard let imageURL = contentEditingInput?.fullSizeImageURL else {
                    seal.reject(ImageSaveError.edition)
                    return
                }
                
                let ciImageOfURL = CIImage(contentsOf: imageURL)
                let context = CIContext(options:nil)
                
                guard let ciImage = ciImageOfURL else {
                    seal.reject(ImageSaveError.edition)
                    return
                }
                
                var tmpUrl = NSURL.fileURL(withPath: NSTemporaryDirectory() + imageURL.lastPathComponent)
                
                let cgImage = context.createCGImage(ciImage, from: ciImage.extent)
                let cgImageSource = CGImageSourceCreateWithURL(imageURL as CFURL, nil)
                
                guard let sourceType = CGImageSourceGetType(cgImageSource!) else {
                    seal.reject(ImageSaveError.edition)
                    return
                }
                
                var createdDestination: CGImageDestination? = CGImageDestinationCreateWithURL(tmpUrl as CFURL, sourceType
                    , 1, nil)
                
                if createdDestination == nil {
                    // media type is unsupported: delete temp file, create new one with extension [.JPG].
                    let _ = try? FileManager.default.removeItem(at: tmpUrl)
                    tmpUrl = NSURL.fileURL(withPath: NSTemporaryDirectory() + imageURL.deletingPathExtension().lastPathComponent + ".JPG")
                    createdDestination = CGImageDestinationCreateWithURL(tmpUrl as CFURL, "public.jpeg" as CFString
                        , 1, nil)
                }
                
                guard let destination = createdDestination else {
                    seal.reject(ImageSaveError.edition)
                    return
                }

                
                CGImageDestinationAddImage(destination, cgImage!, newProps as CFDictionary)
                if !CGImageDestinationFinalize(destination) {
                    seal.reject(ImageSaveError.edition)
                } else {
                    seal.fulfill(tmpUrl)
                }
            })
        }
    }
    
    func createAsset(from tempURL: URL) -> Promise<PHAsset> {
        
        return Promise { seal in
            var localId: String? = ""
            
            PHPhotoLibrary.shared().performChanges({
                let request = PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: tempURL)
                localId = request?.placeholderForCreatedAsset?.localIdentifier
                
                let fetchOptions = PHFetchOptions()
                fetchOptions.predicate = NSPredicate(format: "title = %@", "MetaX")
                let collection = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)
                
                if let album = collection.firstObject {
                    let albumChangeRequest = PHAssetCollectionChangeRequest(for: album)
                    let placeHolder = request?.placeholderForCreatedAsset
                    albumChangeRequest?.addAssets([placeHolder!] as NSArray)
                }
            }, completionHandler: { (rerult, err) in
                
                if !rerult {
                    seal.reject(ImageSaveError.creation)
                }
            
                if let localId = localId {
                    let results = PHAsset.fetchAssets(withLocalIdentifiers: [localId], options: nil)
                    if results.count > 0 {
                        let asset = results.firstObject
                        self.asset = asset
                        
                        let _ = try? FileManager.default.removeItem(at: tempURL)
                        
                        DispatchQueue.main.async {
                            self.loadPhoto()
                            self.updateInfos()
                        }
                        
                        seal.fulfill(asset!)
                    }
                }
            })
        }
    }
    
    func deleteAsset(_ asset: PHAsset?) -> Promise<Bool> {
        return Promise { seal in
            PHPhotoLibrary.shared().performChanges({
                PHAssetCreationRequest.deleteAssets([asset] as NSFastEnumeration)
            }, completionHandler: { result, err in
                if !result {
                    seal.reject(err!)
                }
                seal.fulfill(true)
            })
        }
    }
    
    // MARK: Save Image Core
    func saveImage(newProps: [String: Any], doDelete: Bool, completionHandler: @escaping () -> Void) {
        
        let oldAsset = self.asset
        SVProgressHUD.showProcessingHUD(with: R.string.localizable.viewProcessing())
        
        firstly {
            createNewAlbum(albumTitle: "MetaX")
            }.then { _ -> Promise<URL> in
                let options = PHContentEditingInputRequestOptions()
                options.isNetworkAccessAllowed = true //download asset metadata from iCloud if needed
                
                return self.requestContentEditingInput(with: options, newProps: newProps)
            }.then { tmpURL -> Promise<PHAsset> in
                self.createAsset(from: tmpURL)
            }.then { _ -> Promise<Bool> in
                if doDelete {
                    return self.deleteAsset(oldAsset)
                } else {
                    return Promise {
                        seal in seal.fulfill(true)
                    }
                }
            }.done { _ in
                SVProgressHUD.dismiss()
                completionHandler()
            }.catch { error in
                SVProgressHUD.dismiss()
                
                var errorMessage = R.string.localizable.errorImageSaveUnknown()
                
                switch error {
                case ImageSaveError.edition:
                    errorMessage = R.string.localizable.errorImageSaveEdition()
                    break
                case ImageSaveError.creation:
                    errorMessage = R.string.localizable.errorImageSaveCreation()
                    break
                default:
                    break
                }
                
                SVProgressHUD.showCustomErrorHUD(with: errorMessage)
        }
    }
    
    func checkAlbumExists(_ title: String) -> Bool {
        let albums = PHAssetCollection.fetchAssetCollections(with: PHAssetCollectionType.album, subtype:
            PHAssetCollectionSubtype.albumRegular, options: nil)
        for i in 0 ..< albums.count {
            let album = albums.object(at: i)
            if album.localizedTitle != nil && album.localizedTitle == title {
                return true
            }
        }
        return false
    }
    
    func deleteAlert(completionHandler: @escaping (EditAlertAction) -> Void) {
        
        
        let message = asset.mediaSubtypes == .photoLive ? R.string.localizable.alertLiveAlertDesc() : R.string.localizable.alertConfirmDesc()
        let alert: UIAlertController = UIAlertController(title: R.string.localizable.alertConfirm(),
                                                         message: message,
                                                         preferredStyle: .alert)
        
        let addAndDelAction: UIAlertAction = UIAlertAction(title: R.string.localizable.alertAddAndDel(), style: .default, handler:{
            (action: UIAlertAction!) -> Void in
            completionHandler(EditAlertAction.addAndDel)
        })
        
        let addAction: UIAlertAction = UIAlertAction(title: R.string.localizable.alertAdd(), style: .default, handler:{
            (action: UIAlertAction!) -> Void in
            completionHandler(EditAlertAction.add)
        })

        let cancelAction: UIAlertAction = UIAlertAction(title: R.string.localizable.alertCancel(), style: .cancel, handler:{
            (action: UIAlertAction!) -> Void in
            completionHandler(EditAlertAction.cancel)
        })

        alert.addAction(addAndDelAction)
        alert.addAction(addAction)
        alert.addAction(cancelAction)
        present(alert, animated: true, completion: nil)
    }
}

// MARK: UIPopoverPresentationControllerDelegate
extension DetailInfoViewController: UIPopoverPresentationControllerDelegate {
    
    func popoverPresentationControllerDidDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) {
        if let popover = datePickerPopover {
            addTimeStamp(popover.curDate)
        }
    }
}

// MARK: LocationSearchDelegate
extension DetailInfoViewController: LocationSearchDelegate {
    
    func didSelect(_ model: LocationModel) {
        guard let coordinate = model.coordinate else {
            SVProgressHUD.showCustomErrorHUD(with: R.string.localizable.errorCoordinateFetch())
            return
        }
        addLocation(CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
    }
}

// MARK: UITableViewDataSource
extension DetailInfoViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return tableViewDataSource.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tableViewDataSource[section].map { $0.1 } [0].count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: DetailTableViewCell = tableView.dequeueReusableCell(withIdentifier: String(describing: DetailTableViewCell.self), for: indexPath) as! DetailTableViewCell
        
        let sectionDataSource = tableViewDataSource[indexPath.section].map { $0.1 } [0]
        cell.cellDataSource = sectionDataSource[indexPath.row]
        return cell
    }
}

// MARK: UITableViewDelegate
extension DetailInfoViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerView: DetailSectionHeaderView = UIView().instantiateFromNib(DetailSectionHeaderView.self)
        headerView.headetTitle = tableViewDataSource[section].map { $0.0 } [0]
        return headerView
    }
}

// MARK: PHPhotoLibraryChangeObserver
extension DetailInfoViewController: PHPhotoLibraryChangeObserver {
    
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        guard let curAsset = asset, let details = changeInstance.changeDetails(for: curAsset) else {
            return
        }
        asset = details.objectAfterChanges
        
        DispatchQueue.main.async {
            guard let _ = self.asset else {
                self.navigationController?.popViewController(animated: true)
                return
            }
            
            if details.assetContentChanged {
                self.loadPhoto()
                self.updateInfos()
            }
        }
    }
}
