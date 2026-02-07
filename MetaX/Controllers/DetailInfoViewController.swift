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
import SVProgressHUD
import CoreLocation

// MARK: Enum -
enum EditAlertAction: Int {
    case add = 0
    case addAndDel = 1
    case cancel = 2
}

class DetailInfoViewController: UIViewController, ViewModelObserving {

    // MARK: - ViewModel
    private var viewModel = DetailInfoViewModel()

    // MARK: - UI Components
    private let tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .insetGrouped)
        table.translatesAutoresizingMaskIntoConstraints = false
        return table
    }()

    private let heroImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.backgroundColor = .secondarySystemFill
        return imageView
    }()

    private lazy var clearAllButton: UIBarButtonItem = {
        UIBarButtonItem(image: UIImage(systemName: "trash"), style: .plain, target: self, action: #selector(clearAllMetadata))
    }()

    // MARK: - Properties
    var asset: PHAsset?
    var assetCollection: PHAssetCollection?

    // MARK: - Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupBindings()

        if let asset = asset {
            viewModel.configure(with: asset, collection: assetCollection)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateHeaderHeight()
        viewModel.loadPhoto(targetSize: targetSize)
        Task {
            await viewModel.loadMetadata()
        }
        PHPhotoLibrary.shared().register(self)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        viewModel.cancelRequests()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: nil) { _ in
            self.updateHeaderHeight()
        }
    }

    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }

    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = .systemGroupedBackground
        navigationItem.rightBarButtonItem = clearAllButton

        // TableView setup
        view.addSubview(tableView)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(DetailTableViewCell.self, forCellReuseIdentifier: String(describing: DetailTableViewCell.self))

        // Header Setup
        let headerContainer = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 300))
        headerContainer.addSubview(heroImageView)
        heroImageView.frame = headerContainer.bounds
        heroImageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tableView.tableHeaderView = headerContainer

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func updateHeaderHeight() {
        guard let asset = viewModel.asset else { return }
        let width = view.bounds.width
        let height = width * CGFloat(asset.pixelHeight) / CGFloat(asset.pixelWidth)
        let clampedHeight = min(height, view.bounds.height * 0.5)

        if let header = tableView.tableHeaderView {
            header.frame.size = CGSize(width: width, height: clampedHeight)
            tableView.tableHeaderView = header
        }
    }

    private var targetSize: CGSize {
        let scale = UIScreen.main.scale
        let headerHeight = tableView.tableHeaderView?.frame.height ?? 300
        return CGSize(width: view.bounds.width * scale, height: headerHeight * scale)
    }

    // MARK: - Bindings
    private func setupBindings() {
        observe(viewModel: viewModel, property: { $0.image }) { [weak self] image in
            self?.heroImageView.image = image
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
            self?.tableView.reloadData()
        }

        observe(viewModel: viewModel, property: { $0.timeStamp }) { [weak self] _ in
            guard let self = self, self.isViewLoaded, self.view.window != nil else { return }
            self.tableView.reloadData()
        }

        observe(viewModel: viewModel, property: { ($0.locationDisplayText, $0.location) }) { [weak self] _ in
            guard let self = self, self.isViewLoaded, self.view.window != nil else { return }
            self.tableView.reloadData()
        }

        observe(viewModel: viewModel, property: { $0.fileName }) { [weak self] fileName in
            if !fileName.isEmpty {
                self?.navigationItem.title = fileName
            }
        }
    }

    // MARK: - Actions
    @objc private func clearAllMetadata() {
        deleteAlert { [weak self] action in
            guard let self = self, action != .cancel else { return }
            Task {
                await self.viewModel.clearAllMetadata(deleteOriginal: action == .addAndDel)
            }
        }
    }

    private func showDatePicker() {
        let popover = DetailDatePickerPopover()
        popover.modalPresentationStyle = .popover
        popover.popoverPresentationController?.delegate = self
        popover.popoverPresentationController?.sourceView = view
        popover.popoverPresentationController?.sourceRect = CGRect(
            x: view.bounds.midX, y: view.bounds.midY,
            width: 0, height: 0
        )
        popover.popoverPresentationController?.permittedArrowDirections = []

        present(popover, animated: true)
    }

    private func showLocationSearch() {
        let searchVC = LocationSearchViewController()
        searchVC.delegate = self
        present(UINavigationController(rootViewController: searchVC), animated: true)
    }
}

