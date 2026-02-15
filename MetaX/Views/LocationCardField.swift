//
//  LocationCardField.swift
//  MetaX
//
//  Created by Yuhan Chen on 2026/02/09.
//  Copyright © 2026 Yuhan Chen. All rights reserved.
//

import UIKit
import MapKit

final class LocationCardField: UIView {
    let label: UILabel = {
        let l = UILabel()
        l.font = Theme.Typography.footnote
        l.textColor = .secondaryLabel
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    let button: UIButton = {
        let btn = UIButton(type: .custom)
        btn.backgroundColor = Theme.Colors.tagBackground
        btn.layer.borderWidth = 1.0
        btn.layer.borderColor = Theme.Colors.border.cgColor
        btn.layer.cornerRadius = 0
        btn.clipsToBounds = true
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()
    
    private let mapView: MKMapView = {
        let map = MKMapView()
        map.isUserInteractionEnabled = false
        map.translatesAutoresizingMaskIntoConstraints = false
        map.isHidden = true
        return map
    }()

    private let contentLabel: UILabel = {
        let l = UILabel()
        l.text = String(localized: .viewLocationSearchPlaceholder)
        l.font = Theme.Typography.bodyMedium
        l.textColor = Theme.Colors.text.withAlphaComponent(0.4)
        l.numberOfLines = 1
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    
    private let midDivider: UIView = {
        let v = UIView()
        v.backgroundColor = Theme.Colors.border.withAlphaComponent(0.3)
        v.translatesAutoresizingMaskIntoConstraints = false
        v.isHidden = true
        return v
    }()

    private var buttonHeightConstraint: NSLayoutConstraint?

    init(label: String) {
        super.init(frame: .zero)
        self.label.text = label

        addSubview(self.label)
        addSubview(button)
        
        button.addSubview(contentLabel)
        button.addSubview(midDivider)
        button.addSubview(mapView)

        buttonHeightConstraint = button.heightAnchor.constraint(equalToConstant: 50)
        buttonHeightConstraint?.isActive = true

        NSLayoutConstraint.activate([
            self.label.topAnchor.constraint(equalTo: topAnchor),
            self.label.leadingAnchor.constraint(equalTo: leadingAnchor),
            self.label.trailingAnchor.constraint(equalTo: trailingAnchor),

            button.topAnchor.constraint(equalTo: self.label.bottomAnchor, constant: 6),
            button.leadingAnchor.constraint(equalTo: leadingAnchor),
            button.trailingAnchor.constraint(equalTo: trailingAnchor),
            button.bottomAnchor.constraint(equalTo: bottomAnchor),

            contentLabel.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 12),
            contentLabel.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -12),
            contentLabel.centerYAnchor.constraint(equalTo: button.topAnchor, constant: 25),
            
            midDivider.topAnchor.constraint(equalTo: button.topAnchor, constant: 50),
            midDivider.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            midDivider.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            midDivider.heightAnchor.constraint(equalToConstant: 1.0),

            mapView.topAnchor.constraint(equalTo: midDivider.bottomAnchor),
            mapView.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            mapView.bottomAnchor.constraint(equalTo: button.bottomAnchor),
            mapView.heightAnchor.constraint(equalToConstant: 120)
        ])

        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: LocationCardField, _: UITraitCollection) in
            self.button.layer.borderColor = Theme.Colors.border.cgColor
            self.midDivider.backgroundColor = Theme.Colors.border.withAlphaComponent(0.3)
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    func setLocation(_ location: CLLocation?, title: String?) {
        if let loc = location {
            let region = MKCoordinateRegion(center: loc.coordinate, latitudinalMeters: 1000, longitudinalMeters: 1000)
            mapView.setRegion(region, animated: false)
            mapView.isHidden = false
            midDivider.isHidden = false
            
            contentLabel.numberOfLines = 0
            buttonHeightConstraint?.isActive = false
            
            mapView.removeAnnotations(mapView.annotations)
            let annotation = MKPointAnnotation()
            annotation.coordinate = loc.coordinate
            mapView.addAnnotation(annotation)
            
            if let title = title, !title.isEmpty {
                contentLabel.text = title
                contentLabel.textColor = Theme.Colors.text
            } else {
                contentLabel.text = String(format: "%.4f, %.4f", loc.coordinate.latitude, loc.coordinate.longitude)
                contentLabel.textColor = Theme.Colors.text
            }
        } else {
            mapView.isHidden = true
            midDivider.isHidden = true
            contentLabel.numberOfLines = 1
            contentLabel.text = String(localized: .viewLocationSearchPlaceholder)
            contentLabel.textColor = Theme.Colors.text.withAlphaComponent(0.4)
            buttonHeightConstraint?.isActive = true
        }
    }
}
