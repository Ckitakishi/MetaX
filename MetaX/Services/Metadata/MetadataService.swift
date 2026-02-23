//
//  MetadataService.swift
//  MetaX
//
//  Created by Chen Yuhan on 2026/02/03.
//  Copyright © 2026 Chen Yuhan. All rights reserved.
//

import CoreLocation
import Photos

/// High-level service for loading and generating metadata update intents.
/// This service acts as a facade, bridging the UI requests to the underlying Metadata model logic.
final class MetadataService: MetadataServiceProtocol, @unchecked Sendable {

    // MARK: - Initialization

    init() {}

    // MARK: - Load Metadata

    func loadMetadataEvents(from asset: PHAsset) -> AsyncStream<MetadataLoadEvent> {
        AsyncStream<MetadataLoadEvent> { continuation in
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .highQualityFormat
            options.version = .current // Always request the latest rendered version

            options.progressHandler = { progress, _, _, _ in
                guard progress < 1.0 else { return }
                continuation.yield(.progress(progress))
            }

            let requestId = PHImageManager.default()
                .requestImageDataAndOrientation(for: asset, options: options) { imageData, _, _, info in

                    if let fetchError = info?[PHImageErrorKey] as? Error {
                        continuation.yield(.failure(.photoLibrary(.assetFetchFailed(underlying: fetchError))))
                        continuation.finish()
                        return
                    }

                    guard let data = imageData else {
                        continuation.yield(.failure(.metadata(.readFailed)))
                        continuation.finish()
                        return
                    }

                    if let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
                       let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] {
                        let metadataModel = Metadata(props: properties, asset: asset)
                        continuation.yield(.success(metadataModel))
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

    // MARK: - Intent Generation Bridge

    func updateTimestamp(_ date: Date, in metadata: Metadata) -> MetadataUpdateIntent {
        metadata.writeTimeOriginal(date)
    }

    func removeTimestamp(from metadata: Metadata) -> MetadataUpdateIntent {
        metadata.deleteTimeOriginal()
    }

    func updateLocation(_ location: CLLocation, in metadata: Metadata) -> MetadataUpdateIntent {
        metadata.writeLocation(location)
    }

    func removeLocation(from metadata: Metadata) -> MetadataUpdateIntent {
        metadata.deleteGPS()
    }

    func removeAllMetadata(from metadata: Metadata) -> MetadataUpdateIntent {
        metadata.deleteAllExceptOrientation()
    }

    func updateMetadata(with batch: [String: Any], in metadata: Metadata) -> MetadataUpdateIntent {
        metadata.write(batch: batch)
    }
}