// MARK: - UITableViewDataSource & Delegate
extension DetailInfoViewController: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int {
        return 2 + viewModel.tableViewDataSource.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section < 2 { return 1 }
        return viewModel.tableViewDataSource[section - 2].values.first?.count ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = UITableViewCell(style: .value1, reuseIdentifier: "TimeCell")
            cell.textLabel?.text = R.string.localizable.viewAddDate()
            cell.detailTextLabel?.text = viewModel.timeStamp ?? "---"
            cell.accessoryType = .disclosureIndicator
            cell.imageView?.image = UIImage(systemName: "calendar")
            return cell
        } else if indexPath.section == 1 {
            let cell = UITableViewCell(style: .value1, reuseIdentifier: "LocationCell")
            cell.textLabel?.text = R.string.localizable.viewAddLocation()
            if let displayText = viewModel.locationDisplayText {
                cell.detailTextLabel?.text = displayText
            } else if let location = viewModel.location {
                cell.detailTextLabel?.text = "\(location.coordinate.latitude), \(location.coordinate.longitude)"
            } else {
                cell.detailTextLabel?.text = "---"
            }
            cell.accessoryType = .disclosureIndicator
            cell.imageView?.image = UIImage(systemName: "mappin.and.ellipse")
            return cell
        }

        guard let cell = tableView.dequeueReusableCell(withIdentifier: String(describing: DetailTableViewCell.self), for: indexPath) as? DetailTableViewCell else {
            return UITableViewCell()
        }

        if let sectionDataSource = viewModel.tableViewDataSource[indexPath.section - 2].values.first {
            cell.cellDataSource = sectionDataSource[indexPath.row]
        }
        return cell
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if section < 2 { return nil }
        let headerView = DetailSectionHeaderView()
        headerView.headerTitle = viewModel.tableViewDataSource[section - 2].keys.first ?? ""
        return headerView
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return section < 2 ? 0.1 : 50
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 0 {
            showDatePicker()
        } else if indexPath.section == 1 {
            showLocationSearch()
        }
    }
}

// MARK: - Logic & Alerts
fileprivate extension DetailInfoViewController {
    func deleteAlert(completionHandler: @escaping (EditAlertAction) -> Void) {
        let message = viewModel.isLivePhoto ? R.string.localizable.alertLiveAlertDesc() : R.string.localizable.alertConfirmDesc()
        let alert = UIAlertController(title: R.string.localizable.alertConfirm(), message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: R.string.localizable.alertAddAndDel(), style: .destructive) { _ in completionHandler(.addAndDel) })
        alert.addAction(UIAlertAction(title: R.string.localizable.alertAdd(), style: .default) { _ in completionHandler(.add) })
        alert.addAction(UIAlertAction(title: R.string.localizable.alertCancel(), style: .cancel) { _ in completionHandler(.cancel) })
        present(alert, animated: true)
    }
}

// MARK: - Delegates
extension DetailInfoViewController: UIPopoverPresentationControllerDelegate, LocationSearchDelegate {

    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }

    func popoverPresentationControllerDidDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) {
        if let datePicker = popoverPresentationController.presentedViewController as? DetailDatePickerPopover {
            deleteAlert { [weak self] action in
                guard let self = self, action != .cancel else { return }
                Task { await self.viewModel.addTimeStamp(datePicker.curDate, deleteOriginal: action == .addAndDel) }
            }
        }
    }

    func didSelect(_ model: LocationModel) {
        guard let coord = model.coordinate else {
            SVProgressHUD.showCustomErrorHUD(with: R.string.localizable.errorCoordinateFetch())
            return
        }
        deleteAlert { [weak self] action in
            guard let self = self, action != .cancel else { return }
            Task { await self.viewModel.addLocation(CLLocation(latitude: coord.latitude, longitude: coord.longitude), deleteOriginal: action == .addAndDel) }
        }
    }
}

// MARK: - PHPhotoLibraryChangeObserver
extension DetailInfoViewController: PHPhotoLibraryChangeObserver {
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        Task { @MainActor in
            guard let curAsset = viewModel.asset, let details = changeInstance.changeDetails(for: curAsset) else { return }
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
