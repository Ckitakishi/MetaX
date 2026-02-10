//
//  LocationSearchServiceProtocol.swift
//  MetaX
//
//  Created by Yuhan Chen on 2026/02/09.
//

import MapKit

protocol LocationSearchServiceDelegate: AnyObject {
    func didUpdate(results: [MKLocalSearchCompletion])
    func didFail(with error: Error)
}

protocol LocationSearchServiceProtocol: AnyObject {
    var delegate: LocationSearchServiceDelegate? { get set }
    
    func search(query: String)
    func resolve(completion: MKLocalSearchCompletion, resultHandler: @escaping (Result<LocationModel, Error>) -> Void)
}
