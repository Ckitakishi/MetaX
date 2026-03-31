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

    private enum NavigationBarState {
        case normal(canSort: Bool)
        case selecting(selectedCount: Int, canSort: Bool)
    }

    // MARK: - Intent Closures

    var onSelectAsset: ((PHAsset, PHAssetCollection?) -> Void)?
    var onBatchEdit: (([PHAsset]) -> Void)?
    var onBatchClear: (([PHAsset]) -> Void)?

    // MARK: - UI Components

    private var collectionView: UICollectionView!

    // MARK: - ViewModel

    private let viewModel: PhotoGridViewModel

    // MARK: - Properties

    private var baseTitle: String?
    private lazy var closeSelectionBarButtonItem = UIBarButtonItem(
        image: UIImage(systemName: "xmark"),
        style: .plain,
        target: self,
        action: #selector(exitSelectionMode)
    )

    private lazy var sortBarButtonItem = UIBarButtonItem(
        image: UIImage(systemName: "arrow.up.arrow.down"),
        menu: createSortMenu()
    )

    private lazy var selectionBarButtonItem = UIBarButtonItem(
        title: String(localized: .batchSelect),
        style: .plain,
        target: self,
        action: #selector(enterSelectionMode)
    )

    private lazy var selectionActionsBarButtonItem = UIBarButtonItem(
        image: UIImage(systemName: "ellipsis"),
        menu: createSelectionActionsMenu()
    )

    private lazy var barButtonSpacerItem: UIBarButtonItem = {
        let item = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
        item.width = 12
        return item
    }()

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
        baseTitle = collection?.localizedTitle ?? baseTitle ?? title
        if isViewLoaded {
            setupNavigationBar()
        }
    }

    // MARK: - Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        baseTitle = baseTitle ?? title
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
        renderNavigationBar(for: currentNavigationBarState())
    }

    private func currentNavigationBarState() -> NavigationBarState {
        let canSort = viewModel.assetCollection == nil
        if viewModel.isSelecting {
            return .selecting(selectedCount: viewModel.selectedCount, canSort: canSort)
        } else {
            return .normal(canSort: canSort)
        }
    }

    private func renderNavigationBar(for state: NavigationBarState) {
        updateMenus(for: state)

        switch state {
        case let .normal(canSort):
            title = defaultTitle
            navigationItem.leftBarButtonItem = nil
            navigationItem.rightBarButtonItems = rightBarButtonItems(canSort: canSort, isSelecting: false)
        case let .selecting(selectedCount, canSort):
            title = selectionTitle(for: selectedCount)
            navigationItem.leftBarButtonItem = closeSelectionBarButtonItem
            navigationItem.rightBarButtonItems = rightBarButtonItems(canSort: canSort, isSelecting: true)
        }
    }

    private func createSortMenu() -> UIMenu {
        let creationDateAction = UIAction(
            title: PhotoSortOrder.creationDate.title,
            state: viewModel.currentSortOrder == .creationDate ? .on : .off
        ) { [weak self] _ in
            self?.viewModel.currentSortOrder = .creationDate
            self?.rebuildMenus()
        }

        let addedDateAction = UIAction(
            title: PhotoSortOrder.addedDate.title,
            state: viewModel.currentSortOrder == .addedDate ? .on : .off
        ) { [weak self] _ in
            self?.viewModel.currentSortOrder = .addedDate
            self?.rebuildMenus()
        }

        return UIMenu(title: String(localized: .sortMenuTitle), children: [creationDateAction, addedDateAction])
    }

    private func createSelectionActionsMenu() -> UIMenu {
        let hasSelection = viewModel.selectedCount > 0

        let editAction = UIAction(
            title: String(localized: .viewEditMetadata),
            image: UIImage(systemName: "pencil.line"),
            attributes: hasSelection ? [] : .disabled
        ) { [weak self] _ in
            self?.batchEditTapped()
        }

        let clearAction = UIAction(
            title: String(localized: .viewClearAllMetadata),
            image: UIImage(systemName: "trash"),
            attributes: hasSelection ? .destructive : [.destructive, .disabled]
        ) { [weak self] _ in
            self?.batchClearTapped()
        }

        return UIMenu(children: [editAction, clearAction])
    }

    private var defaultTitle: String? {
        baseTitle
    }

    private func selectionTitle(for count: Int) -> String {
        count > 0
            ? String(localized: .batchNitemsSelected(count))
            : String(localized: .batchSelectItems)
    }

    private func rightBarButtonItems(canSort: Bool, isSelecting: Bool) -> [UIBarButtonItem] {
        var items: [UIBarButtonItem] = [isSelecting ? selectionActionsBarButtonItem : selectionBarButtonItem]
        if canSort {
            items.append(barButtonSpacerItem)
            items.append(sortBarButtonItem)
        }
        return items
    }

    private func updateMenus(for state: NavigationBarState) {
        sortBarButtonItem.menu = createSortMenu()
        if case .selecting = state {
            selectionActionsBarButtonItem.menu = createSelectionActionsMenu()
        }
    }

    private func rebuildMenus() {
        updateMenus(for: currentNavigationBarState())
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

        collectionView.allowsMultipleSelection = false
        collectionView.allowsMultipleSelectionDuringEditing = true

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

    // MARK: - Selection Mode

    @objc private func enterSelectionMode() {
        viewModel.isSelecting = true
        collectionView.isEditing = true
        collectionView.allowsMultipleSelection = true
        setupNavigationBar()
        updateVisibleCellsSelectionState()
    }

    @objc private func exitSelectionMode() {
        viewModel.clearSelection()
        collectionView.isEditing = false
        collectionView.allowsMultipleSelection = false
        for indexPath in collectionView.indexPathsForSelectedItems ?? [] {
            collectionView.deselectItem(at: indexPath, animated: false)
        }
        setupNavigationBar()
        updateVisibleCellsSelectionState()
    }

    func resetBatchSelectionMode() {
        guard isViewLoaded else {
            viewModel.clearSelection()
            return
        }
        exitSelectionMode()
    }

    private func updateVisibleCellsSelectionState() {
        for cell in collectionView.visibleCells {
            guard let photoCell = cell as? PhotoCollectionViewCell,
                  let indexPath = collectionView.indexPath(for: cell) else { continue }
            photoCell.updateSelectionState(
                isSelecting: viewModel.isSelecting,
                isSelected: viewModel.isSelected(at: indexPath.item)
            )
        }
    }

    private func batchEditTapped() {
        let assets = viewModel.selectedPHAssets()
        guard !assets.isEmpty else { return }
        onBatchEdit?(assets)
    }

    private func batchClearTapped() {
        let assets = viewModel.selectedPHAssets()
        guard !assets.isEmpty else { return }
        onBatchClear?(assets)
    }

    // MARK: - Bindings

    private func setupBindings() {
        observe(viewModel: viewModel, property: { $0.fetchResult }) { [weak self] _ in
            guard let self else { return }
            collectionView.reloadData()
            viewModel.resetCachedAssets()
            updateCachedAssets()
        }

        observe(viewModel: viewModel, property: { $0.selectedIdentifiers }) { [weak self] _ in
            guard let self, viewModel.isSelecting else { return }
            renderNavigationBar(for: currentNavigationBarState())
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

        let isSelected = viewModel.isSelected(at: indexPath.item)
        cell.configure(
            with: cellModel,
            imageStream: viewModel.requestImageStream(for: cellModel.asset, targetSize: thumbnailSize),
            isSelecting: viewModel.isSelecting,
            isSelected: isSelected
        )

        // Keep collection view selection state in sync with viewModel
        if viewModel.isSelecting && isSelected {
            collectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
        }

        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if viewModel.isSelecting {
            let success = viewModel.setSelected(true, at: indexPath.item)
            if !success {
                // At selection limit — revert the collection view's selection
                collectionView.deselectItem(at: indexPath, animated: false)
                let maxCount = PhotoGridViewModel.maxSelectionCount
                let alert = UIAlertController(
                    title: nil,
                    message: String(localized: .batchSelectionLimit(maxCount)),
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: String(localized: .alertConfirm), style: .default))
                present(alert, animated: true)
            }
        } else {
            collectionView.deselectItem(at: indexPath, animated: false)
            guard let asset = viewModel.asset(at: indexPath.item) else { return }
            onSelectAsset?(asset, viewModel.assetCollection)
        }
    }

    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        guard viewModel.isSelecting else { return }
        viewModel.setSelected(false, at: indexPath.item)
    }

    // MARK: - Multi-Select Gesture

    func collectionView(
        _ collectionView: UICollectionView,
        shouldBeginMultipleSelectionInteractionAt indexPath: IndexPath
    ) -> Bool {
        return viewModel.isSelecting
    }

    func collectionView(
        _ collectionView: UICollectionView,
        didBeginMultipleSelectionInteractionAt indexPath: IndexPath
    ) {
        // Already in selection mode
    }

    func collectionViewDidEndMultipleSelectionInteraction(_ collectionView: UICollectionView) {
        // No action needed
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
