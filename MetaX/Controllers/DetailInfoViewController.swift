//
//  DetailInfoViewController.swift
//  MetaX
//
//  Created by Ckitakishi on 2018/3/20.
//  Copyright © 2018 Yuhan Chen. All rights reserved.
//

import UIKit
import Photos
import MapKit
import PhotosUI
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

    // MARK: - Dependencies
    private let viewModel: DetailInfoViewModel
    private let container: DependencyContainer
    
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

    private lazy var moreMenuButton: UIBarButtonItem = {
        let editAction = UIAction(
            title: String(localized: .viewEditMetadata),
            image: UIImage(systemName: "pencil.and.outline")
        ) { [weak self] _ in
            self?.showMetadataEditor()
        }
        
        let removeAllAction = UIAction(
            title: String(localized: .viewClearAllMetadata),
            image: UIImage(systemName: "trash")
        ) { [weak self] _ in
            self?.clearAllMetadata()
        }
        
        let menu = UIMenu(title: "", children: [editAction, removeAllAction])
        return UIBarButtonItem(image: UIImage(systemName: "slider.horizontal.3"), menu: menu)
    }()

    // MARK: - Initialization

    init(container: DependencyContainer) {
        self.container = container
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
    
    func configure(with asset: PHAsset?, collection: PHAssetCollection?) {
        if let asset = asset {
            viewModel.configure(with: asset, collection: collection)
        }
    }

    // MARK: - Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupBindings()
        PHPhotoLibrary.shared().register(self)

    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateHeaderHeight()
        viewModel.loadPhoto(targetSize: targetSize)
        Task {
            await viewModel.loadMetadata()
        }
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
        navigationItem.rightBarButtonItem = moreMenuButton

        // TableView setup
        view.addSubview(tableView)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(DetailTableViewCell.self, forCellReuseIdentifier: String(describing: DetailTableViewCell.self))
        tableView.register(DetailLocationCell.self, forCellReuseIdentifier: String(describing: DetailLocationCell.self))

        // Header Setup
        let headerContainer = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: Theme.Layout.heroHeaderHeight))
        headerContainer.addSubview(heroCardView)
        heroCardView.addSubview(heroImageView)

        let cardTrailing = heroCardView.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor, constant: -Theme.Layout.cardPadding)
        cardTrailing.priority = UILayoutPriority(999)
        
        let imageTrailing = heroImageView.trailingAnchor.constraint(equalTo: heroCardView.trailingAnchor, constant: -HeroLayout.inset)
        imageTrailing.priority = UILayoutPriority(999)

        NSLayoutConstraint.activate([
            heroCardView.topAnchor.constraint(equalTo: headerContainer.topAnchor, constant: Theme.Layout.cardPadding),
            heroCardView.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor, constant: Theme.Layout.cardPadding),
            cardTrailing,
            heroCardView.bottomAnchor.constraint(equalTo: headerContainer.bottomAnchor, constant: -Theme.Layout.cardPadding),

            heroImageView.topAnchor.constraint(equalTo: heroCardView.topAnchor, constant: HeroLayout.inset),
            heroImageView.leadingAnchor.constraint(equalTo: heroCardView.leadingAnchor, constant: HeroLayout.inset),
            imageTrailing,
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
            h.backgroundColor = Theme.Colors.border
            h.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(h)

            let v = UIView()
            v.backgroundColor = Theme.Colors.border
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
        let scale = traitCollection.displayScale
        let headerHeight = tableView.tableHeaderView?.frame.height ?? Theme.Layout.heroHeaderHeight
        return CGSize(width: ceil(view.bounds.width * scale), height: ceil(headerHeight * scale))
    }

    // MARK: - Bindings
    private func setupBindings() {
        observe(viewModel: viewModel, property: { $0.image }) { [weak self] image in
            self?.heroImageView.image = image
        }

        observe(viewModel: viewModel, property: { $0.isSaving }) { [weak self] isSaving in
            self?.view.isUserInteractionEnabled = !isSaving
            if isSaving {
                HUD.showProcessing(with: String(localized: .viewProcessing))
            } else {
                HUD.dismiss()
            }
        }

        observe(viewModel: viewModel, property: { $0.error }) { [weak self] error in
            if let error = error {
                HUD.showError(with: error.localizedDescription)
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

    private func showMetadataEditor() {
        guard let metadata = viewModel.metadata else { return }
        let editorVC = MetadataEditViewController(metadata: metadata, container: container)
        editorVC.delegate = self
        let nav = UINavigationController(rootViewController: editorVC)
        present(nav, animated: true)
    }
}

// MARK: - UITableViewDataSource & Delegate
extension DetailInfoViewController: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int {
        return viewModel.tableViewDataSource.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.tableViewDataSource[section].rows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let sectionData = viewModel.tableViewDataSource[indexPath.section]
        let rowData = sectionData.rows[indexPath.row]
        let isFirst = indexPath.row == 0
        let isLast = indexPath.row == sectionData.rows.count - 1
        
        // Use DetailLocationCell if it's the location row and we have coordinate data
        if rowData.prop == String(localized: .viewAddLocation),
           let location = viewModel.currentLocation {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: String(describing: DetailLocationCell.self), for: indexPath) as? DetailLocationCell else {
                return UITableViewCell()
            }
            cell.configure(model: rowData, location: location, isFirst: isFirst, isLast: isLast)
            return cell
        }
        
        guard let cell = tableView.dequeueReusableCell(withIdentifier: String(describing: DetailTableViewCell.self), for: indexPath) as? DetailTableViewCell else {
            return UITableViewCell()
        }

        cell.cellDataSource = rowData
        // Apply borders immediately for standard cells
        cell.applyCardBorders(isFirst: isFirst, isLast: isLast)
        return cell
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerView = DetailSectionHeaderView()
        headerView.headerTitle = viewModel.tableViewDataSource[section].section.localizedTitle
        return headerView
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return Theme.Layout.sectionHeaderHeight
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        if let cell = tableView.cellForRow(at: indexPath) as? DetailLocationCell, let location = cell.currentLocation {
            openFullMap(for: location)
        }
    }
}

