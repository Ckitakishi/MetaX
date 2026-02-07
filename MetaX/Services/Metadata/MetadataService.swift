//
//  MetadataService.swift
//  MetaX
//
//  Created by Chen Yuhan on 2026/02/03.
//  Copyright © 2026 Chen Yuhan. All rights reserved.
//

import Photos
import CoreLocation
import CoreImage

/// Service for metadata operations
final class MetadataService: MetadataServiceProtocol {

    // MARK: - Initialization

    init() {}

    // MARK: - Load Metadata

    func loadMetadata(from asset: PHAsset) async -> Result<Metadata, MetaXError> {
        // Validate media type - only support images, not live photos (mediaSubtypes.rawValue == 32)
        guard asset.mediaType == .image, asset.mediaSubtypes.rawValue != 32 else {
            return .failure(.metadata(.unsupportedMediaType))
        }

        return await withCheckedContinuation { continuation in
            let options = PHContentEditingInputRequestOptions()
            options.isNetworkAccessAllowed = true

            asset.requestContentEditingInput(with: options) { input, info in
                // Check iCloud status
                if let inCloudKey = info[PHContentEditingInputResultIsInCloudKey] as? Int,
                   inCloudKey == 1,
                   input?.fullSizeImageURL == nil {
                    continuation.resume(returning: .failure(.metadata(.iCloudSyncFailed)))
                    return
                }

                // Check for errors
                if let error = info[PHContentEditingInputErrorKey] as? Error {
                    continuation.resume(returning: .failure(.photoLibrary(.assetFetchFailed(underlying: error))))
                    return
                }

                guard let imageURL = input?.fullSizeImageURL,
                      let ciImage = CIImage(contentsOf: imageURL),
                      let metadata = Metadata(ciimage: ciImage) else {
                    continuation.resume(returning: .failure(.metadata(.readFailed)))
                    return
                }

                continuation.resume(returning: .success(metadata))
            }
        }
    }

    func loadMetadata(from url: URL) -> Result<Metadata, MetaXError> {
        guard let metadata = Metadata(contentsOf: url) else {
            return .failure(.metadata(.readFailed))
        }
        return .success(metadata)
    }

    // MARK: - Modify Metadata

    func updateTimestamp(_ date: Date, in metadata: Metadata) -> [String: Any] {
        metadata.writeTimeOriginal(date)
    }

    func removeTimestamp(from metadata: Metadata) -> [String: Any] {
        metadata.deleteTimeOriginal() ?? metadata.sourceProperties
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
}
