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

    // MARK: - Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        checkAuthorizationAndLoad()
        setupBindings()
    }

    deinit {
        let vm = viewModel
        Task { @MainActor in
            vm.unregisterPhotoLibraryObserver()
        }
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
        let lockView: AuthLockView = UIView().instantiateFromNib(AuthLockView.self)
        if let topView = navigationController?.view {
            lockView.frame = topView.frame
            lockView.delegate = self
            lockView.title = R.string.localizable.alertPhotoAccess()
            lockView.detail = R.string.localizable.alertPhotoAccessDesc()
            lockView.buttonTitle = R.string.localizable.alertPhotoAuth()
            topView.addSubview(lockView)
        }
    }

    // MARK: - Segues

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let navigationController = segue.destination as? UINavigationController,
              let destination = navigationController.topViewController as? PhotoGridViewController else {
            return
        }

        guard let cell = sender as? UITableViewCell,
              let indexPath = tableView.indexPath(for: cell) else {
            return
        }

        let (fetchResult, collection, title) = viewModel.fetchResult(for: indexPath)
        destination.configureWithViewModel(fetchResult: fetchResult, collection: collection)
        destination.title = title
    }
}

// MARK: - UITableViewDataSource

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
}

// MARK: - AuthLockViewDelegate

extension AlbumViewController: AuthLockViewDelegate {

    func toSetting() {
        PHPhotoLibrary.guideToSetting()
    }
}
