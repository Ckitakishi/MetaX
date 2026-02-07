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
            message = R.string.localizable.alertPhotoAccess()
        case .photoLibrary(.unavailable),
             .photoLibrary(.assetNotFound),
             .photoLibrary(.assetFetchFailed):
            message = R.string.localizable.errorImageSaveUnknown()
        case .metadata(.readFailed), .metadata(.writeFailed):
            message = R.string.localizable.errorImageSaveEdition()
        case .metadata(.unsupportedMediaType):
            message = R.string.localizable.infoNotSupport()
        case .metadata(.iCloudSyncRequired), .metadata(.iCloudSyncFailed):
            message = R.string.localizable.errorICloud()
        case .imageSave(.editionFailed), .imageSave(.temporaryFileError):
            message = R.string.localizable.errorImageSaveEdition()
        case .imageSave(.creationFailed), .imageSave(.albumCreationFailed):
            message = R.string.localizable.errorImageSaveCreation()
        case .location(.accessDenied):
            message = R.string.localizable.alertPhotoAccess()
        case .location(.geocodingFailed), .location(.coordinateNotAvailable):
            message = R.string.localizable.errorCoordinateFetch()
        case .unknown:
            message = R.string.localizable.errorImageSaveUnknown()
        }
        return "\(message) (MX-\(code))"
    }
}
