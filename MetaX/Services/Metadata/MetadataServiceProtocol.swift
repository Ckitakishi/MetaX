//
//  MetadataServiceProtocol.swift
//  MetaX
//
//  Created by Chen Yuhan on 2026/02/03.
//  Copyright © 2026 Chen Yuhan. All rights reserved.
//

import CoreLocation
import Photos

/// Protocol defining metadata operations.
protocol MetadataServiceProtocol: Sendable {
    // MARK: - Load Metadata

    /// Loads metadata as a stream of events.
    func loadMetadataEvents(from asset: PHAsset) -> AsyncStream<MetadataLoadEvent>

    // MARK: - Modify Metadata

    /// Updates timestamp in metadata.
    func updateTimestamp(_ date: Date, in metadata: Metadata) -> MetadataUpdateIntent

    /// Removes timestamp from metadata.
    func removeTimestamp(from metadata: Metadata) -> MetadataUpdateIntent

    /// Updates location in metadata.
    func updateLocation(_ location: CLLocation, in metadata: Metadata) -> MetadataUpdateIntent

    /// Removes location from metadata.
    func removeLocation(from metadata: Metadata) -> MetadataUpdateIntent

    /// Removes all metadata except orientation.
    func removeAllMetadata(from metadata: Metadata) -> MetadataUpdateIntent

    /// Updates multiple metadata fields at once.
    func updateMetadata(with batch: [String: Any], in metadata: Metadata) -> MetadataUpdateIntent
}
