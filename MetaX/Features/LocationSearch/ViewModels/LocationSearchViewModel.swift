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

    enum RowType {
        case history(HistoryLocation)
        case result(MKLocalSearchCompletion)
    }

    struct Section {
        let title: String?
        let rows: [RowType]
    }

    // MARK: - Properties (Public State)

    private(set) var sections: [Section] = []
    var onError: ((Error) -> Void)?

    var isEmpty: Bool {
        sections.allSatisfy { $0.rows.isEmpty }
    }

    var searchText: String = "" {
        didSet {
            performSearch(query: searchText)
        }
    }

    // MARK: - Internal State

    private var searchResults: [MKLocalSearchCompletion] = []
    private var history: [HistoryLocation] = []
    private let historyService: LocationHistoryServiceProtocol
    private var searchService: LocationSearchServiceProtocol
    private var searchTask: Task<Void, Never>?

    // MARK: - Initialization

    init(historyService: LocationHistoryServiceProtocol, searchService: LocationSearchServiceProtocol) {
        self.historyService = historyService
        self.searchService = searchService
        history = historyService.fetchAll()
        self.searchService.delegate = self
        updateSections()
    }

    // MARK: - Public Methods

    func deleteHistory(at index: Int) {
        historyService.delete(at: index)
        history = historyService.fetchAll()
        updateSections()
    }

    func selectItem(at indexPath: IndexPath) async -> LocationModel? {
        guard indexPath.section < sections.count,
              indexPath.row < sections[indexPath.section].rows.count else { return nil }

        let row = sections[indexPath.section].rows[indexPath.row]

        switch row {
        case let .history(item):
            var model = LocationModel(title: item.title, subtitle: item.subtitle)
            model.coordinate = CLLocationCoordinate2D(latitude: item.latitude, longitude: item.longitude)
            model.country = item.country
            model.countryCode = item.countryCode
            model.state = item.state
            model.city = item.city
            model.street = item.street
            model.houseNumber = item.houseNumber

            // Move to top
            historyService.save(item)
            history = historyService.fetchAll()
            updateSections()
            return model

        case let .result(completion):
            do {
                let locationModel = try await searchService.resolve(completion: completion)
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
                    history = historyService.fetchAll()
                    // No need to call updateSections here as resolving a location usually leads to dismissal
                }
                return locationModel
            } catch {
                onError?(error)
                return nil
            }
        }
    }

    // MARK: - Private Methods

    private func performSearch(query: String) {
        searchTask?.cancel()

        if query.isEmpty {
            searchResults = []
            updateSections()
            return
        }

        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300 * 1_000_000)
            if Task.isCancelled { return }
            searchService.search(query: query)
        }
    }

    private func updateSections() {
        if searchText.isEmpty {
            let rows = history.map { RowType.history($0) }
            sections = rows.isEmpty ? [] : [Section(
                title: String(localized: .viewRecentHistory).uppercased(),
                rows: rows
            )]
        } else {
            let rows = searchResults.map { RowType.result($0) }
            sections = [Section(title: nil, rows: rows)]
        }
    }

    // MARK: - LocationSearchServiceDelegate

    nonisolated func didUpdate(results: [MKLocalSearchCompletion]) {
        Task { @MainActor in
            self.searchResults = results
            self.updateSections()
        }
    }

    nonisolated func didFail(with error: Error) {
        Task { @MainActor in
            self.onError?(error)
        }
    }
}
