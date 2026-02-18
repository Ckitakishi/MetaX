//
//  LocationSearchService.swift
//  MetaX
//
//  Created by Yuhan Chen on 2026/02/09.
//

import MapKit

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

    @MainActor func resolve(at index: Int) async throws -> LocationModel {
        guard index < completer.results.count else {
            throw MetaXError.unknown(underlying: nil)
        }
        let completion = completer.results[index]
        // Pre-capture as a value type before search.start, whose callback runs on a background queue
        let fallback = LocationModel(title: completion.title, subtitle: completion.subtitle)
        let searchRequest = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: searchRequest)

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<LocationModel, Error>) in
            let onceGuard = OnceGuard(continuation)
            search.start { response, error in
                if let error = error {
                    onceGuard.resume(throwing: error)
                    return
                }

                if let mapItem = response?.mapItems.first {
                    onceGuard.resume(returning: LocationModel(with: mapItem))
                } else {
                    onceGuard.resume(returning: fallback)
                }
            }
        }
    }
}

// MARK: - MKLocalSearchCompleterDelegate

extension LocationSearchService: MKLocalSearchCompleterDelegate {

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let completions = completer.results.enumerated().map { SearchCompletion(
            title: $1.title,
            subtitle: $1.subtitle,
            index: $0
        ) }
        delegate?.didUpdate(results: completions)
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        delegate?.didFail(with: error)
    }
}
