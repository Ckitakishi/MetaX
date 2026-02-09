//
//  AlbumHeroTableViewCell.swift
//  MetaX
//
//  Created by Yuhan Chen on 2026/02/08.
//  Copyright © 2026 Yuhan Chen. All rights reserved.
//

import UIKit

class AlbumHeroTableViewCell: UITableViewCell {

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
        Theme.Shadows.applyCardBorder(to: imageView.layer)
        imageView.backgroundColor = .secondarySystemFill
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 20, weight: .bold)
        label.textColor = Theme.Colors.text
        label.textAlignment = .left
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let countTagView: UIView = {
        let view = UIView()
        view.backgroundColor = Theme.Colors.tagBackground
        view.layer.borderWidth = 1.0
        view.layer.borderColor = Theme.Colors.border.cgColor
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

    var title: String? {
        didSet {
            guard let title = title else { return }
            let text = title.uppercased()
            let attributedString = NSMutableAttributedString(string: text)
            attributedString.addAttribute(.kern, value: 2.0, range: NSRange(location: 0, length: text.count))
            titleLabel.attributedText = attributedString
        }
    }

    var count: Int = 0 {
        didSet { countLabel.text = "\(count)" }
    }

    var thumnail: UIImage? {
        didSet { thumbnailImageView.image = thumnail }
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

        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (cell: AlbumHeroTableViewCell, _: UITraitCollection) in
            Theme.Shadows.updateLayerColors(for: cell.cardView.layer)
            Theme.Shadows.updateLayerColors(for: cell.thumbnailImageView.layer)
            Theme.Shadows.updateLayerColors(for: cell.countTagView.layer)
            if let layer = cell.stackedLayer {
                Theme.Shadows.updateLayerColors(for: layer.layer)
            }
        }

        contentView.addSubview(cardView)
        stackedLayer = Theme.Shadows.applyStackedLayer(to: cardView, in: contentView)
        cardView.addSubview(thumbnailImageView)
        cardView.addSubview(countTagView)
        countTagView.addSubview(countIconView)
        countTagView.addSubview(countLabel)
        cardView.addSubview(titleLabel)

        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Theme.Layout.cellSpacing),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Theme.Layout.cardPadding),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Theme.Layout.cardPadding),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -Theme.Layout.cellSpacing),
            
            thumbnailImageView.topAnchor.constraint(equalTo: cardView.topAnchor),
            thumbnailImageView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor),
            thumbnailImageView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor),
            thumbnailImageView.heightAnchor.constraint(equalTo: thumbnailImageView.widthAnchor, multiplier: 0.5625),
            
            titleLabel.topAnchor.constraint(equalTo: thumbnailImageView.bottomAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20),
            titleLabel.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -24),
            
            countTagView.topAnchor.constraint(equalTo: thumbnailImageView.topAnchor, constant: 12),
            countTagView.trailingAnchor.constraint(equalTo: thumbnailImageView.trailingAnchor, constant: -12),
            
            countIconView.leadingAnchor.constraint(equalTo: countTagView.leadingAnchor, constant: 10),
            countIconView.centerYAnchor.constraint(equalTo: countTagView.centerYAnchor),
            countIconView.widthAnchor.constraint(equalToConstant: 14),
            countIconView.heightAnchor.constraint(equalToConstant: 14),
            
            countLabel.leadingAnchor.constraint(equalTo: countIconView.trailingAnchor, constant: 6),
            countLabel.trailingAnchor.constraint(equalTo: countTagView.trailingAnchor, constant: -10),
            countLabel.centerYAnchor.constraint(equalTo: countTagView.centerYAnchor),
            countTagView.heightAnchor.constraint(equalToConstant: 26)
        ])
    }
    
    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        UIView.animate(withDuration: 0.1) {
            Theme.Shadows.applyPressEffect(to: self.cardView, isPressed: highlighted)
        }
    }

}
