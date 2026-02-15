//
//  DetailInfoViewController.swift
//  MetaX
//
//  Created by Ckitakishi on 2018/3/20.
//  Copyright © 2018 Yuhan Chen. All rights reserved.
//

import CoreLocation
import MapKit
import Photos
import PhotosUI
import UIKit

class DetailInfoViewController: UIViewController, ViewModelObserving {

    private enum HeroLayout {
        static let inset: CGFloat = 8
        static let cornerLength: CGFloat = 20
        static let cornerThickness: CGFloat = 3
    }

    // MARK: - Badge Constraints

    private var badgeLeadingConstraint: NSLayoutConstraint?
    private var badgeTopConstraint: NSLayoutConstraint?

    // MARK: - Dependencies

    private let viewModel: DetailInfoViewModel
    private let container: DependencyContainer
    var router: AppRouter?

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

    private let heroLivePhotoView: PHLivePhotoView = {
        let view = PHLivePhotoView()
        view.isMuted = true
        view.contentMode = .scaleAspectFit
        view.clipsToBounds = true
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let heroBadgeView: UIImageView = {
        let iv = UIImageView()
        iv.image = PHLivePhotoView.livePhotoBadgeImage(options: .overContent)
        iv.contentMode = .scaleAspectFit
        iv.isHidden = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private lazy var moreMenuButton: UIBarButtonItem = .init(
        image: UIImage(systemName: "slider.horizontal.3"),
        menu: UIMenu(title: "", children: [])
    )

    private func buildMoreMenu() -> UIMenu {
        let editAction = UIAction(
            title: String(localized: .viewEditMetadata),
            image: UIImage(systemName: "pencil.and.outline")
        ) { [weak self] _ in
            self?.showMetadataEditor()
        }

        let removeAllAction = UIAction(
            title: String(localized: .viewClearAllMetadata),
            image: UIImage(systemName: "trash"),
            attributes: .destructive
        ) { [weak self] _ in
            self?.clearAllMetadata()
        }

        var actions: [UIMenuElement] = [editAction]

        if viewModel.hasMetaXEdit {
            let revertAction = UIAction(
                title: String(localized: .viewRevertToOriginal),
                image: UIImage(systemName: "arrow.uturn.backward")
            ) { [weak self] _ in
                Task { await self?.viewModel.revertToOriginal() }
            }
            actions.append(revertAction)
        }

        actions.append(removeAllAction)
        return UIMenu(title: "", children: actions)
    }

    // MARK: - Initialization

    init(container: DependencyContainer) {
        self.container = container
        viewModel = DetailInfoViewModel(
            metadataService: container.metadataService,
            imageSaveService: container.imageSaveService,
            photoLibraryService: container.photoLibraryService
        )
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
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
        if viewModel.isLivePhoto {
            viewModel.loadLivePhoto(targetSize: targetSize)
        } else {
            viewModel.loadPhoto(targetSize: targetSize)
        }
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
        moreMenuButton.menu = buildMoreMenu()
        navigationItem.rightBarButtonItem = moreMenuButton

        // TableView setup
        view.addSubview(tableView)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(
            DetailTableViewCell.self,
            forCellReuseIdentifier: String(describing: DetailTableViewCell.self)
        )
        tableView.register(DetailLocationCell.self, forCellReuseIdentifier: String(describing: DetailLocationCell.self))

        // Header Setup
        let headerContainer = UIView(frame: CGRect(
            x: 0,
            y: 0,
            width: view.bounds.width,
            height: Theme.Layout.heroHeaderHeight
        ))
        headerContainer.addSubview(heroCardView)
        heroCardView.addSubview(heroImageView)
        heroCardView.addSubview(heroLivePhotoView)
        heroCardView.addSubview(heroBadgeView)

        let cardTrailing = heroCardView.trailingAnchor.constraint(
            equalTo: headerContainer.trailingAnchor,
            constant: -Theme.Layout.cardPadding
        )
        cardTrailing.priority = UILayoutPriority(999)

        let imageTrailing = heroImageView.trailingAnchor.constraint(
            equalTo: heroCardView.trailingAnchor,
            constant: -HeroLayout.inset
        )
        imageTrailing.priority = UILayoutPriority(999)
        let liveTrailing = heroLivePhotoView.trailingAnchor.constraint(
            equalTo: heroCardView.trailingAnchor,
            constant: -HeroLayout.inset
        )
        liveTrailing.priority = UILayoutPriority(999)

        NSLayoutConstraint.activate([
            heroCardView.topAnchor.constraint(equalTo: headerContainer.topAnchor, constant: Theme.Layout.cardPadding),
            heroCardView.leadingAnchor.constraint(
                equalTo: headerContainer.leadingAnchor,
                constant: Theme.Layout.cardPadding
            ),
            cardTrailing,
            heroCardView.bottomAnchor.constraint(
                equalTo: headerContainer.bottomAnchor,
                constant: -Theme.Layout.cardPadding
            ),

            heroImageView.topAnchor.constraint(equalTo: heroCardView.topAnchor, constant: HeroLayout.inset),
            heroImageView.leadingAnchor.constraint(equalTo: heroCardView.leadingAnchor, constant: HeroLayout.inset),
            imageTrailing,
            heroImageView.bottomAnchor.constraint(equalTo: heroCardView.bottomAnchor, constant: -HeroLayout.inset),

            heroLivePhotoView.topAnchor.constraint(equalTo: heroCardView.topAnchor, constant: HeroLayout.inset),
            heroLivePhotoView.leadingAnchor.constraint(equalTo: heroCardView.leadingAnchor, constant: HeroLayout.inset),
            liveTrailing,
            heroLivePhotoView.bottomAnchor.constraint(equalTo: heroCardView.bottomAnchor, constant: -HeroLayout.inset),

            heroBadgeView.widthAnchor.constraint(equalToConstant: 28),
            heroBadgeView.heightAnchor.constraint(equalToConstant: 28),
        ])

        let badgeLeading = heroBadgeView.leadingAnchor.constraint(equalTo: heroLivePhotoView.leadingAnchor, constant: 4)
        let badgeTop = heroBadgeView.topAnchor.constraint(equalTo: heroLivePhotoView.topAnchor, constant: 4)
        badgeLeadingConstraint = badgeLeading
        badgeTopConstraint = badgeTop
        NSLayoutConstraint.activate([
            badgeLeading,
            badgeTop,
        ])

        addCornerMarks(to: heroCardView)
        tableView.tableHeaderView = headerContainer

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func addCornerMarks(to view: UIView) {
        let length = HeroLayout.cornerLength
        let thickness = HeroLayout.cornerThickness

        let corners: [(NSLayoutXAxisAnchor, Bool, NSLayoutYAxisAnchor, Bool)] = [
            (view.leadingAnchor, true, view.topAnchor, true),
            (view.trailingAnchor, false, view.topAnchor, true),
            (view.leadingAnchor, true, view.bottomAnchor, false),
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

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateBadgePosition()
    }

    private func updateBadgePosition() {
        guard let asset = viewModel.asset,
              !heroLivePhotoView.isHidden,
              heroLivePhotoView.bounds.width > 0,
              heroLivePhotoView.bounds.height > 0,
              asset.pixelWidth > 0, asset.pixelHeight > 0 else { return }

        let viewW = heroLivePhotoView.bounds.width
        let viewH = heroLivePhotoView.bounds.height
        let scale = min(viewW / CGFloat(asset.pixelWidth), viewH / CGFloat(asset.pixelHeight))
        let xOffset = (viewW - CGFloat(asset.pixelWidth) * scale) / 2
        let yOffset = (viewH - CGFloat(asset.pixelHeight) * scale) / 2

        badgeLeadingConstraint?.constant = xOffset + 4
        badgeTopConstraint?.constant = yOffset + 4
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
        observe(viewModel: viewModel, property: { $0.heroContent }) { [weak self] content in
            guard let self else { return }
            switch content {
            case let .photo(image):
                heroImageView.image = image
                heroImageView.isHidden = false
                heroLivePhotoView.isHidden = true
                heroBadgeView.isHidden = true
            case let .livePhoto(livePhoto):
                heroLivePhotoView.livePhoto = livePhoto
                heroLivePhotoView.isHidden = false
                heroImageView.isHidden = true
                heroBadgeView.isHidden = false
                updateBadgePosition()
            case nil:
                break
            }
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

        observe(viewModel: viewModel, property: { $0.hasMetaXEdit }) { [weak self] _ in
            guard let self else { return }
            moreMenuButton.menu = buildMoreMenu()
        }
    }

    // MARK: - Actions

    @objc private func clearAllMetadata() {
        Task {
            guard let mode = await requestSaveMode(presentingVC: nil) else { return }
            await viewModel.clearAllMetadata(saveMode: mode)
        }
    }

    private func showMetadataEditor() {
        guard let metadata = viewModel.metadata else { return }
        let vc = MetadataEditViewController(metadata: metadata, container: container)
        let nav = UINavigationController(rootViewController: vc)

        vc.onSave = { [weak self, weak nav] fields in
            guard let self, let nav else { return }
            Task { @MainActor in
                guard let mode = await self.requestSaveMode(presentingVC: nav) else { return }
                let success = await self.viewModel.applyMetadataTemplate(fields: fields, saveMode: mode)
                if success {
                    nav.dismiss(animated: true)
                }
            }
        }
        vc.onCancel = { [weak self] in
            self?.dismiss(animated: true)
        }

        present(nav, animated: true) {
            nav.presentationController?.delegate = vc
        }
    }

    private func requestSaveMode(presentingVC: UIViewController?) async -> SaveWorkflowMode? {
        guard let mode = await router?.pickSaveWorkflow(on: presentingVC) else { return nil }
        if case .saveAsCopy = mode, viewModel.isLivePhoto {
            let confirmed = await confirmLivePhotoCopy(on: presentingVC ?? self)
            return confirmed ? mode : nil
        }
        return mode
    }

    private func confirmLivePhotoCopy(on presenter: UIViewController) async -> Bool {
        await withCheckedContinuation { continuation in
            let alert = UIAlertController(
                title: "Live Photo",
                message: String(localized: .alertLivePhotoCopyMessage),
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: String(localized: .alertContinue), style: .default) { _ in
                continuation.resume(returning: true)
            })
            alert.addAction(UIAlertAction(title: String(localized: .alertCancel), style: .cancel) { _ in
                continuation.resume(returning: false)
            })
            presenter.present(alert, animated: true)
        }
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

        if rowData.prop == String(localized: .viewAddLocation),
           let location = viewModel.currentLocation {
            guard let cell = tableView.dequeueReusableCell(
                withIdentifier: String(describing: DetailLocationCell.self),
                for: indexPath
            ) as? DetailLocationCell else {
                return UITableViewCell()
            }
            cell.configure(model: rowData, location: location, isFirst: isFirst, isLast: isLast)
            return cell
        }

        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: String(describing: DetailTableViewCell.self),
            for: indexPath
        ) as? DetailTableViewCell else {
            return UITableViewCell()
        }

        cell.cellDataSource = rowData
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
            router?.openLocationMap(for: location)
        }
    }
}

// MARK: - Delegates

extension DetailInfoViewController: UIPopoverPresentationControllerDelegate, LocationSearchDelegate {

    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }

    func popoverPresentationControllerDidDismissPopover(
        _ popoverPresentationController: UIPopoverPresentationController
    ) {
        if let datePicker = popoverPresentationController.presentedViewController as? DetailDatePickerPopover {
            Task {
                guard let mode = await requestSaveMode(presentingVC: nil) else { return }
                await viewModel.addTimeStamp(datePicker.curDate, saveMode: mode)
            }
        }
    }

    func didSelect(_ model: LocationModel) {
        guard let coord = model.coordinate else {
            HUD.showError(with: String(localized: .errorCoordinateFetch))
            return
        }
        Task {
            let loc = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
            guard let mode = await requestSaveMode(presentingVC: nil) else { return }
            await viewModel.addLocation(loc, saveMode: mode)
        }
    }
}

// MARK: - PHPhotoLibraryChangeObserver

extension DetailInfoViewController: PHPhotoLibraryChangeObserver {
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        Task { @MainActor in
            guard let curAsset = viewModel.asset,
                  let details = changeInstance.changeDetails(for: curAsset) else { return }
            viewModel.updateAsset(details.objectAfterChanges)
            guard viewModel.asset != nil else {
                navigationController?.popViewController(animated: true)
                return
            }
            if details.assetContentChanged {
                if viewModel.isLivePhoto {
                    viewModel.loadLivePhoto(targetSize: targetSize)
                } else {
                    viewModel.loadPhoto(targetSize: targetSize)
                }
                await viewModel.loadMetadata()
            }
        }
    }
}
