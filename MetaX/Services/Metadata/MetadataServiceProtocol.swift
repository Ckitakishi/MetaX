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
protocol MetadataServiceProtocol: Sendable {
    // MARK: - Load Metadata

    /// Loads metadata as a stream of events, allowing for progress updates and cancellation.
    func loadMetadataEvents(from asset: PHAsset) -> AsyncStream<MetadataLoadEvent>

    // MARK: - Modify Metadata

    /// Update timestamp in metadata, returns structured update intent
    func updateTimestamp(_ date: Date, in metadata: Metadata) -> MetadataUpdateIntent

    /// Remove timestamp from metadata, returns structured update intent
    func removeTimestamp(from metadata: Metadata) -> MetadataUpdateIntent

    /// Update location in metadata, returns structured update intent
    func updateLocation(_ location: CLLocation, in metadata: Metadata) -> MetadataUpdateIntent

    /// Remove location from metadata, returns structured update intent
    func removeLocation(from metadata: Metadata) -> MetadataUpdateIntent

    /// Remove all metadata except orientation, returns structured update intent
    func removeAllMetadata(from metadata: Metadata) -> MetadataUpdateIntent

    /// Update multiple metadata fields at once, returns structured update intent
    func updateMetadata(with batch: [String: Any], in metadata: Metadata) -> MetadataUpdateIntent
}
