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

@MainActor
class PhotoGridViewController: UIViewController, ViewModelObserving {

    // MARK: - Intent Closures

    var onSelectAsset: ((PHAsset, PHAssetCollection?) -> Void)?

    // MARK: - UI Components

    private var collectionView: UICollectionView!

    // MARK: - ViewModel

    private let viewModel: PhotoGridViewModel

    // MARK: - Properties

    private var thumbnailSize: CGSize = .zero
    private var columns: Int {
        calculateColumns(for: view.safeAreaLayoutGuide.layoutFrame.width)
    }

    private func calculateColumns(for width: CGFloat) -> Int {
        let actualWidth = width > 0 ? width : view.bounds.width
        guard traitCollection.horizontalSizeClass == .regular else { return 3 }
        let minColumnWidth: CGFloat = 200
        return max(3, Int(actualWidth / minColumnWidth))
    }

    // MARK: - Initialization

    init(viewModel: PhotoGridViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Configuration

    func configureWithViewModel(fetchResult: PHFetchResult<PHAsset>?, collection: PHAssetCollection?) {
        viewModel.configure(with: fetchResult, collection: collection)
        if isViewLoaded {
            setupNavigationBar()
        }
    }

    // MARK: - Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
        setupBindings()

        viewModel.loadDefaultPhotosIfNeeded()
        viewModel.registerPhotoLibraryObserver()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        let currentWidth = view.safeAreaLayoutGuide.layoutFrame.width
        if currentWidth > 0, abs(lastLayoutWidth - currentWidth) > 1.0 {
            lastLayoutWidth = currentWidth
            collectionView.setCollectionViewLayout(createLayout(for: currentWidth), animated: false)
            updateThumbnailSize()
        }
    }

    private var lastLayoutWidth: CGFloat = 0

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

    private func setupNavigationBar() {
        if viewModel.assetCollection != nil {
            navigationItem.rightBarButtonItem = nil
            return
        }

        let sortButton = UIBarButtonItem(
            image: UIImage(systemName: "arrow.up.arrow.down"),
            menu: createSortMenu()
        )
        navigationItem.rightBarButtonItem = sortButton
    }

    private func createSortMenu() -> UIMenu {
        let creationDateAction = UIAction(
            title: PhotoSortOrder.creationDate.title,
            state: viewModel.currentSortOrder == .creationDate ? .on : .off
        ) { [weak self] _ in
            self?.viewModel.currentSortOrder = .creationDate
            self?.updateNavigationBar()
        }

        let addedDateAction = UIAction(
            title: PhotoSortOrder.addedDate.title,
            state: viewModel.currentSortOrder == .addedDate ? .on : .off
        ) { [weak self] _ in
            self?.viewModel.currentSortOrder = .addedDate
            self?.updateNavigationBar()
        }

        return UIMenu(title: String(localized: .sortMenuTitle), children: [creationDateAction, addedDateAction])
    }

    private func updateNavigationBar() {
        navigationItem.rightBarButtonItem?.menu = createSortMenu()
    }

    private func setupUI() {
        view.backgroundColor = Theme.Colors.mainBackground

        setupNavigationBar()
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: createLayout())
        collectionView.backgroundColor = .clear
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.showsVerticalScrollIndicator = false
        collectionView.translatesAutoresizingMaskIntoConstraints = false

        collectionView.register(
            PhotoCollectionViewCell.self,
            forCellWithReuseIdentifier: String(describing: PhotoCollectionViewCell.self)
        )

        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func createLayout(for width: CGFloat? = nil) -> UICollectionViewLayout {
        let targetWidth = width ?? view.safeAreaLayoutGuide.layoutFrame.width
        let currentColumns = CGFloat(calculateColumns(for: targetWidth))
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1 / currentColumns),
            heightDimension: .fractionalWidth(1 / currentColumns)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let half: CGFloat = 8
        item.contentInsets = NSDirectionalEdgeInsets(top: half, leading: half, bottom: half, trailing: half)

        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .fractionalWidth(1 / currentColumns)
        )
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: half, leading: half, bottom: half, trailing: half)
        return UICollectionViewCompositionalLayout(section: section)
    }

    private func updateThumbnailSize() {
        let currentWidth = view.safeAreaLayoutGuide.layoutFrame.width
        let width = (currentWidth > 0 ? currentWidth : view.bounds.width) / CGFloat(columns)
        let scale = traitCollection.displayScale
        thumbnailSize = CGSize(width: ceil(width * scale), height: ceil(width * scale))
        viewModel.setThumbnailSize(thumbnailSize)
    }

    // MARK: - Bindings

    private func setupBindings() {
        // Observe fetchResult changes and reload immediately (synchronously)
        // to take advantage of PHFetchResult's lazy loading.
        observe(viewModel: viewModel, property: { $0.fetchResult }) { [weak self] _ in
            guard let self else { return }
            collectionView.reloadData()
            viewModel.resetCachedAssets()
            updateCachedAssets()
        }
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
        guard let cellModel = viewModel.cellModel(at: indexPath.item),
              let cell = collectionView.dequeueReusableCell(
                  withReuseIdentifier: String(describing: PhotoCollectionViewCell.self),
                  for: indexPath
              ) as? PhotoCollectionViewCell
        else {
            return UICollectionViewCell()
        }

        cell.configure(
            with: cellModel,
            imageStream: viewModel.requestImageStream(for: cellModel.asset, targetSize: thumbnailSize)
        )

        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let asset = viewModel.asset(at: indexPath.item) else { return }
        onSelectAsset?(asset, viewModel.assetCollection)
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
