//
//  AlbumViewController.swift
//  MetaX
//
//  Created by Ckitakishi on 2018/3/20.
//  Copyright © 2018 Yuhan Chen. All rights reserved.
//

import Photos
import UIKit

class AlbumViewController: UITableViewController, ViewModelObserving {

    // MARK: - ViewModel

    private let viewModel: AlbumViewModel

    // MARK: - Intent Closures

    var onSelectAlbum: ((PHFetchResult<PHAsset>, PHAssetCollection?, String) -> Void)?
    var onRequestSettings: (() -> Void)?

    // MARK: - Properties

    var splashDismissHandler: (() -> Void)?
    private var isHeroImageLoaded = false

    private let sectionTitles = [
        "",
        String(localized: .viewMyAlbums),
        String(localized: .viewSmartAlbums),
    ]

    private let searchController = UISearchController(searchResultsController: nil)

    // MARK: - Initialization

    init(viewModel: AlbumViewModel) {
        self.viewModel = viewModel
        super.init(style: .grouped)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
        checkAuthorizationAndLoad()
        setupBindings()
    }

    deinit {
        let vm = viewModel
        Task { @MainActor in
            vm.unregisterPhotoLibraryObserver()
        }
    }

    // MARK: - UI Setup

    private func setupUI() {
        let titleLabel = UILabel()
        let attributedString = NSMutableAttributedString(string: "METAX")
        attributedString.addAttribute(.kern, value: 1.5, range: NSRange(location: 0, length: 5))
        titleLabel.attributedText = attributedString
        titleLabel.font = Theme.Typography.navBrand
        titleLabel.textColor = .secondaryLabel
        navigationItem.titleView = titleLabel

        navigationController?.navigationBar.prefersLargeTitles = false
        navigationItem.largeTitleDisplayMode = .never

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "gearshape"),
            style: .plain,
            target: self,
            action: #selector(didTapSettings)
        )
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "arrow.up.arrow.down"),
            style: .plain,
            target: nil,
            action: nil
        )
        navigationItem.rightBarButtonItem?.menu = makeSortMenu()

        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = String(localized: .viewMyAlbums)
        navigationItem.hidesSearchBarWhenScrolling = true
        definesPresentationContext = true

        tableView.backgroundColor = Theme.Colors.mainBackground
        tableView.separatorStyle = .none
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 120
        tableView.sectionHeaderTopPadding = 0
        tableView.prefetchDataSource = self
        tableView.showsVerticalScrollIndicator = false
        tableView.register(
            AlbumHeroTableViewCell.self,
            forCellReuseIdentifier: String(describing: AlbumHeroTableViewCell.self)
        )
        tableView.register(
            AlbumStandardTableViewCell.self,
            forCellReuseIdentifier: String(describing: AlbumStandardTableViewCell.self)
        )
    }

    @objc private func didTapSettings() {
        onRequestSettings?()
    }

    private var standardThumbnailSize: CGSize {
        let scale = traitCollection.displayScale
        let side = max(1, ceil(Theme.Layout.thumbnailSize * scale))
        return CGSize(width: side, height: side)
    }

    private var heroThumbnailSize: CGSize {
        let scale = traitCollection.displayScale
        let width = max(1, view.bounds.width - 2 * Theme.Layout.standardPadding)
        return CGSize(width: ceil(width * scale), height: ceil(width * Theme.Layout.heroAspectRatio * scale))
    }

    private func makeSortMenu() -> UIMenu {
        let actions = AlbumSortOption.allCases.map { option in
            UIAction(
                title: option.title,
                state: viewModel.sortOption == option ? .on : .off
            ) { [weak self] _ in
                self?.viewModel.sortOption = option
                self?.navigationItem.rightBarButtonItem?.menu = self?.makeSortMenu()
            }
        }
        return UIMenu(children: actions)
    }

    // MARK: - Bindings

    private func setupBindings() {
        observe(viewModel: viewModel, property: { $0.isAuthorized }) { [weak self] in
            $0 ? self?.removeLockView() : self?.showLockView()
        }

        observe(viewModel: viewModel, property: { $0.isSearchAvailable }) { [weak self] isAvailable in
            guard let self else { return }
            self.navigationItem.searchController = isAvailable ? self.searchController : nil
        }

        observe(viewModel: viewModel, property: { $0.reloadToken }) { [weak self] _ in
            guard let self, self.viewModel.allPhotos != nil else { return }
            self.tableView.reloadData()
        }

        observe(viewModel: viewModel, property: { $0.pendingLoadsCount }) { [weak self] count in
            guard count == 0 else { return }
            self?.checkSplashDismissal()
        }
    }

    private func handleInitialLoad() {
        tableView.reloadData()
        tableView.layoutIfNeeded()
        checkSplashDismissal()
    }

    // MARK: - Splash

    private func checkSplashDismissal() {
        guard splashDismissHandler != nil,
              isHeroImageLoaded,
              viewModel.pendingLoadsCount == 0 else { return }
        splashDismissHandler?()
        splashDismissHandler = nil
    }

    private func checkAuthorizationAndLoad() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            if await viewModel.authorizeAndLoad() {
                handleInitialLoad()
            } else {
                splashDismissHandler?()
                splashDismissHandler = nil
            }
        }
    }

    private static let lockViewTag = 9001

    private func showLockView() {
        guard let topView = navigationController?.view,
              topView.viewWithTag(AlbumViewController.lockViewTag) == nil else { return }
        let lockView = AuthLockView()
        lockView.tag = AlbumViewController.lockViewTag
        lockView.frame = topView.frame
        lockView.delegate = self
        lockView.title = String(localized: .alertPhotoAccess)
        lockView.detail = String(localized: .alertPhotoAccessDesc)
        lockView.buttonTitle = String(localized: .alertPhotoAuth)
        topView.addSubview(lockView)
    }

    private func removeLockView() {
        navigationController?.view.viewWithTag(AlbumViewController.lockViewTag)?.removeFromSuperview()
    }
}

