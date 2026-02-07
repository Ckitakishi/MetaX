//
//  AlbumViewController.swift
//  MetaX
//
//  Created by Ckitakishi on 2018/3/20.
//  Copyright © 2018年 Yuhan Chen. All rights reserved.
//

import UIKit
import Photos

class AlbumViewController: UITableViewController, ViewModelObserving {

    // MARK: - ViewModel

    private let viewModel = AlbumViewModel()

    // MARK: - Properties

    let sectionLocalizedTitles = [
        "",
        NSLocalizedString(R.string.localizable.viewSmartAlbums(), comment: ""),
        NSLocalizedString(R.string.localizable.viewMyAlbums(), comment: "")
    ]

    // MARK: - Initialization
    
    init() {
        super.init(style: .insetGrouped)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
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
        title = NSLocalizedString("Albums", comment: "")
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.largeTitleDisplayMode = .always
        
        tableView.register(AlbumTableViewCell.self, forCellReuseIdentifier: String(describing: AlbumTableViewCell.self))
        tableView.rowHeight = 88 // Taller cells for better touch targets
    }

    // MARK: - Bindings

    private func setupBindings() {
        observe(viewModel: viewModel, property: { $0.isAuthorized }) { [weak self] isAuthorized in
            if !isAuthorized {
                self?.showLockView()
            }
        }

        observe(viewModel: viewModel, property: { $0.needsReload }) { [weak self] needsReload in
            if needsReload {
                self?.tableView.reloadData()
            }
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
            lockView.title = R.string.localizable.alertPhotoAccess()
            lockView.detail = R.string.localizable.alertPhotoAccessDesc()
            lockView.buttonTitle = R.string.localizable.alertPhotoAuth()
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
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: String(describing: AlbumTableViewCell.self),
            for: indexPath
        ) as? AlbumTableViewCell else {
            return UITableViewCell()
        }

        cell.thumnail = nil

        let (title, count, asset) = viewModel.albumInfo(at: indexPath)
        cell.title = title
        cell.count = count

        if let asset = asset {
            viewModel.getThumbnail(for: asset) { [weak cell] image in
                Task { @MainActor in
                    cell?.thumnail = image
                }
            }
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sectionLocalizedTitles[section]
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        // Retrieve data
        let (fetchResult, collection, title) = viewModel.fetchResult(for: indexPath)

        // Create destination (Pure programmatic)
        let destination = PhotoGridViewController()

        // Configure destination
        destination.configureWithViewModel(fetchResult: fetchResult, collection: collection)
        destination.title = title

        // Navigate - Use showDetailViewController for iPad split view support
        // This replaces the detail pane on iPad, or pushes on iPhone
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
