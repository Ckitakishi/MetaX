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
import SVProgressHUD

// MARK: Enum -
enum EditAlertAction: Int {
    case add = 0
    case addAndDel = 1
    case cancel = 2
}

class DetailInfoViewController: UIViewController, ViewModelObserving {

    // MARK: - ViewModel

    private var viewModel = DetailInfoViewModel()

    // MARK: - Legacy Properties (for Storyboard segue)

    var asset: PHAsset? {
        didSet {
            if let asset = asset {
                viewModel.configure(with: asset, collection: assetCollection)
            }
        }
    }
    var assetCollection: PHAssetCollection?
    
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
    
    
    // MARK: - Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        let skeletonableViews: [UIView] = [imageView]
        for view in skeletonableViews {
            view.isSkeletonable = true
            view.showAnimatedGradientSkeleton()
        }

        infoTableView.dataSource = self
        infoTableView.delegate = self

        setupBindings()
    }

    // MARK: - Bindings

    private func setupBindings() {
        observe(viewModel: viewModel, property: { $0.image }) { [weak self] image in
            if let image = image {
                self?.imageView.isHidden = false
                self?.imageView.image = image
                self?.imageView.hideSkeleton()
            }
        }

        observe(viewModel: viewModel, property: { $0.isLoading }) { [weak self] isLoading in
            self?.view.isUserInteractionEnabled = !isLoading
            if isLoading {
                SVProgressHUD.showProcessingHUD(with: R.string.localizable.viewProcessing())
            } else {
                SVProgressHUD.dismiss()
            }
        }

        observe(viewModel: viewModel, property: { $0.error }) { [weak self] error in
            if let error = error {
                SVProgressHUD.showCustomErrorHUD(with: error.localizedDescription)
                if case .unsupportedMediaType = error {
                    self?.navigationController?.popViewController(animated: true)
                }
                self?.viewModel.clearError()
            }
        }

        observe(viewModel: viewModel, property: { $0.tableViewDataSource }) { [weak self] _ in
            self?.infoTableView.reloadData()
            self?.tableViewHeightConstraint.constant = self?.heightOfTableView() ?? 0
        }

        observe(viewModel: viewModel, property: { $0.timeStamp }) { [weak self] timeStamp in
            self?.updateTimeStampUI(timeStamp)
        }

        observe(viewModel: viewModel, property: { ($0.locationDisplayText, $0.location) }) { [weak self] (displayText, location) in
            self?.updateLocationUI(displayText: displayText, location: location)
        }

        observe(viewModel: viewModel, property: { $0.fileName }) { [weak self] fileName in
            if !fileName.isEmpty {
                self?.navigationItem.title = fileName
            }
        }
    }

    private func updateTimeStampUI(_ timeStamp: String?) {
        if let timeStamp = timeStamp {
            timeStampButton.titleText = timeStamp
            timeStampButton.isEmpty = false
        } else {
            timeStampButton.titleText = R.string.localizable.viewAddDate()
            timeStampButton.isEmpty = true
        }
        timeStampEditButton.isHidden = timeStampButton.isEmpty
    }

    private func updateLocationUI(displayText: String?, location: CLLocation?) {
        if let displayText = displayText {
            locationButton.titleText = displayText
            locationButton.isEmpty = false
        } else if let location = location {
            locationButton.titleText = "\(location.coordinate.latitude), \(location.coordinate.longitude)"
            locationButton.isEmpty = false
        } else {
            locationButton.titleText = R.string.localizable.viewAddLocation()
            locationButton.isEmpty = true
        }
        locationEditButton.isHidden = locationButton.isEmpty
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        adjustImageView()

        // Configure viewModel if asset was set via segue
        if let asset = asset {
            viewModel.configure(with: asset, collection: assetCollection)
        }

        viewModel.loadPhoto(targetSize: targetSize)

        Task {
            await viewModel.loadMetadata()
        }

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
        viewModel.cancelRequests()
    }
    
    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }
    
    // MARK: - Computed Properties

    var targetSize: CGSize {
        let scale = UIScreen.main.scale
        return CGSize(width: imageView.bounds.width * scale,
                      height: imageView.bounds.height * scale)
    }
    
    func adjustImageView() {
        guard let asset = viewModel.asset else { return }
        imageViewHeightConstraint.constant = imageView.bounds.width * CGFloat(asset.pixelHeight) / CGFloat(asset.pixelWidth)

        if UIDevice.current.userInterfaceIdiom == .pad {
            UIView.animate(withDuration: 0.2, animations: {
                self.view.layoutIfNeeded()
            })
        }
    }

    // MARK: - Actions
    @IBAction func editTimeStamp(_ sender: UIButton) {
        deleteAlert { [weak self] action in
            guard let self = self, action != .cancel else { return }
            Task {
                await self.viewModel.clearTimeStamp(deleteOriginal: action == .addAndDel)
            }
        }
    }

    @IBAction func editLocation(_ sender: UIButton) {
        deleteAlert { [weak self] action in
            guard let self = self, action != .cancel else { return }
            Task {
                await self.viewModel.clearLocation(deleteOriginal: action == .addAndDel)
            }
        }
    }

    @IBAction func clearAllMetadata(_ sender: UIButton) {
        deleteAlert { [weak self] action in
            guard let self = self, action != .cancel else { return }
            Task {
                await self.viewModel.clearAllMetadata(deleteOriginal: action == .addAndDel)
            }
        }
    }
    
    
    // MARK: Prepare
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == R.segue.detailInfoViewController.detailPickDate.identifier {
            datePickerPopover = segue.destination as? DetailDatePickerPopover
            if let popover = datePickerPopover?.popoverPresentationController {
                popover.delegate = self;
            }
        } else if segue.identifier == R.segue.detailInfoViewController.detailSearchLocation.identifier {
            if let searchView = segue.destination as? LocationSearchViewController {
                searchView.delegate = self
            }
        }
    }
    
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }
}

