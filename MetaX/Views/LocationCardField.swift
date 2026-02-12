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
    
    private let stackView: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.spacing = 8
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()
    
    private let mapView: MKMapView = {
        let map = MKMapView()
        map.isUserInteractionEnabled = false
        map.layer.borderWidth = 1.0
        map.layer.borderColor = Theme.Colors.border.cgColor
        map.translatesAutoresizingMaskIntoConstraints = false
        map.isHidden = true // Default hidden
        return map
    }()

    private let contentLabel: UILabel = {
        let l = UILabel()
        l.text = String(localized: .viewLocationSearchPlaceholder)
        l.font = Theme.Typography.bodyMedium
        l.textColor = Theme.Colors.text.withAlphaComponent(0.4)
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    init(label: String) {
        super.init(frame: .zero)
        self.label.text = label

        addSubview(self.label)
        addSubview(stackView)
        
        stackView.addArrangedSubview(button)
        stackView.addArrangedSubview(mapView)
        
        button.addSubview(contentLabel)

        NSLayoutConstraint.activate([
            self.label.topAnchor.constraint(equalTo: topAnchor),
            self.label.leadingAnchor.constraint(equalTo: leadingAnchor),
            self.label.trailingAnchor.constraint(equalTo: trailingAnchor),

            stackView.topAnchor.constraint(equalTo: self.label.bottomAnchor, constant: 6),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),

            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 48),
            mapView.heightAnchor.constraint(equalToConstant: 120),

            contentLabel.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 12),
            contentLabel.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -12),
            contentLabel.topAnchor.constraint(equalTo: button.topAnchor, constant: 12),
            contentLabel.bottomAnchor.constraint(equalTo: button.bottomAnchor, constant: -12)
        ])

        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: LocationCardField, _: UITraitCollection) in
            self.button.layer.borderColor = Theme.Colors.border.cgColor
            self.mapView.layer.borderColor = Theme.Colors.border.cgColor
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    func setLocation(_ location: CLLocation?, title: String?) {
        if let loc = location {
            let region = MKCoordinateRegion(center: loc.coordinate, latitudinalMeters: 1000, longitudinalMeters: 1000)
            mapView.setRegion(region, animated: false)
            mapView.isHidden = false
            
            // Add marker
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
            contentLabel.text = String(localized: .viewLocationSearchPlaceholder)
            contentLabel.textColor = Theme.Colors.text.withAlphaComponent(0.4)
        }
    }
}