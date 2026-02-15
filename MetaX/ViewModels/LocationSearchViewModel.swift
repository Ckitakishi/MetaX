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
final class LocationSearchViewModel: LocationSearchServiceDelegate {

    // MARK: - Properties

    private(set) var searchResults: [MKLocalSearchCompletion] = []
    private(set) var history: [HistoryLocation] = []
    private(set) var error: Error?
    private(set) var selectedLocation: LocationModel?

    private let historyService: LocationHistoryServiceProtocol
    private var searchService: LocationSearchServiceProtocol
    private var searchTask: Task<Void, Never>?

    // MARK: - Initialization

    init(historyService: LocationHistoryServiceProtocol, searchService: LocationSearchServiceProtocol) {
        self.historyService = historyService
        self.searchService = searchService
        history = historyService.fetchAll()

        self.searchService.delegate = self
    }

    // MARK: - Public Methods

    func search(query: String) {
        searchTask?.cancel()

        if query.isEmpty {
            searchResults = []
            refreshHistory()
            return
        }

        searchTask = Task {
            // Debounce for 300ms
            try? await Task.sleep(nanoseconds: 300 * 1_000_000)
            if Task.isCancelled { return }

            searchService.search(query: query)
        }
    }

    func refreshHistory() {
        history = historyService.fetchAll()
    }

    func deleteHistory(at index: Int) {
        historyService.delete(at: index)
        refreshHistory()
    }

    func clearResults() {
        searchResults = []
    }

    func selectLocation(at index: Int) async -> LocationModel? {
        guard index < searchResults.count else { return nil }

        let selected = searchResults[index]

        do {
            let locationModel = try await searchService.resolve(completion: selected)
            selectedLocation = locationModel

            if let coord = locationModel.coordinate {
                let historyItem = HistoryLocation(
                    title: locationModel.name,
                    subtitle: locationModel.shortPlacemark,
                    latitude: coord.latitude,
                    longitude: coord.longitude,
                    country: locationModel.country,
                    countryCode: locationModel.countryCode,
                    state: locationModel.state,
                    city: locationModel.city,
                    street: locationModel.street,
                    houseNumber: locationModel.houseNumber
                )
                historyService.save(historyItem)
                refreshHistory()
            }
            return locationModel
        } catch {
            self.error = error
            return nil
        }
    }

    func selectHistory(at index: Int) -> LocationModel? {
        guard index < history.count else { return nil }
        let item = history[index]
        var model = LocationModel(title: item.title, subtitle: item.subtitle)
        model.coordinate = CLLocationCoordinate2D(latitude: item.latitude, longitude: item.longitude)

        // Restore rich data
        model.country = item.country
        model.countryCode = item.countryCode
        model.state = item.state
        model.city = item.city
        model.street = item.street
        model.houseNumber = item.houseNumber

        // Move to top of history
        historyService.save(item)
        refreshHistory()

        return model
    }

    // MARK: - LocationSearchServiceDelegate

    nonisolated func didUpdate(results: [MKLocalSearchCompletion]) {
        Task { @MainActor in
            self.searchResults = results
        }
    }

    nonisolated func didFail(with error: Error) {
        Task { @MainActor in
            self.error = error
        }
    }
}
