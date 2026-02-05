//
//  PhotoGridViewController.swift
//  MetaX
//
//  Created by Ckitakishi on 2018/3/17.
//  Copyright © 2018年 Yuhan Chen. All rights reserved.
//

import UIKit
import Photos
import PhotosUI

private extension UICollectionView {
    func indexPathsForElements(in rect: CGRect) -> [IndexPath] {
        guard let allLayoutAttributes = collectionViewLayout.layoutAttributesForElements(in: rect) else {
            return []
        }
        return allLayoutAttributes.map { $0.indexPath }
    }
}

class PhotoGridViewController: UICollectionViewController, ViewModelObserving {

    // MARK: - ViewModel

    private let viewModel = PhotoGridViewModel()

    // MARK: - Properties

    private var thumbnailSize: CGSize = .zero

    // MARK: - Configuration (called from AlbumViewController)

    func configureWithViewModel(fetchResult: PHFetchResult<PHAsset>?, collection: PHAssetCollection?) {
        viewModel.configure(with: fetchResult, collection: collection)
    }

    // MARK: - Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        viewModel.loadDefaultPhotosIfNeeded()
        viewModel.registerPhotoLibraryObserver()
        setupBindings()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        let scale = UIScreen.main.scale
        if let flowLayout = collectionViewLayout as? UICollectionViewFlowLayout {
            let cellSize = flowLayout.itemSize
            thumbnailSize = CGSize(width: cellSize.width * scale, height: cellSize.height * scale)
            viewModel.setThumbnailSize(thumbnailSize)

            let layout = UICollectionViewFlowLayout()
            layout.itemSize = cellSize
            layout.minimumInteritemSpacing = 2
            layout.minimumLineSpacing = 2
            collectionView?.collectionViewLayout = layout
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        updateCachedAssets()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        collectionView?.frame.size = size
    }

    override func viewDidLayoutSubviews() {
        guard let wrapperView = collectionView?.superview else { return }
        collectionView?.frame = wrapperView.frame
    }

    deinit {
        let vm = viewModel
        Task { @MainActor in
            vm.unregisterPhotoLibraryObserver()
        }
    }

    // MARK: - Bindings

    private func setupBindings() {
        observe(viewModel: viewModel, property: { $0.changeDetails }) { [weak self] changes in
            if let changes = changes {
                self?.handlePhotoLibraryChanges(changes)
            }
        }
    }

    private func handlePhotoLibraryChanges(_ changes: PHFetchResultChangeDetails<PHAsset>) {
        if changes.hasIncrementalChanges {
            guard let collectionView = collectionView else { return }

            collectionView.performBatchUpdates({
                if let removed = changes.removedIndexes, !removed.isEmpty {
                    collectionView.deleteItems(at: removed.map { IndexPath(item: $0, section: 0) })
                }
                if let inserted = changes.insertedIndexes, !inserted.isEmpty {
                    collectionView.insertItems(at: inserted.map { IndexPath(item: $0, section: 0) })
                }
                if let changed = changes.changedIndexes, !changed.isEmpty {
                    collectionView.reloadItems(at: changed.map { IndexPath(item: $0, section: 0) })
                }

                changes.enumerateMoves { fromIndex, toIndex in
                    collectionView.moveItem(
                        at: IndexPath(item: fromIndex, section: 0),
                        to: IndexPath(item: toIndex, section: 0)
                    )
                }
            })
        } else {
            collectionView?.reloadData()
        }
        viewModel.resetCachedAssets()
    }

    // MARK: - Segues

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let destination = segue.destination as? DetailInfoViewController,
              let cell = sender as? UICollectionViewCell,
              let indexPath = collectionView?.indexPath(for: cell) else {
            return
        }

        destination.asset = viewModel.asset(at: indexPath.item)
        destination.assetCollection = viewModel.assetCollection
    }

    // MARK: - UICollectionViewDataSource

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return viewModel.numberOfItems
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let asset = viewModel.asset(at: indexPath.item),
              let cell = collectionView.dequeueReusableCell(
                  withReuseIdentifier: String(describing: PhotoCollectionViewCell.self),
                  for: indexPath
              ) as? PhotoCollectionViewCell else {
            return UICollectionViewCell()
        }

        if asset.mediaSubtypes.contains(.photoLive) {
            cell.livePhotoBadgeImage = PHLivePhotoView.livePhotoBadgeImage(options: .overContent)
        }

        cell.representedAssetIdentifier = asset.localIdentifier
        viewModel.requestImage(for: asset, targetSize: thumbnailSize) { [weak cell] image in
            guard cell?.representedAssetIdentifier == asset.localIdentifier else { return }
            Task { @MainActor in
                cell?.thumbnailImage = image
            }
        }

        return cell
    }

    // MARK: - UIScrollViewDelegate

    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateCachedAssets()
    }

    // MARK: - Asset Caching

    private func updateCachedAssets() {
        guard isViewLoaded, view.window != nil, let collectionView = collectionView else { return }

        let visibleRect = CGRect(origin: collectionView.contentOffset, size: collectionView.bounds.size)

        viewModel.updateCachedAssets(
            visibleRect: visibleRect,
            viewBoundsHeight: view.bounds.height
        ) { [weak collectionView] rect in
            collectionView?.indexPathsForElements(in: rect) ?? []
        }
    }
}