fileprivate extension DetailInfoViewController {
    func openFullMap(for location: CLLocation) {
        let mapVC = UIViewController()
        mapVC.title = String(localized: .viewAddLocation)
        let fullMapView = MKMapView()
        fullMapView.translatesAutoresizingMaskIntoConstraints = false
        fullMapView.setRegion(MKCoordinateRegion(center: location.coordinate, latitudinalMeters: 1000, longitudinalMeters: 1000), animated: false)

        let annotation = MKPointAnnotation()
        annotation.coordinate = location.coordinate
        fullMapView.addAnnotation(annotation)

        mapVC.view.addSubview(fullMapView)
        NSLayoutConstraint.activate([
            fullMapView.topAnchor.constraint(equalTo: mapVC.view.topAnchor),
            fullMapView.leadingAnchor.constraint(equalTo: mapVC.view.leadingAnchor),
            fullMapView.trailingAnchor.constraint(equalTo: mapVC.view.trailingAnchor),
            fullMapView.bottomAnchor.constraint(equalTo: mapVC.view.bottomAnchor)
        ])

        let nav = UINavigationController(rootViewController: mapVC)
        mapVC.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(dismissMap))
        present(nav, animated: true)
    }
    
    @objc func dismissMap() {
        dismiss(animated: true)
    }
    
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
            HUD.showError(with: String(localized: .errorCoordinateFetch))
            return
        }
        deleteAlert { [weak self] action in
            guard let self = self, action != .cancel else { return }
            Task { await self.viewModel.addLocation(CLLocation(latitude: coord.latitude, longitude: coord.longitude), deleteOriginal: action == .addAndDel) }
        }
    }
}

// MARK: - MetadataEditDelegate
extension DetailInfoViewController: MetadataEditDelegate {
    func metadataEditDidSave(fields: [String: Any], completion: @escaping (Bool) -> Void) {
        deleteAlert { [weak self] action in
            guard let self = self, action != .cancel else {
                completion(false)
                return
            }
            completion(true)
            Task {
                await self.viewModel.applyMetadataTemplate(fields: fields, deleteOriginal: action == .addAndDel)
            }
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
