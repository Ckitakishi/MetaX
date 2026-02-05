//
//  MetaXError.swift
//  MetaX
//
//  Created by Chen Yuhan on 2026/02/03.
//  Copyright © 2026 Chen Yuhan. All rights reserved.
//

import Foundation

/// Unified error type for MetaX application
enum MetaXError: Error {
    // MARK: - Photo Library Errors
    case photoLibraryAccessDenied
    case photoLibraryUnavailable
    case assetNotFound
    case assetFetchFailed(underlying: Error?)

    // MARK: - Metadata Errors
    case metadataReadFailed
    case metadataWriteFailed
    case unsupportedMediaType
    case iCloudSyncRequired
    case iCloudSyncFailed

    // MARK: - Image Save Errors
    case imageEditionFailed
    case imageCreationFailed
    case albumCreationFailed
    case temporaryFileError

    // MARK: - Location Errors
    case locationAccessDenied
    case geocodingFailed
    case coordinateNotAvailable

    // MARK: - General
    case unknown(underlying: Error?)
}

// MARK: - LocalizedError
extension MetaXError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .photoLibraryAccessDenied:
            return R.string.localizable.alertPhotoAccess()
        case .photoLibraryUnavailable:
            return R.string.localizable.errorImageSaveUnknown()
        case .assetNotFound, .assetFetchFailed:
            return R.string.localizable.errorImageSaveUnknown()
        case .metadataReadFailed, .metadataWriteFailed:
            return R.string.localizable.errorImageSaveEdition()
        case .unsupportedMediaType:
            return R.string.localizable.infoNotSupport()
        case .iCloudSyncRequired, .iCloudSyncFailed:
            return R.string.localizable.errorICloud()
        case .imageEditionFailed:
            return R.string.localizable.errorImageSaveEdition()
        case .imageCreationFailed:
            return R.string.localizable.errorImageSaveCreation()
        case .albumCreationFailed:
            return R.string.localizable.errorImageSaveCreation()
        case .temporaryFileError:
            return R.string.localizable.errorImageSaveEdition()
        case .locationAccessDenied:
            return R.string.localizable.alertPhotoAccess()
        case .geocodingFailed, .coordinateNotAvailable:
            return R.string.localizable.errorCoordinateFetch()
        case .unknown:
            return R.string.localizable.errorImageSaveUnknown()
        }
    }
}
