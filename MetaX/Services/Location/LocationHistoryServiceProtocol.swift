//
//  LocationHistoryServiceProtocol.swift
//  MetaX
//
//  Created by Yuhan Chen on 2026/02/09.
//

import Foundation

protocol LocationHistoryServiceProtocol {
    func save(_ location: HistoryLocation)
    func fetchAll() -> [HistoryLocation]
    func delete(at index: Int)
    func clearAll()
}
