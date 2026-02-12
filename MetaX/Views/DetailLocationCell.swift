//
//  DetailLocationCell.swift
//  MetaX
//
//  Created by Yuhan Chen on 2026/02/12.
//  Copyright © 2026 Yuhan Chen. All rights reserved.
//

import UIKit
import MapKit

final class DetailLocationCell: UITableViewCell {

    private(set) var currentLocation: CLLocation?

    // Card borders
    private let topBorder = UIView()
    private let bottomBorder = UIView()
    private let leftBorder = UIView()
    private let rightBorder = UIView()

    private let container: UIView = {
        let v = UIView()
        v.backgroundColor = Theme.Colors.cardBackground
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let propLabel: UILabel = {
        let label = UILabel()
        label.font = Theme.Typography.footnote
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let valueLabel: UILabel = {
        let label = UILabel()
        label.font = Theme.Typography.bodyMedium
        label.textColor = Theme.Colors.text
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let mapView: MKMapView = {
        let map = MKMapView()
        map.isUserInteractionEnabled = false
        map.layer.cornerRadius = 0
        map.translatesAutoresizingMaskIntoConstraints = false
        return map
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    func configure(model: DetailCellModel, location: CLLocation, isFirst: Bool, isLast: Bool) {
        // Text
        let text = model.prop
        let attributed = NSMutableAttributedString(string: text)
        attributed.addAttribute(.kern, value: 1.0, range: NSRange(location: 0, length: text.count))
        propLabel.attributedText = attributed
        valueLabel.text = model.value
        
        // Map
        self.currentLocation = location
        let region = MKCoordinateRegion(center: location.coordinate, latitudinalMeters: 500, longitudinalMeters: 500)
        mapView.setRegion(region, animated: false)
        mapView.removeAnnotations(mapView.annotations)
        let annotation = MKPointAnnotation()
        annotation.coordinate = location.coordinate
        mapView.addAnnotation(annotation)
        
        // Borders
        topBorder.isHidden = !isFirst
        bottomBorder.isHidden = !isLast
    }

    private func setupUI() {
        selectionStyle = .none
        backgroundColor = .clear

        contentView.addSubview(container)
        [leftBorder, rightBorder, topBorder, bottomBorder].forEach {
            $0.backgroundColor = Theme.Colors.border
            $0.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview($0)
        }
        
        container.addSubview(propLabel)
        container.addSubview(valueLabel)
        container.addSubview(mapView)

        let borderWidth: CGFloat = 1
        let padding: CGFloat = 12
        let contentInset = borderWidth + padding

        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: contentView.topAnchor),
            container.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Theme.Layout.cardPadding),
            container.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Theme.Layout.cardPadding),
            container.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            // Borders
            leftBorder.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            leftBorder.topAnchor.constraint(equalTo: container.topAnchor),
            leftBorder.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            leftBorder.widthAnchor.constraint(equalToConstant: borderWidth),

            rightBorder.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            rightBorder.topAnchor.constraint(equalTo: container.topAnchor),
            rightBorder.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            rightBorder.widthAnchor.constraint(equalToConstant: borderWidth),

            topBorder.topAnchor.constraint(equalTo: container.topAnchor),
            topBorder.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            topBorder.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            topBorder.heightAnchor.constraint(equalToConstant: borderWidth),

            bottomBorder.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            bottomBorder.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            bottomBorder.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            bottomBorder.heightAnchor.constraint(equalToConstant: borderWidth),

            // Text Content
            propLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: padding),
            propLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: contentInset),
            propLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -contentInset),

            valueLabel.topAnchor.constraint(equalTo: propLabel.bottomAnchor, constant: 4),
            valueLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: contentInset),
            valueLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -contentInset),
            
            // Map - Flush with bottom and sides
            mapView.topAnchor.constraint(equalTo: valueLabel.bottomAnchor, constant: 12),
            mapView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 1),
            mapView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -1),
            mapView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -1),
            mapView.heightAnchor.constraint(equalToConstant: 160)
        ])
    }
}
