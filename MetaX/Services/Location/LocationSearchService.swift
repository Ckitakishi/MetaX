//
//  LocationSearchService.swift
//  MetaX
//
//  Created by Yuhan Chen on 2026/02/09.
//

@preconcurrency import MapKit

final class LocationSearchService: NSObject, LocationSearchServiceProtocol {

    weak var delegate: LocationSearchServiceDelegate?
    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
    }

    func search(query: String) {
        if query.isEmpty {
            delegate?.didUpdate(results: [])
        } else {
            completer.queryFragment = query
        }
    }

    func resolve(completion: MKLocalSearchCompletion) async throws -> LocationModel {
        let searchRequest = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: searchRequest)

        return try await withCheckedThrowingContinuation { continuation in
            search.start { response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                if let mapItem = response?.mapItems.first {
                    let locationModel = LocationModel(with: mapItem)
                    continuation.resume(returning: locationModel)
                } else {
                    // Fallback to basic model if no map item found
                    continuation.resume(returning: LocationModel(with: completion))
                }
            }
        }
    }
}

// MARK: - MKLocalSearchCompleterDelegate

extension LocationSearchService: MKLocalSearchCompleterDelegate {

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        delegate?.didUpdate(results: completer.results)
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        delegate?.didFail(with: error)
    }
}
