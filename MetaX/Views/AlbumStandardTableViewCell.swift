//
//  AlbumStandardTableViewCell.swift
//  MetaX
//
//  Created by Yuhan Chen on 2026/02/08.
//  Copyright © 2026 Yuhan Chen. All rights reserved.
//

import UIKit

class AlbumStandardTableViewCell: UITableViewCell {

    private var stackedLayer: UIView?

    private let cardView: UIView = {
        let view = UIView()
        view.backgroundColor = Theme.Colors.cardBackground
        Theme.Shadows.applyCardBorder(to: view.layer)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let thumbnailImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 0
        imageView.backgroundColor = .secondarySystemFill
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let imageRightBorder: UIView = {
        let view = UIView()
        view.backgroundColor = Theme.Colors.border
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = Theme.Typography.headline
        label.textColor = Theme.Colors.text
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let countTagView: UIView = {
        let view = UIView()
        view.backgroundColor = Theme.Colors.tagBackground
        Theme.Shadows.applyCardBorder(to: view.layer)
        view.layer.cornerRadius = 2
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let countIconView: UIImageView = {
        let imageView = UIImageView(image: UIImage(systemName: "photo.stack"))
        imageView.tintColor = Theme.Colors.text
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let countLabel: UILabel = {
        let label = UILabel()
        label.font = Theme.Typography.captionMono
        label.textColor = Theme.Colors.text
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    var representedIdentifier: String?
    var cancelThumbnailRequest: (() -> Void)?

    var title: String? {
        didSet { titleLabel.text = title }
    }

    var count: Int? {
        didSet { countLabel.text = count.map { "\($0)" } ?? "—" }
    }

    var thumbnail: UIImage? {
        didSet { thumbnailImageView.image = thumbnail }
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        selectionStyle = .none
        backgroundColor = .clear

        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (cell: AlbumStandardTableViewCell, _: UITraitCollection) in
            Theme.Shadows.updateLayerColors(for: cell.cardView.layer)
            Theme.Shadows.updateLayerColors(for: cell.countTagView.layer)
            if let layer = cell.stackedLayer {
                Theme.Shadows.updateLayerColors(for: layer.layer)
            }
        }

        contentView.addSubview(cardView)
        stackedLayer = Theme.Shadows.applyStackedLayer(to: cardView, in: contentView)
        cardView.addSubview(thumbnailImageView)
        cardView.addSubview(imageRightBorder)
        
        let infoStack = UIStackView(arrangedSubviews: [titleLabel, countTagView])
        infoStack.axis = .vertical
        infoStack.spacing = 8
        infoStack.alignment = .leading
        infoStack.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(infoStack)
        
        countTagView.addSubview(countIconView)
        countTagView.addSubview(countLabel)

        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Theme.Layout.cellSpacing),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Theme.Layout.cardPadding),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Theme.Layout.cardPadding),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -Theme.Layout.cellSpacing),
            
            // Image Bleed Layout
            thumbnailImageView.topAnchor.constraint(equalTo: cardView.topAnchor),
            thumbnailImageView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor),
            thumbnailImageView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor),
            thumbnailImageView.widthAnchor.constraint(equalToConstant: Theme.Layout.thumbnailSize),
            thumbnailImageView.heightAnchor.constraint(equalToConstant: Theme.Layout.thumbnailSize),
            
            // Image Right Border
            imageRightBorder.topAnchor.constraint(equalTo: cardView.topAnchor),
            imageRightBorder.bottomAnchor.constraint(equalTo: cardView.bottomAnchor),
            imageRightBorder.leadingAnchor.constraint(equalTo: thumbnailImageView.trailingAnchor),
            imageRightBorder.widthAnchor.constraint(equalToConstant: 1.0), // Reduced to 1.0
            
            // Vertically Centered Info Stack
            infoStack.leadingAnchor.constraint(equalTo: imageRightBorder.trailingAnchor, constant: Theme.Layout.cardPadding),
            infoStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -12),
            infoStack.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            
            countIconView.leadingAnchor.constraint(equalTo: countTagView.leadingAnchor, constant: 8),
            countIconView.centerYAnchor.constraint(equalTo: countTagView.centerYAnchor),
            countIconView.widthAnchor.constraint(equalToConstant: 12),
            countIconView.heightAnchor.constraint(equalToConstant: 12),
            
            countLabel.leadingAnchor.constraint(equalTo: countIconView.trailingAnchor, constant: 4),
            countLabel.trailingAnchor.constraint(equalTo: countTagView.trailingAnchor, constant: -8),
            countLabel.topAnchor.constraint(equalTo: countTagView.topAnchor, constant: 4),
            countLabel.bottomAnchor.constraint(equalTo: countTagView.bottomAnchor, constant: -4)
        ])
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        cancelThumbnailRequest?()
        cancelThumbnailRequest = nil
        representedIdentifier = nil
        thumbnailImageView.image = nil
        countLabel.text = "—"
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        UIView.animate(withDuration: Theme.Animation.pressEffect) {
            Theme.Shadows.applyPressEffect(to: self.cardView, isPressed: highlighted)
        }
    }

}
