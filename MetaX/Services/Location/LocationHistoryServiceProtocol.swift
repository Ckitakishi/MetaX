//
//  LocationHistoryServiceProtocol.swift
//  MetaX
//
//  Created by Yuhan Chen on 2026/02/09.
//

import Foundation

/// Defines the capabilities for managing location search history.
protocol LocationHistoryServiceProtocol {
    /// Saves a location to history, moving it to the top if it already exists.
    func save(_ location: HistoryLocation)

    /// Returns all saved locations from history.
    func fetchAll() -> [HistoryLocation]

    /// Deletes a location from history at the specified index.
    func delete(at index: Int)

    /// Clears all locations from history.
    func clearAll()
}
