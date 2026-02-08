//
//  DetailInfoViewController.swift
//  MetaX
//
//  Created by Ckitakishi on 2018/3/20.
//  Copyright © 2018 Yuhan Chen. All rights reserved.
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

    private enum HeroLayout {
        static let inset: CGFloat = 8
        static let cornerLength: CGFloat = 20
        static let cornerThickness: CGFloat = 3
    }

    // MARK: - ViewModel
    private let viewModel: DetailInfoViewModel

    // MARK: - UI Components
    private let tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .grouped)
        table.backgroundColor = .clear
        table.separatorStyle = .none
        table.translatesAutoresizingMaskIntoConstraints = false
        return table
    }()

    private let heroCardView: UIView = {
        let view = UIView()
        view.backgroundColor = Theme.Colors.cardBackground
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let heroImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.backgroundColor = Theme.Colors.cardBackground
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private lazy var clearAllButton: UIBarButtonItem = {
        UIBarButtonItem(image: UIImage(systemName: "trash"), style: .plain, target: self, action: #selector(clearAllMetadata))
    }()

    // MARK: - Properties
    var asset: PHAsset?
    var assetCollection: PHAssetCollection?

    // MARK: - Initialization

    init(container: DependencyContainer) {
        self.viewModel = DetailInfoViewModel(
            metadataService: container.metadataService,
            imageSaveService: container.imageSaveService,
            photoLibraryService: container.photoLibraryService
        )
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

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
        view.backgroundColor = Theme.Colors.mainBackground
        navigationItem.rightBarButtonItem = clearAllButton

        // TableView setup
        view.addSubview(tableView)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(DetailTableViewCell.self, forCellReuseIdentifier: String(describing: DetailTableViewCell.self))

        // Header Setup
        let headerContainer = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 320))
        headerContainer.addSubview(heroCardView)
        heroCardView.addSubview(heroImageView)

        NSLayoutConstraint.activate([
            heroCardView.topAnchor.constraint(equalTo: headerContainer.topAnchor, constant: Theme.Layout.cardPadding),
            heroCardView.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor, constant: Theme.Layout.cardPadding),
            heroCardView.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor, constant: -Theme.Layout.cardPadding),
            heroCardView.bottomAnchor.constraint(equalTo: headerContainer.bottomAnchor, constant: -Theme.Layout.cardPadding),

            heroImageView.topAnchor.constraint(equalTo: heroCardView.topAnchor, constant: HeroLayout.inset),
            heroImageView.leadingAnchor.constraint(equalTo: heroCardView.leadingAnchor, constant: HeroLayout.inset),
            heroImageView.trailingAnchor.constraint(equalTo: heroCardView.trailingAnchor, constant: -HeroLayout.inset),
            heroImageView.bottomAnchor.constraint(equalTo: heroCardView.bottomAnchor, constant: -HeroLayout.inset)
        ])
        
        addCornerMarks(to: heroCardView)
        tableView.tableHeaderView = headerContainer

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func addCornerMarks(to view: UIView) {
        let length = HeroLayout.cornerLength
        let thickness = HeroLayout.cornerThickness

        // (xAnchor, isLeading, yAnchor, isTop)
        let corners: [(NSLayoutXAxisAnchor, Bool, NSLayoutYAxisAnchor, Bool)] = [
            (view.leadingAnchor,  true,  view.topAnchor,    true),
            (view.trailingAnchor, false, view.topAnchor,    true),
            (view.leadingAnchor,  true,  view.bottomAnchor, false),
            (view.trailingAnchor, false, view.bottomAnchor, false),
        ]

        for (xAnchor, isLeading, yAnchor, isTop) in corners {
            let h = UIView()
            h.backgroundColor = .black
            h.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(h)

            let v = UIView()
            v.backgroundColor = .black
            v.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(v)

            NSLayoutConstraint.activate([
                h.leadingAnchor.constraint(equalTo: xAnchor, constant: isLeading ? 0 : -length),
                h.topAnchor.constraint(equalTo: yAnchor, constant: isTop ? 0 : -thickness),
                h.widthAnchor.constraint(equalToConstant: length),
                h.heightAnchor.constraint(equalToConstant: thickness),

                v.leadingAnchor.constraint(equalTo: xAnchor, constant: isLeading ? 0 : -thickness),
                v.topAnchor.constraint(equalTo: yAnchor, constant: isTop ? 0 : -length),
                v.widthAnchor.constraint(equalToConstant: thickness),
                v.heightAnchor.constraint(equalToConstant: length),
            ])
        }
    }

    private func updateHeaderHeight() {
        guard let asset = viewModel.asset else { return }
        let padding = Theme.Layout.cardPadding
        let cardWidth = view.bounds.width - padding * 2
        let cardHeight: CGFloat
        if asset.pixelWidth > asset.pixelHeight {
            cardHeight = cardWidth * CGFloat(asset.pixelHeight) / CGFloat(asset.pixelWidth)
        } else {
            cardHeight = cardWidth
        }
        if let header = tableView.tableHeaderView {
            header.frame.size = CGSize(width: view.bounds.width, height: cardHeight + padding * 2)
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
                SVProgressHUD.showProcessingHUD(with: String(localized: .viewProcessing))
            } else {
                SVProgressHUD.dismiss()
            }
        }

        observe(viewModel: viewModel, property: { $0.error }) { [weak self] error in
            if let error = error {
                SVProgressHUD.showCustomErrorHUD(with: error.localizedDescription)
                if case .metadata(.unsupportedMediaType) = error {
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
        guard let cell = tableView.dequeueReusableCell(withIdentifier: String(describing: DetailTableViewCell.self), for: indexPath) as? DetailTableViewCell else {
            return UITableViewCell()
        }
        switch indexPath.section {
        case 0:
            cell.cellDataSource = DetailCellModel(prop: String(localized: .viewAddDate), value: viewModel.timeStamp ?? "---")
        case 1:
            let locationText = viewModel.locationDisplayText
                ?? viewModel.location.map { "\($0.coordinate.latitude), \($0.coordinate.longitude)" }
                ?? "---"
            cell.cellDataSource = DetailCellModel(prop: String(localized: .viewAddLocation), value: locationText)
        default:
            if let sectionData = viewModel.tableViewDataSource[indexPath.section - 2].values.first {
                cell.cellDataSource = sectionData[indexPath.row]
            }
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
        return section < 2 ? 0.1 : Theme.Layout.sectionHeaderHeight
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let detailCell = cell as? DetailTableViewCell else { return }
        let isFirst = indexPath.row == 0
        let isLast = indexPath.row == tableView.numberOfRows(inSection: indexPath.section) - 1
        detailCell.applyCardBorders(isFirst: isFirst, isLast: isLast)
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
        let message = viewModel.isLivePhoto ? String(localized: .alertLiveAlertDesc) : String(localized: .alertConfirmDesc)
        let alert = UIAlertController(title: String(localized: .alertConfirm), message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: String(localized: .alertAddAndDel), style: .destructive) { _ in completionHandler(.addAndDel) })
        alert.addAction(UIAlertAction(title: String(localized: .alertAdd), style: .default) { _ in completionHandler(.add) })
        alert.addAction(UIAlertAction(title: String(localized: .alertCancel), style: .cancel) { _ in completionHandler(.cancel) })
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
            SVProgressHUD.showCustomErrorHUD(with: String(localized: .errorCoordinateFetch))
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
