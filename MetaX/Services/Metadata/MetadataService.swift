//
//  MetadataService.swift
//  MetaX
//
//  Created by Chen Yuhan on 2026/02/03.
//  Copyright © 2026 Chen Yuhan. All rights reserved.
//

import CoreLocation
import Photos

/// Service for metadata operations
/// @unchecked Sendable: stateless service, all methods operate on their inputs only.
final class MetadataService: MetadataServiceProtocol, @unchecked Sendable {

    // MARK: - Initialization

    init() {}

    // MARK: - Load Metadata

    func loadMetadataEvents(from asset: PHAsset) -> AsyncStream<MetadataLoadEvent> {
        AsyncStream<MetadataLoadEvent> { continuation in
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .highQualityFormat
            options.version = .current // IMPORTANT: Always request the latest rendered version

            options.progressHandler = { progress, _, _, _ in
                // progress == 1.0 means instantly-complete, skip
                guard progress < 1.0 else { return }
                continuation.yield(.progress(progress))
            }

            let requestId = PHImageManager.default()
                .requestImageDataAndOrientation(for: asset, options: options) { data, _, _, info in
                    if let error = info?[PHImageErrorKey] as? Error {
                        continuation.yield(.failure(.photoLibrary(.assetFetchFailed(underlying: error))))
                        continuation.finish()
                        return
                    }

                    if let data = data {
                        if let source = CGImageSourceCreateWithData(data as CFData, nil),
                           let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] {
                            if let metadata = Metadata(props: properties, asset: asset) {
                                continuation.yield(.success(metadata))
                            } else {
                                continuation.yield(.failure(.metadata(.readFailed)))
                            }
                        } else {
                            continuation.yield(.failure(.metadata(.readFailed)))
                        }
                    } else {
                        continuation.yield(.failure(.metadata(.readFailed)))
                    }
                    continuation.finish()
                }

            continuation.onTermination = { _ in
                PHImageManager.default().cancelImageRequest(requestId)
            }
        }
    }

    // MARK: - Modify Metadata

    func updateTimestamp(_ date: Date, in metadata: Metadata) -> [String: Any] {
        metadata.writeTimeOriginal(date)
    }

    func removeTimestamp(from metadata: Metadata) -> [String: Any] {
        metadata.deleteTimeOriginal()
    }

    func updateLocation(_ location: CLLocation, in metadata: Metadata) -> [String: Any] {
        metadata.writeLocation(location)
    }

    func removeLocation(from metadata: Metadata) -> [String: Any] {
        metadata.deleteGPS() ?? [:]
    }

    func removeAllMetadata(from metadata: Metadata) -> [String: Any] {
        metadata.deleteAllExceptOrientation() ?? [:]
    }

    func updateMetadata(with batch: [String: Any], in metadata: Metadata) -> [String: Any] {
        metadata.write(batch: batch)
    }
}
