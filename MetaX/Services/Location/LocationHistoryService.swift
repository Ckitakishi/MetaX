//
//  LocationHistoryService.swift
//  MetaX
//
//  Created by Yuhan Chen on 2026/02/09.
//

import Foundation
import MapKit

/// Represents a location saved in the search history.
struct HistoryLocation: Codable, Equatable, Sendable {
    let title: String
    let subtitle: String
    let latitude: Double
    let longitude: Double

    var country: String?
    var countryCode: String?
    var state: String?
    var city: String?
    var street: String?
    var houseNumber: String?

    /// Unique identity based on address text.
    var identifier: String {
        "\(title)|\(subtitle)"
    }
}

final class LocationHistoryService: LocationHistoryServiceProtocol {
    // MARK: - Constants

    private let key = "com.metax.recent_locations"
    private let maxCount = 10

    // MARK: - Initialization

    init() {}

    // MARK: - Persistence

    func save(_ location: HistoryLocation) {
        var history = fetchAll()

        // Remove existing item to avoid duplicates and handle re-ordering.
        history.removeAll { $0.identifier == location.identifier }

        // Insert at beginning and limit size.
        history.insert(location, at: 0)
        if history.count > maxCount {
            history = Array(history.prefix(maxCount))
        }

        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func fetchAll() -> [HistoryLocation] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let history = try? JSONDecoder().decode([HistoryLocation].self, from: data)
        else {
            return []
        }
        return history
    }

    func delete(at index: Int) {
        var history = fetchAll()
        guard index < history.count else { return }

        history.remove(at: index)
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func clearAll() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