// MARK: - UITableViewDataSource & Delegate

extension AlbumViewController {

    override func numberOfSections(in tableView: UITableView) -> Int {
        return AlbumSection.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let albumSection = AlbumSection(rawValue: section) else { return 0 }
        return viewModel.numberOfRows(in: albumSection)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let (title, count, asset) = viewModel.albumInfo(at: indexPath)
        let collectionId = viewModel.collectionIdentifier(at: indexPath)

        if indexPath.section == 0 {
            guard let cell = tableView.dequeueReusableCell(
                withIdentifier: String(describing: AlbumHeroTableViewCell.self),
                for: indexPath
            ) as? AlbumHeroTableViewCell else {
                return UITableViewCell()
            }
            cell.representedIdentifier = "allPhotos"
            cell.title = title
            cell.count = count
            cell.thumbnail = nil

            if let asset {
                cell.imageLoadTask?.cancel()
                cell.imageLoadTask = Task { @MainActor [weak self, weak cell] in
                    guard let self, let cell else { return }
                    for await (image, isDegraded) in viewModel.requestThumbnailStream(
                        for: asset,
                        targetSize: heroThumbnailSize
                    ) {
                        guard !Task.isCancelled else { break }
                        if !isDegraded {
                            isHeroImageLoaded = true
                            checkSplashDismissal()
                        }
                        guard cell.representedIdentifier == "allPhotos" else { break }
                        cell.thumbnail = image
                    }
                }
            } else if viewModel.allPhotos != nil {
                isHeroImageLoaded = true
                checkSplashDismissal()
            }
            return cell
        } else {
            guard let cell = tableView.dequeueReusableCell(
                withIdentifier: String(describing: AlbumStandardTableViewCell.self),
                for: indexPath
            ) as? AlbumStandardTableViewCell else {
                return UITableViewCell()
            }
            cell.representedIdentifier = collectionId
            cell.title = title
            cell.count = count
            cell.thumbnail = nil

            // Show cached cover immediately if available
            if let asset {
                cell.imageLoadTask?.cancel()
                cell.imageLoadTask = Task { @MainActor [weak self, weak cell] in
                    guard let self, let cell else { return }
                    for await (image, _) in viewModel.requestThumbnailStream(
                        for: asset,
                        targetSize: standardThumbnailSize
                    ) {
                        guard !Task.isCancelled else { break }
                        guard cell.representedIdentifier == collectionId else { break }
                        cell.thumbnail = image
                    }
                }
            }

            // Async-load count + thumbnail if not yet cached (no-op when already cached).
            // Note: Keeping this completion-based for now as it handles complex synchronization
            // within the ViewModel, but image loading is now Task-based above.
            viewModel
                .loadCellDataIfNeeded(at: indexPath, thumbnailSize: standardThumbnailSize) { [weak cell] count, image in
                    guard let cell, cell.representedIdentifier == collectionId else { return }
                    cell.count = count
                    if let image { cell.thumbnail = image }
                }

            return cell
        }
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerTitle = sectionTitles[section]
        if section == 0 || headerTitle.isEmpty { return nil }

        let headerView = DetailSectionHeaderView()
        headerView.headerTitle = headerTitle
        return headerView
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if section == 0 { return CGFloat.leastNonzeroMagnitude }
        guard let albumSection = AlbumSection(rawValue: section) else { return 0 }
        if viewModel.numberOfRows(in: albumSection) == 0 {
            return CGFloat.leastNonzeroMagnitude
        }
        return Theme.Layout.sectionHeaderHeight
    }

    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return nil
    }

    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return section == 0 ? Theme.Layout.stackSpacing : 0.1
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let (fetchResult, collection, title) = viewModel.fetchResult(for: indexPath)
        guard let fetchResult = fetchResult, let title = title else { return }
        onSelectAlbum?(fetchResult, collection, title)
    }
}

// MARK: - AuthLockViewDelegate

extension AlbumViewController: AuthLockViewDelegate {

    func toSetting() {
        viewModel.guideToSettings()
    }
}

// MARK: - UITableViewDataSourcePrefetching

extension AlbumViewController: UITableViewDataSourcePrefetching {

    func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
        for indexPath in indexPaths where indexPath.section != 0 {
            viewModel.loadCellDataIfNeeded(at: indexPath, thumbnailSize: standardThumbnailSize) { _, _ in }
        }
    }

    func tableView(_ tableView: UITableView, cancelPrefetchingForRowsAt indexPaths: [IndexPath]) {
        viewModel.stopCachingThumbnails(for: indexPaths, targetSize: standardThumbnailSize)
    }
}

// MARK: - UISearchResultsUpdating

extension AlbumViewController: UISearchResultsUpdating {

    func updateSearchResults(for searchController: UISearchController) {
        viewModel.searchText = searchController.searchBar.text ?? ""
    }
}
