//
//  MetadataServiceProtocol.swift
//  MetaX
//
//  Created by Chen Yuhan on 2026/02/03.
//  Copyright © 2026 Chen Yuhan. All rights reserved.
//

import CoreLocation
import Photos

/// Protocol defining metadata operations
protocol MetadataServiceProtocol {
    // MARK: - Load Metadata

    /// Load metadata from a PHAsset
    func loadMetadata(from asset: PHAsset) async -> Result<Metadata, MetaXError>

    /// Load metadata from a URL
    func loadMetadata(from url: URL) -> Result<Metadata, MetaXError>

    // MARK: - Modify Metadata

    /// Update timestamp in metadata, returns modified properties dictionary
    func updateTimestamp(_ date: Date, in metadata: Metadata) -> [String: Any]

    /// Remove timestamp from metadata, returns modified properties dictionary
    func removeTimestamp(from metadata: Metadata) -> [String: Any]

    /// Update location in metadata, returns modified properties dictionary
    func updateLocation(_ location: CLLocation, in metadata: Metadata) -> [String: Any]

    /// Remove location from metadata, returns modified properties dictionary
    func removeLocation(from metadata: Metadata) -> [String: Any]

    /// Remove all metadata except orientation, returns modified properties dictionary
    func removeAllMetadata(from metadata: Metadata) -> [String: Any]

    /// Update multiple metadata fields at once
    func updateMetadata(with batch: [String: Any], in metadata: Metadata) -> [String: Any]
}
