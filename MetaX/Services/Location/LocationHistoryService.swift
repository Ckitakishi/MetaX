//
//  LocationHistoryService.swift
//  MetaX
//
//  Created by Yuhan Chen on 2026/02/09.
//

import Foundation
import MapKit

struct HistoryLocation: Codable, Equatable {
    let title: String
    let subtitle: String
    let latitude: Double
    let longitude: Double
    
    // Rich Data for persistence
    var country: String?
    var countryCode: String?
    var state: String?
    var city: String?
    var street: String?
    var houseNumber: String?

    // Unique identity based on address text
    var identifier: String {
        return "\(title)|\(subtitle)"
    }

    static func == (lhs: HistoryLocation, rhs: HistoryLocation) -> Bool {
        return lhs.identifier == rhs.identifier
    }
}

final class LocationHistoryService: LocationHistoryServiceProtocol {
    private let key = "com.metax.recent_locations"
    private let maxCount = 10
    
    init() {}
    
    func save(_ location: HistoryLocation) {
        var history = fetchAll()
        
        // Remove existing item with same identifier to avoid duplicates and handle re-ordering
        history.removeAll { $0.identifier == location.identifier }
        
        // Insert at beginning
        history.insert(location, at: 0)
        
        // Limit size
        if history.count > maxCount {
            history = Array(history.prefix(maxCount))
        }
        
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    
    func fetchAll() -> [HistoryLocation] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let history = try? JSONDecoder().decode([HistoryLocation].self, from: data) else {
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