// MARK: - Private Methods
fileprivate extension DetailInfoViewController {

    func heightOfTableView() -> CGFloat {
        return viewModel.tableViewDataSource.reduce(0) { height, dic in
            guard let firstValue = dic.values.first else { return height }
            return height + CGFloat(firstValue.count * rowHeight + sectionTitleHeight)
        }
    }

    func addTimeStamp(_ date: Date) {
        deleteAlert { [weak self] action in
            guard let self = self, action != .cancel else { return }
            Task {
                await self.viewModel.addTimeStamp(date, deleteOriginal: action == .addAndDel)
            }
        }
    }

    func addLocation(_ location: CLLocation) {
        deleteAlert { [weak self] action in
            guard let self = self, action != .cancel else { return }
            Task {
                await self.viewModel.addLocation(location, deleteOriginal: action == .addAndDel)
            }
        }
    }

    func deleteAlert(completionHandler: @escaping (EditAlertAction) -> Void) {
        let message = viewModel.isLivePhoto ? R.string.localizable.alertLiveAlertDesc() : R.string.localizable.alertConfirmDesc()
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

// MARK: - UITableViewDataSource
extension DetailInfoViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return viewModel.tableViewDataSource.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.tableViewDataSource[section].values.first?.count ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: String(describing: DetailTableViewCell.self), for: indexPath) as? DetailTableViewCell else {
            return UITableViewCell()
        }

        if let sectionDataSource = viewModel.tableViewDataSource[indexPath.section].values.first {
            cell.cellDataSource = sectionDataSource[indexPath.row]
        }
        return cell
    }
}

// MARK: - UITableViewDelegate
extension DetailInfoViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerView: DetailSectionHeaderView = UIView().instantiateFromNib(DetailSectionHeaderView.self)
        headerView.headetTitle = viewModel.tableViewDataSource[section].keys.first ?? ""
        return headerView
    }
}

// MARK: - PHPhotoLibraryChangeObserver
extension DetailInfoViewController: PHPhotoLibraryChangeObserver {

    func photoLibraryDidChange(_ changeInstance: PHChange) {
        Task { @MainActor in
            guard let curAsset = viewModel.asset,
                  let details = changeInstance.changeDetails(for: curAsset) else {
                return
            }

            viewModel.updateAsset(details.objectAfterChanges)

            guard viewModel.asset != nil else {
                navigationController?.popViewController(animated: true)
                return
            }

            if details.assetContentChanged {
                viewModel.loadPhoto(targetSize: targetSize)
                await viewModel.loadMetadata()
            }
        }
    }
}
