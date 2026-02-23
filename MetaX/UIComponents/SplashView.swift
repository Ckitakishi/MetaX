//
//  SplashView.swift
//  MetaX
//
//  Created by Chen Yuhan on 2026/02/10.
//  Copyright © 2026 Chen Yuhan. All rights reserved.
//

import UIKit

/// A view shown during app launch while initial data is being loaded.
final class SplashView: UIView {

    // MARK: - UI Components

    private let iconImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.layer.cornerRadius = 33
        iv.layer.cornerCurve = .continuous
        iv.clipsToBounds = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    // MARK: - Initialization

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = Theme.Colors.launchBackground
        iconImageView.image = UIImage(named: "LaunchLogo")

        addSubview(iconImageView)

        NSLayoutConstraint.activate([
            iconImageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 150),
            iconImageView.heightAnchor.constraint(equalToConstant: 150),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
