//
//  LocationModel.swift
//  MetaX
//
//  Created by Ckitakishi on 2018/04/11.
//  Copyright © 2018 Yuhan Chen. All rights reserved.
//

import UIKit
import MapKit

protocol LocationModelRepresentable {
    var name: String { get }
    var shortPlacemark: String { get }
    var coordinate: CLLocationCoordinate2D? { get }
}

extension MKLocalSearchCompletion: LocationModelRepresentable {
    var name: String { title }
    var shortPlacemark: String { subtitle }
    var coordinate: CLLocationCoordinate2D? { nil }
}

struct LocationModel: LocationModelRepresentable {

    var name: String
    var shortPlacemark: String
    var coordinate: CLLocationCoordinate2D?
    
    // Rich Data
    var country: String?
    var countryCode: String?
    var state: String? // administrativeArea
    var city: String? // locality
    var street: String? // thoroughfare
    var houseNumber: String? // subThoroughfare
    
    init(title: String, subtitle: String) {
        self.name = title
        self.shortPlacemark = subtitle
        self.coordinate = nil
    }
    
    init(with mapItem: MKMapItem) {
        let placemark = mapItem.placemark
        self.name = mapItem.name ?? placemark.name ?? ""
        
        self.country = placemark.country
        self.countryCode = placemark.isoCountryCode
        self.state = placemark.administrativeArea
        self.city = placemark.locality
        self.street = placemark.thoroughfare
        self.houseNumber = placemark.subThoroughfare
        
        let infos = [placemark.administrativeArea, placemark.locality, placemark.thoroughfare, placemark.subThoroughfare]
        self.shortPlacemark = infos.compactMap { $0 }.joined(separator: ", ")
        
        self.coordinate = placemark.coordinate
    }
    
    init(with completion: MKLocalSearchCompletion) {
        self.name = completion.title
        self.shortPlacemark = completion.subtitle
        self.coordinate = nil
    }
}
