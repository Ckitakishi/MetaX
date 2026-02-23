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

    // MARK: - Properties

    private var representedAssetIdentifier: String?
    private var imageLoadTask: Task<Void, Never>?

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
        }

        contentView.addSubview(containerView)
        stackedLayer = Theme.Shadows.applyStackedLayer(to: containerView, in: contentView)
        containerView.addSubview(imageView)
        containerView.addSubview(livePhotoBadgeImageView)

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            imageView.topAnchor.constraint(equalTo: containerView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),

            livePhotoBadgeImageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 6),
            livePhotoBadgeImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 6),
            livePhotoBadgeImageView.widthAnchor.constraint(equalToConstant: 24),
            livePhotoBadgeImageView.heightAnchor.constraint(equalToConstant: 24),
        ])
    }

    /// Configures the cell and starts loading the thumbnail asynchronously.
    func configure(
        with model: PhotoGridViewModel.CellModel,
        imageStream: AsyncStream<(UIImage?, Bool)>
    ) {
        representedAssetIdentifier = model.identifier
        livePhotoBadgeImageView.image = model.isLivePhoto ? PHLivePhotoView
            .livePhotoBadgeImage(options: .overContent) : nil
        livePhotoBadgeImageView.isHidden = !model.isLivePhoto

        imageLoadTask?.cancel()
        imageLoadTask = Task { @MainActor in
            for await (image, _) in imageStream {
                guard !Task.isCancelled, representedAssetIdentifier == model.identifier else { break }
                imageView.image = image
            }
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageLoadTask?.cancel()
        imageLoadTask = nil
        imageView.image = nil
        livePhotoBadgeImageView.image = nil
        representedAssetIdentifier = nil
    }
}
