//
//  LocationModel.swift
//  MetaX
//
//  Created by Ckitakishi on 2018/04/11.
//  Copyright © 2018 Yuhan Chen. All rights reserved.
//

import MapKit
import UIKit

protocol LocationModelRepresentable {
    var name: String { get }
    var shortPlacemark: String { get }
    var coordinate: CLLocationCoordinate2D? { get }
}

extension MKLocalSearchCompletion: LocationModelRepresentable {
    var name: String {
        title
    }

    var shortPlacemark: String {
        subtitle
    }

    var coordinate: CLLocationCoordinate2D? {
        nil
    }
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
        name = title
        shortPlacemark = subtitle
        coordinate = nil
    }

    init(with mapItem: MKMapItem) {
        let placemark = mapItem.placemark
        name = mapItem.name ?? placemark.name ?? ""

        country = placemark.country
        countryCode = placemark.isoCountryCode
        state = placemark.administrativeArea
        city = placemark.locality
        street = placemark.thoroughfare
        houseNumber = placemark.subThoroughfare

        let infos = [
            placemark.administrativeArea,
            placemark.locality,
            placemark.thoroughfare,
            placemark.subThoroughfare,
        ]
        shortPlacemark = infos.compactMap { $0 }.joined(separator: ", ")

        coordinate = placemark.coordinate
    }

    init(with completion: MKLocalSearchCompletion) {
        name = completion.title
        shortPlacemark = completion.subtitle
        coordinate = nil
    }
}
