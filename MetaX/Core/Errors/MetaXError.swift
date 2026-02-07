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
    case photoLibrary(PhotoLibrary)
    case metadata(Metadata)
    case imageSave(ImageSave)
    case location(Location)
    case unknown(underlying: Error?)

    enum PhotoLibrary {
        case accessDenied
        case unavailable
        case assetNotFound
        case assetFetchFailed(underlying: Error?)
    }

    enum Metadata {
        case readFailed
        case writeFailed
        case unsupportedMediaType
        case iCloudSyncRequired
        case iCloudSyncFailed
    }

    enum ImageSave {
        case editionFailed
        case creationFailed
        case albumCreationFailed
        case temporaryFileError
    }

    enum Location {
        case accessDenied
        case geocodingFailed
        case coordinateNotAvailable
    }
}

// MARK: - Error Code

extension MetaXError {
    var code: Int {
        switch self {
        case .photoLibrary(let error):
            switch error {
            case .accessDenied:    return 1001
            case .unavailable:     return 1002
            case .assetNotFound:   return 1003
            case .assetFetchFailed: return 1004
            }
        case .metadata(let error):
            switch error {
            case .readFailed:           return 1010
            case .writeFailed:          return 1011
            case .unsupportedMediaType: return 1012
            case .iCloudSyncRequired:   return 1013
            case .iCloudSyncFailed:     return 1014
            }
        case .imageSave(let error):
            switch error {
            case .editionFailed:       return 1020
            case .creationFailed:      return 1021
            case .albumCreationFailed: return 1022
            case .temporaryFileError:  return 1023
            }
        case .location(let error):
            switch error {
            case .accessDenied:          return 1030
            case .geocodingFailed:       return 1031
            case .coordinateNotAvailable: return 1032
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
        case .unknown:
            message = String(localized: .errorImageSaveUnknown)
        }
        return "\(message) (MX-\(code))"
    }
}
