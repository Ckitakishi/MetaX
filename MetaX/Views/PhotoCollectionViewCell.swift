//
//  PhotoCollectionViewCell.swift
//  MetaX
//
//  Created by Ckitakishi on 2018/3/18.
//  Copyright © 2018年 Yuhan Chen. All rights reserved.
//

import UIKit

class PhotoCollectionViewCell: UICollectionViewCell {
    
    // MARK: - UI Components
    
    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
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
    
    var representedAssetIdentifier: String!
    
    var thumbnailImage: UIImage? {
        didSet {
            imageView.image = thumbnailImage
        }
    }
    
    var livePhotoBadgeImage: UIImage? {
        didSet {
            livePhotoBadgeImageView.image = livePhotoBadgeImage
            livePhotoBadgeImageView.isHidden = (livePhotoBadgeImage == nil)
        }
    }
    
    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.2) {
                self.contentView.alpha = self.isHighlighted ? 0.7 : 1.0
                self.contentView.transform = self.isHighlighted ? CGAConfiguration.shrink : .identity
            }
        }
    }
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        contentView.addSubview(imageView)
        contentView.addSubview(livePhotoBadgeImageView)
        
        NSLayoutConstraint.activate([
            // Image View
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            // Badge View
            livePhotoBadgeImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            livePhotoBadgeImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
            livePhotoBadgeImageView.widthAnchor.constraint(equalToConstant: 24),
            livePhotoBadgeImageView.heightAnchor.constraint(equalToConstant: 24)
        ])
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
        livePhotoBadgeImageView.image = nil
        representedAssetIdentifier = nil
    }
}

// MARK: - Helpers
private enum CGAConfiguration {
    static let shrink = CGAffineTransform(scaleX: 0.95, y: 0.95)
}

