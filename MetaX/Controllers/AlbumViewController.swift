//
//  AlbumViewController.swift
//  MetaX
//
//  Created by Ckitakishi on 2018/3/20.
//  Copyright © 2018 Yuhan Chen. All rights reserved.
//

import UIKit

class AlbumViewController: UITableViewController, ViewModelObserving {

    // MARK: - Dependencies

    private let container: DependencyContainer
    var router: AppRouter?

    // MARK: - ViewModel

    private let viewModel: AlbumViewModel

    // MARK: - Properties

    var splashDismissHandler: (() -> Void)?
    private var isHeroImageLoaded = false
    private var currentSectionIndex = 0

    private var visibleSectionIndices: [Int] {
        return (0..<AlbumSection.count).filter {
            if $0 == 0 { return true }
            guard let section = AlbumSection(rawValue: $0) else { return false }
            return viewModel.numberOfRows(in: section) > 0
        }
    }

    private let sectionTitles = [
        "",
        String(localized: .viewMyAlbums),
        String(localized: .viewSmartAlbums),
    ]

    private let searchController = UISearchController(searchResultsController: nil)

    // MARK: - Initialization

    init(container: DependencyContainer) {
        self.container = container
        viewModel = AlbumViewModel(photoLibraryService: container.photoLibraryService)
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
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = true
        definesPresentationContext = true

        tableView.backgroundColor = Theme.Colors.mainBackground
        tableView.separatorStyle = .none
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 120
        tableView.sectionHeaderTopPadding = 0
        tableView.prefetchDataSource = self
        tableView.register(
            AlbumHeroTableViewCell.self,
            forCellReuseIdentifier: String(describing: AlbumHeroTableViewCell.self)
        )
        tableView.register(
            AlbumStandardTableViewCell.self,
            forCellReuseIdentifier: String(describing: AlbumStandardTableViewCell.self)
        )

        tableView.sectionIndexColor = Theme.Colors.text
        tableView.sectionIndexBackgroundColor = .clear
        tableView.sectionIndexTrackingBackgroundColor = .clear
    }

    @objc private func didTapSettings() {
        guard let nav = navigationController else { return }
        router?.viewSettings(from: nav)
    }

    private var standardThumbnailSize: CGSize {
        let scale = traitCollection.displayScale
        let side = ceil(Theme.Layout.thumbnailSize * scale)
        return CGSize(width: side, height: side)
    }

    private var heroThumbnailSize: CGSize {
        let scale = traitCollection.displayScale
        let width = view.bounds.width - 2 * Theme.Layout.cardPadding
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
                let requestID = viewModel.getThumbnail(for: asset, targetSize: heroThumbnailSize) { [
                    weak cell,
                    weak self
                ] image, isDegraded in
                    Task { @MainActor in
                        if !isDegraded {
                            self?.isHeroImageLoaded = true
                            self?.checkSplashDismissal()
                        }
                        guard cell?.representedIdentifier == "allPhotos" else { return }
                        cell?.thumbnail = image
                    }
                }
                cell.cancelThumbnailRequest = { [weak self] in
                    self?.viewModel.cancelThumbnailRequest(requestID)
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
                let requestID = viewModel
                    .getThumbnail(for: asset, targetSize: standardThumbnailSize) { [weak cell] image, _ in
                        // Guard inside Task to avoid TOCTOU: cell may be reused between
                        // the callback firing and the Task body executing on the main actor.
                        Task { @MainActor in
                            guard let cell, cell.representedIdentifier == collectionId else { return }
                            cell.thumbnail = image
                        }
                    }
                cell.cancelThumbnailRequest = { [weak self] in
                    self?.viewModel.cancelThumbnailRequest(requestID)
                }
            }

            // Async-load count + thumbnail if not yet cached (no-op when already cached).
            // Completion fires only when both count and first thumbnail image are ready.
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
        if self.tableView(tableView, numberOfRowsInSection: section) == 0 {
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

    override func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        let indices = visibleSectionIndices
        return indices.map { $0 == currentSectionIndex ? "●" : "○" }
    }

    override func tableView(_ tableView: UITableView, sectionForSectionIndexTitle title: String, at index: Int) -> Int {
        let indices = visibleSectionIndices
        return index < indices.count ? indices[index] : 0
    }

    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let currentOffset = scrollView.contentOffset.y
        let maximumOffset = scrollView.contentSize.height - scrollView.frame.size.height
        let visualTop = currentOffset + scrollView.adjustedContentInset.top

        var activeSection = 0
        let indices = visibleSectionIndices

        if maximumOffset > 0, currentOffset > 0, maximumOffset - currentOffset <= 20 {
            activeSection = indices.last ?? 0
        } else {
            for section in indices {
                let rect = tableView.rect(forSection: section)
                if rect.minY <= visualTop + 1, rect.maxY > visualTop + 1 {
                    activeSection = section
                    break
                }
            }
        }

        if currentSectionIndex != activeSection {
            currentSectionIndex = activeSection
            tableView.reloadSectionIndexTitles()
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let (fetchResult, collection, title) = viewModel.fetchResult(for: indexPath)
        let destination = PhotoGridViewController(container: container)
        destination.configureWithViewModel(fetchResult: fetchResult, collection: collection)
        destination.title = title
        // Pass the router down the chain
        destination.router = router

        splitViewController?.showDetailViewController(
            UINavigationController(rootViewController: destination),
            sender: self
        )
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
