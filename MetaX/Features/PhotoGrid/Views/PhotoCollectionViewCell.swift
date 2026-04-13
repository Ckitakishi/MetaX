//
//  PhotoCollectionViewCell.swift
//  MetaX
//
//  Created by Ckitakishi on 2018/3/18.
//  Copyright © 2018 Yuhan Chen. All rights reserved.
//

import Photos
import PhotosUI
import UIKit

@MainActor
class PhotoCollectionViewCell: UICollectionViewCell {

    // MARK: - UI Components

    private var stackedLayer: UIView?

    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = Theme.Colors.cardBackground
        Theme.Shadows.applyCardBorder(to: view.layer)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = Theme.Layout.imageCornerRadius
        imageView.backgroundColor = .secondarySystemFill
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let livePhotoBadgeImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let selectionOverlay: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let checkmarkCircleView: UIView = {
        let view = UIView()
        view.backgroundColor = Theme.Colors.accent
        view.layer.borderWidth = 2
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var checkmarkView: UIView = {
        let size: CGFloat = 24
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.isHidden = true

        let checkmark = UIImageView(image: UIImage(
            systemName: "checkmark",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .bold)
        ))
        checkmark.tintColor = .white
        checkmark.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(checkmarkCircleView)
        checkmarkCircleView.addSubview(checkmark)

        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(equalToConstant: size),
            container.heightAnchor.constraint(equalToConstant: size),
            checkmarkCircleView.topAnchor.constraint(equalTo: container.topAnchor),
            checkmarkCircleView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            checkmarkCircleView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            checkmarkCircleView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            checkmark.centerXAnchor.constraint(equalTo: checkmarkCircleView.centerXAnchor),
            checkmark.centerYAnchor.constraint(equalTo: checkmarkCircleView.centerYAnchor),
        ])

        return container
    }()

    // MARK: - Properties

    private var representedAssetIdentifier: String?
    private var imageLoadTask: Task<Void, Never>?
    private(set) var isInSelectionMode = false

    override var isSelected: Bool {
        didSet {
            guard isInSelectionMode else { return }
            let show = isSelected
            selectionOverlay.isHidden = !show
            checkmarkView.isHidden = !show
        }
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.1) { [weak self] in
                guard let self else { return }
                Theme.Shadows.applyPressEffect(to: self.containerView, isPressed: self.isHighlighted)
            }
        }
    }

    // MARK: - Initialization

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (
            cell: PhotoCollectionViewCell,
            _: UITraitCollection
        ) in
            Theme.Shadows.updateLayerColors(for: cell.containerView.layer)
            if let layer = cell.stackedLayer {
                Theme.Shadows.updateLayerColors(for: layer.layer)
            }
            cell.updateCheckmarkAppearance()
        }

        updateCheckmarkAppearance()

        contentView.addSubview(containerView)
        stackedLayer = Theme.Shadows.applyStackedLayer(to: containerView, in: contentView)
        containerView.addSubview(imageView)
        containerView.addSubview(selectionOverlay)
        containerView.addSubview(livePhotoBadgeImageView)
        containerView.addSubview(checkmarkView)

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            imageView.topAnchor.constraint(equalTo: containerView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),

            selectionOverlay.topAnchor.constraint(equalTo: containerView.topAnchor),
            selectionOverlay.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            selectionOverlay.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            selectionOverlay.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),

            livePhotoBadgeImageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 6),
            livePhotoBadgeImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 6),
            livePhotoBadgeImageView.widthAnchor.constraint(equalToConstant: 24),
            livePhotoBadgeImageView.heightAnchor.constraint(equalToConstant: 24),

            checkmarkView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -6),
            checkmarkView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -6),
        ])
    }

    /// Configures the cell and starts loading the thumbnail asynchronously.
    func configure(
        with model: PhotoGridViewModel.CellModel,
        imageStream: AsyncStream<(UIImage?, Bool)>,
        isSelecting: Bool = false,
        isSelected: Bool = false
    ) {
        representedAssetIdentifier = model.identifier
        livePhotoBadgeImageView.image = model.isLivePhoto ? PHLivePhotoView
            .livePhotoBadgeImage(options: .overContent) : nil
        livePhotoBadgeImageView.isHidden = !model.isLivePhoto

        updateSelectionState(isSelecting: isSelecting, isSelected: isSelected)

        imageLoadTask?.cancel()
        imageLoadTask = Task { @MainActor in
            for await (image, _) in imageStream {
                guard !Task.isCancelled, representedAssetIdentifier == model.identifier else { break }
                imageView.image = image
            }
        }
    }

    func updateSelectionState(isSelecting: Bool, isSelected: Bool) {
        isInSelectionMode = isSelecting
        selectionOverlay.isHidden = !(isSelecting && isSelected)
        checkmarkView.isHidden = !(isSelecting && isSelected)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageLoadTask?.cancel()
        imageLoadTask = nil
        imageView.image = nil
        livePhotoBadgeImageView.image = nil
        representedAssetIdentifier = nil
        isInSelectionMode = false
        selectionOverlay.isHidden = true
        checkmarkView.isHidden = true
    }

    private func updateCheckmarkAppearance() {
        checkmarkCircleView.layer.borderColor = UIColor.label.cgColor
    }
}
