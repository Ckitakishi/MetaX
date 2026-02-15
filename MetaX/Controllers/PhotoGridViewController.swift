//
//  PhotoGridViewController.swift
//  MetaX
//
//  Created by Ckitakishi on 2018/3/17.
//  Copyright © 2018 Yuhan Chen. All rights reserved.
//

import Photos
import PhotosUI
import UIKit

class PhotoGridViewController: UIViewController, ViewModelObserving {

    // MARK: - Dependencies

    private let container: DependencyContainer
    var router: AppRouter?

    // MARK: - UI Components

    private var collectionView: UICollectionView!

    // MARK: - ViewModel

    private let viewModel: PhotoGridViewModel

    // MARK: - Properties

    private var thumbnailSize: CGSize = .zero

    // MARK: - Initialization

    init(container: DependencyContainer) {
        self.container = container
        viewModel = PhotoGridViewModel(photoLibraryService: container.photoLibraryService)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Configuration (called from AlbumViewController)

    func configureWithViewModel(fetchResult: PHFetchResult<PHAsset>?, collection: PHAssetCollection?) {
        viewModel.configure(with: fetchResult, collection: collection)
    }

    // MARK: - Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
        setupBindings()

        viewModel.loadDefaultPhotosIfNeeded()
        viewModel.registerPhotoLibraryObserver()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateThumbnailSize()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        updateCachedAssets()
    }

    deinit {
        let vm = viewModel
        Task { @MainActor in
            vm.unregisterPhotoLibraryObserver()
        }
    }

    // MARK: - UI Setup

    private func setupUI() {
        view.backgroundColor = Theme.Colors.mainBackground

        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1 / 3),
            heightDimension: .fractionalWidth(1 / 3)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let half: CGFloat = 8
        item.contentInsets = NSDirectionalEdgeInsets(top: half, leading: half, bottom: half, trailing: half)

        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .fractionalWidth(1 / 3)
        )
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: half, leading: half, bottom: half, trailing: half)
        let layout = UICollectionViewCompositionalLayout(section: section)

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.translatesAutoresizingMaskIntoConstraints = false

        collectionView.register(
            PhotoCollectionViewCell.self,
            forCellWithReuseIdentifier: String(describing: PhotoCollectionViewCell.self)
        )

        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func updateThumbnailSize() {
        let width = view.bounds.width / 3
        let scale = traitCollection.displayScale
        thumbnailSize = CGSize(width: ceil(width * scale), height: ceil(width * scale))
        viewModel.setThumbnailSize(thumbnailSize)
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
        viewModel.commitFetchResult(changes.fetchResultAfterChanges)
        collectionView.reloadData()
        viewModel.finishChange()
        viewModel.resetCachedAssets()
    }

    // MARK: - Asset Caching

    private func updateCachedAssets() {
        guard isViewLoaded, view.window != nil else { return }

        let visibleRect = CGRect(origin: collectionView.contentOffset, size: collectionView.bounds.size)

        viewModel.updateCachedAssets(
            visibleRect: visibleRect,
            viewBoundsHeight: view.bounds.height
        ) { [weak self] rect in
            self?.collectionView.indexPathsForElements(in: rect) ?? []
        }
    }
}

// MARK: - UICollectionViewDataSource & Delegate

extension PhotoGridViewController: UICollectionViewDataSource, UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return viewModel.numberOfItems
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        guard let asset = viewModel.asset(at: indexPath.item),
              let cell = collectionView.dequeueReusableCell(
                  withReuseIdentifier: String(describing: PhotoCollectionViewCell.self),
                  for: indexPath
              ) as? PhotoCollectionViewCell
        else {
            return UICollectionViewCell()
        }

        if asset.mediaSubtypes.contains(.photoLive) {
            cell.livePhotoBadgeImage = PHLivePhotoView.livePhotoBadgeImage(options: .overContent)
        } else {
            cell.livePhotoBadgeImage = nil
        }

        cell.representedAssetIdentifier = asset.localIdentifier
        viewModel.requestImage(for: asset, targetSize: thumbnailSize) { [weak cell] image, _ in
            guard cell?.representedAssetIdentifier == asset.localIdentifier else { return }
            Task { @MainActor in
                cell?.thumbnailImage = image
            }
        }

        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let asset = viewModel.asset(at: indexPath.item) else { return }
        router?.viewAssetDetail(for: asset, in: viewModel.assetCollection, from: navigationController)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateCachedAssets()
    }
}

// MARK: - Helper Extension

extension UICollectionView {
    fileprivate func indexPathsForElements(in rect: CGRect) -> [IndexPath] {
        guard let allLayoutAttributes = collectionViewLayout.layoutAttributesForElements(in: rect) else {
            return []
        }
        return allLayoutAttributes.map { $0.indexPath }
    }
}
