//
//  LocationSearchViewModel.swift
//  MetaX
//
//  Created by Chen Yuhan on 2026/02/03.
//  Copyright © 2026 Chen Yuhan. All rights reserved.
//

import Foundation
import MapKit
import Observation

/// ViewModel for LocationSearchViewController
@Observable @MainActor
final class LocationSearchViewModel: NSObject {

    // MARK: - Properties

    private(set) var searchResults: [MKLocalSearchCompletion] = []
    private(set) var error: Error?
    private(set) var selectedLocation: LocationModel?

    private let completer = MKLocalSearchCompleter()
    private let locationManager = CLLocationManager()

    // MARK: - Initialization

    override init() {
        super.init()
        completer.delegate = self
        locationManager.delegate = self
    }

    // MARK: - Public Methods

    func search(query: String) {
        if query.isEmpty {
            searchResults = []
        } else {
            completer.queryFragment = query
        }
    }

    func clearResults() {
        searchResults = []
    }

    func requestLocationAuthorization() {
        let status = locationManager.authorizationStatus
        if status == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
        locationManager.startUpdatingLocation()
    }

    func selectLocation(at index: Int, completion: @escaping (LocationModel?) -> Void) {
        guard index < searchResults.count else {
            completion(nil)
            return
        }

        let selected = searchResults[index]
        var locationModel = LocationModel(with: selected)

        let searchRequest = MKLocalSearch.Request(completion: selected)
        let search = MKLocalSearch(request: searchRequest)

        search.start { response, error in
            Task { @MainActor in
                if let error = error {
                    self.error = error
                    completion(nil)
                    return
                }

                if let coordinate = response?.mapItems.first?.placemark.coordinate {
                    locationModel.coordinate = coordinate
                }

                self.selectedLocation = locationModel
                completion(locationModel)
            }
        }
    }
}

// MARK: - MKLocalSearchCompleterDelegate

extension LocationSearchViewModel: MKLocalSearchCompleterDelegate {

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        Task { @MainActor in
            self.searchResults = completer.results
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            self.error = error
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationSearchViewModel: CLLocationManagerDelegate {

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Location updates can be handled here if needed
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.error = error
        }
    }
}
