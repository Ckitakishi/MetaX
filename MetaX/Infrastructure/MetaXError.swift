//
//  MetaXError.swift
//  MetaX
//
//  Created by Chen Yuhan on 2026/02/03.
//  Copyright © 2026 Chen Yuhan. All rights reserved.
//

import Foundation

/// Unified error type for MetaX application
enum MetaXError: Error, Sendable {
    case photoLibrary(PhotoLibrary)
    case metadata(Metadata)
    case imageSave(ImageSave)
    case location(Location)
    case store(Store)
    case unknown(underlying: Error?)

    enum PhotoLibrary: Sendable {
        case accessDenied
        case unavailable
        case assetNotFound
        case assetFetchFailed(underlying: Error?)
    }

    enum Metadata: Sendable {
        case readFailed
        case writeFailed
        case unsupportedMediaType
        case iCloudSyncRequired
        case iCloudSyncFailed
    }

    enum ImageSave: Sendable {
        case editionFailed
        case creationFailed
        case albumCreationFailed
        case temporaryFileError
    }

    enum Location: Sendable {
        case accessDenied
        case geocodingFailed
        case coordinateNotAvailable
    }

    enum Store: Sendable {
        case productNotFound
        case purchaseFailed
        case purchaseRestricted
        case restoreFailed
    }
}

// MARK: - Error Code

extension MetaXError {
    /// Numerical error code for tracking and support (e.g., MX-1001).
    var code: Int {
        switch self {
        case let .photoLibrary(error):
            switch error {
            case .accessDenied: return 1001
            case .unavailable: return 1002
            case .assetNotFound: return 1003
            case .assetFetchFailed: return 1004
            }
        case let .metadata(error):
            switch error {
            case .readFailed: return 1010
            case .writeFailed: return 1011
            case .unsupportedMediaType: return 1012
            case .iCloudSyncRequired: return 1013
            case .iCloudSyncFailed: return 1014
            }
        case let .imageSave(error):
            switch error {
            case .editionFailed: return 1020
            case .creationFailed: return 1021
            case .albumCreationFailed: return 1022
            case .temporaryFileError: return 1023
            }
        case let .location(error):
            switch error {
            case .accessDenied: return 1030
            case .geocodingFailed: return 1031
            case .coordinateNotAvailable: return 1032
            }
        case let .store(error):
            switch error {
            case .productNotFound: return 1040
            case .purchaseFailed: return 1041
            case .purchaseRestricted: return 1042
            case .restoreFailed: return 1043
            }
        case .unknown:
            return 1090
        }
    }
}

// MARK: - LocalizedError

extension MetaXError: LocalizedError {
    var errorDescription: String? {
        let message: String
        switch self {
        case .photoLibrary(.accessDenied):
            message = String(localized: .alertPhotoAccess)
        case .photoLibrary(.unavailable),
             .photoLibrary(.assetNotFound),
             .photoLibrary(.assetFetchFailed):
            message = String(localized: .errorImageSaveUnknown)
        case .metadata(.readFailed), .metadata(.writeFailed):
            message = String(localized: .errorImageSaveEdition)
        case .metadata(.unsupportedMediaType):
            message = String(localized: .infoNotSupport)
        case .metadata(.iCloudSyncRequired), .metadata(.iCloudSyncFailed):
            message = String(localized: .errorICloud)
        case .imageSave(.editionFailed), .imageSave(.temporaryFileError):
            message = String(localized: .errorImageSaveEdition)
        case .imageSave(.creationFailed), .imageSave(.albumCreationFailed):
            message = String(localized: .errorImageSaveCreation)
        case .location(.accessDenied):
            message = String(localized: .alertPhotoAccess)
        case .location(.geocodingFailed), .location(.coordinateNotAvailable):
            message = String(localized: .errorCoordinateFetch)
        case .store:
            message = String(localized: .errorStoreFailed)
        case .unknown:
            message = String(localized: .errorImageSaveUnknown)
        }
        return "\(message) (MX-\(code))"
    }
}
