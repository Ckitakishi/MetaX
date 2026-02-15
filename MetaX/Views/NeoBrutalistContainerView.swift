//
//  NeoBrutalistContainerView.swift
//  MetaX
//
//  Created by Yuhan Chen on 2026/02/15.
//

import UIKit

/// A reusable container that implements MetaX's Neo-Brutalist section-based border logic.
final class NeoBrutalistContainerView: UIView {

    private let topBorder = makeBorderView()
    private let bottomBorder = makeBorderView()
    private let leftBorder = makeBorderView()
    private let rightBorder = makeBorderView()

    private let rowSeparator: UIView = {
        let v = UIView()
        v.backgroundColor = Theme.Colors.border.withAlphaComponent(0.4)
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    let contentView: UIView = {
        let v = UIView()
        v.backgroundColor = Theme.Colors.cardBackground
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let contentPadding: CGFloat

    init(contentPadding: CGFloat = 16) {
        self.contentPadding = contentPadding
        super.init(frame: .zero)
        setupUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private static func makeBorderView() -> UIView {
        let v = UIView()
        v.backgroundColor = Theme.Colors.border
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }

    private func setupUI() {
        addSubview(contentView)
        for item in [leftBorder, rightBorder, topBorder, bottomBorder, rowSeparator] {
            contentView.addSubview(item)
        }

        let borderWidth: CGFloat = 1
        let separatorInset = borderWidth + contentPadding

        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: topAnchor),
            contentView.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: bottomAnchor),

            leftBorder.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            leftBorder.topAnchor.constraint(equalTo: contentView.topAnchor),
            leftBorder.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            leftBorder.widthAnchor.constraint(equalToConstant: borderWidth),

            rightBorder.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            rightBorder.topAnchor.constraint(equalTo: contentView.topAnchor),
            rightBorder.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            rightBorder.widthAnchor.constraint(equalToConstant: borderWidth),

            topBorder.topAnchor.constraint(equalTo: contentView.topAnchor),
            topBorder.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            topBorder.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            topBorder.heightAnchor.constraint(equalToConstant: borderWidth),

            bottomBorder.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            bottomBorder.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            bottomBorder.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            bottomBorder.heightAnchor.constraint(equalToConstant: borderWidth),

            rowSeparator.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            rowSeparator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: separatorInset),
            rowSeparator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -separatorInset),
            rowSeparator.heightAnchor.constraint(equalToConstant: 0.5),
        ])
    }

    /// Updates the visibility of borders and separators based on the row position.
    func updateBorders(isFirst: Bool, isLast: Bool) {
        topBorder.isHidden = !isFirst
        bottomBorder.isHidden = !isLast
        rowSeparator.isHidden = isLast
    }
}
