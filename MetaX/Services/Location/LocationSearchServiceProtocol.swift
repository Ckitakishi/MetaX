//
//  LocationSearchServiceProtocol.swift
//  MetaX
//
//  Created by Yuhan Chen on 2026/02/09.
//

struct SearchCompletion: Sendable {
    let title: String
    let subtitle: String
    let index: Int
}

protocol LocationSearchServiceDelegate: AnyObject {
    func didUpdate(results: [SearchCompletion])
    func didFail(with error: Error)
}

protocol LocationSearchServiceProtocol: AnyObject {
    var delegate: LocationSearchServiceDelegate? { get set }

    func search(query: String)
    func cancel()
    @MainActor func resolve(at index: Int) async throws -> LocationModel
}
