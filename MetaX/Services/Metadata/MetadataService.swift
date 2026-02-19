//
//  MetadataService.swift
//  MetaX
//
//  Created by Chen Yuhan on 2026/02/03.
//  Copyright © 2026 Chen Yuhan. All rights reserved.
//

import CoreImage
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
            let options = PHContentEditingInputRequestOptions()
            options.isNetworkAccessAllowed = true

            options.progressHandler = { progress, _ in
                // progress == 1.0 means instantly-complete (local asset edge case), skip
                guard progress < 1.0 else { return }
                continuation.yield(.progress(progress))
            }

            let requestId = asset.requestContentEditingInput(with: options) { input, info in
                if let inCloud = info[PHContentEditingInputResultIsInCloudKey] as? Bool, inCloud, input == nil {
                    return
                }

                defer { continuation.finish() }

                if let error = info[PHContentEditingInputErrorKey] as? Error {
                    continuation.yield(.failure(.photoLibrary(.assetFetchFailed(underlying: error))))
                } else if let input = input,
                          let imageURL = input.fullSizeImageURL,
                          let ciImage = CIImage(contentsOf: imageURL),
                          let metadata = Metadata(ciimage: ciImage, asset: asset) {
                    continuation.yield(.success(metadata))
                } else {
                    continuation.yield(.failure(.metadata(.readFailed)))
                }
            }

            continuation.onTermination = { _ in
                asset.cancelContentEditingInputRequest(requestId)
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
        metadata.deleteGPS() ?? metadata.sourceProperties
    }

    func removeAllMetadata(from metadata: Metadata) -> [String: Any] {
        metadata.deleteAllExceptOrientation() ?? metadata.sourceProperties
    }

    func updateMetadata(with batch: [String: Any], in metadata: Metadata) -> [String: Any] {
        metadata.write(batch: batch)
    }
}
