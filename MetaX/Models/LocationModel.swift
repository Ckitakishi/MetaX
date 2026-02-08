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

struct LocationModel: LocationModelRepresentable {

    var name: String
    var shortPlacemark: String
    var coordinate: CLLocationCoordinate2D?
    
    init(with mapItem: MKMapItem) {
        
        self.name = mapItem.name ?? ""
        
        let placemark = mapItem.placemark
        let infos = [placemark.thoroughfare, placemark.locality, placemark.administrativeArea, placemark.country]
        
        self.shortPlacemark = infos.reduce("") { (locaitonText: String, info) in
            let infoText = info ?? ""
            return "\(locaitonText)" + (locaitonText != "" ? "," : "") + "\(infoText)"
        }
        
        // Struct
        self.coordinate = placemark.coordinate
    }
    
    init(with completion: MKLocalSearchCompletion) {
        self.name = completion.title
        self.shortPlacemark = completion.subtitle
        // ...
        self.coordinate = nil
    }
}
