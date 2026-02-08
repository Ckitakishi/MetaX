//
//  AlbumViewController.swift
//  MetaX
//
//  Created by Ckitakishi on 2018/3/20.
//  Copyright © 2018 Yuhan Chen. All rights reserved.
//

import UIKit
import Photos

class AlbumViewController: UITableViewController, ViewModelObserving {

    // MARK: - Dependencies

    private let container: DependencyContainer

    // MARK: - ViewModel

    private let viewModel: AlbumViewModel

    // MARK: - Properties

    private let sectionTitles = [
        "",
        String(localized: .viewMyAlbums),
        String(localized: .viewSmartAlbums)
    ]

    private let searchController = UISearchController(searchResultsController: nil)

    // MARK: - Initialization

    init(container: DependencyContainer) {
        self.container = container
        self.viewModel = AlbumViewModel(photoLibraryService: container.photoLibraryService)
        super.init(style: .grouped)
    }

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
        titleLabel.font = .monospacedDigitSystemFont(ofSize: 10, weight: .bold)
        titleLabel.textColor = .secondaryLabel
        navigationItem.titleView = titleLabel

        navigationController?.navigationBar.prefersLargeTitles = false
        navigationItem.largeTitleDisplayMode = .never

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "gearshape"),
            style: .plain,
            target: nil,
            action: nil
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
        tableView.register(AlbumHeroTableViewCell.self, forCellReuseIdentifier: String(describing: AlbumHeroTableViewCell.self))
        tableView.register(AlbumStandardTableViewCell.self, forCellReuseIdentifier: String(describing: AlbumStandardTableViewCell.self))
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
        observe(viewModel: viewModel, property: { $0.isAuthorized }) { [weak self] isAuthorized in
            if !isAuthorized {
                self?.showLockView()
            }
        }

        observe(viewModel: viewModel, property: { $0.reloadToken }) { [weak self] _ in
            self?.tableView.reloadData()
        }
    }

    private func checkAuthorizationAndLoad() {
        PHPhotoLibrary.checkAuthorizationStatus { [weak self] status in
            guard let self = self else { return }
            if status {
                Task { @MainActor in
                    self.viewModel.loadAlbums()
                    self.viewModel.registerPhotoLibraryObserver()
                    self.tableView.reloadData()
                }
            } else {
                Task { @MainActor in
                    self.showLockView()
                }
            }
        }
    }

    private func showLockView() {
        let lockView = AuthLockView()
        if let topView = navigationController?.view {
            lockView.frame = topView.frame
            lockView.delegate = self
            lockView.title = String(localized: .alertPhotoAccess)
            lockView.detail = String(localized: .alertPhotoAccessDesc)
            lockView.buttonTitle = String(localized: .alertPhotoAuth)
            topView.addSubview(lockView)
        }
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

        if indexPath.section == 0 {
            guard let cell = tableView.dequeueReusableCell(
                withIdentifier: String(describing: AlbumHeroTableViewCell.self),
                for: indexPath
            ) as? AlbumHeroTableViewCell else {
                return UITableViewCell()
            }
            cell.title = title
            cell.count = count
            if let asset = asset {
                viewModel.getThumbnail(for: asset, targetSize: CGSize(width: 600, height: 600)) { [weak cell] image in
                    Task { @MainActor in cell?.thumnail = image }
                }
            }
            return cell
        } else {
            guard let cell = tableView.dequeueReusableCell(
                withIdentifier: String(describing: AlbumStandardTableViewCell.self),
                for: indexPath
            ) as? AlbumStandardTableViewCell else {
                return UITableViewCell()
            }
            cell.title = title
            cell.count = count
            if let asset = asset {
                viewModel.getThumbnail(for: asset, targetSize: CGSize(width: 200, height: 200)) { [weak cell] image in
                    Task { @MainActor in cell?.thumnail = image }
                }
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
        return Theme.Layout.sectionHeaderHeight
    }

    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return nil
    }

    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return section == 0 ? 24 : 0.1
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let (fetchResult, collection, title) = viewModel.fetchResult(for: indexPath)
        let destination = PhotoGridViewController(container: container)
        destination.configureWithViewModel(fetchResult: fetchResult, collection: collection)
        destination.title = title

        splitViewController?.showDetailViewController(
            UINavigationController(rootViewController: destination),
            sender: self
        )
    }
}

// MARK: - AuthLockViewDelegate

extension AlbumViewController: AuthLockViewDelegate {

    func toSetting() {
        PHPhotoLibrary.guideToSetting()
    }
}

// MARK: - UISearchResultsUpdating

extension AlbumViewController: UISearchResultsUpdating {

    func updateSearchResults(for searchController: UISearchController) {
        viewModel.searchText = searchController.searchBar.text ?? ""
    }
}
