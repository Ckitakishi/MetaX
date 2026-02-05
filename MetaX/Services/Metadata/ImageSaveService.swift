//
//  ImageSaveService.swift
//  MetaX
//
//  Created by Chen Yuhan on 2026/02/03.
//  Copyright © 2026 Chen Yuhan. All rights reserved.
//

import Photos
import CoreImage
import UIKit

/// Protocol defining image save operations
protocol ImageSaveServiceProtocol {
    /// Save image with new metadata properties
    func saveImage(
        asset: PHAsset,
        newProperties: [String: Any],
        deleteOriginal: Bool
    ) async -> Result<PHAsset, MetaXError>
}

/// Service for saving images with modified metadata
final class ImageSaveService: ImageSaveServiceProtocol {

    // MARK: - Dependencies

    private let photoLibraryService: PhotoLibraryServiceProtocol

    // MARK: - Initialization

    init(photoLibraryService: PhotoLibraryServiceProtocol = PhotoLibraryService.shared) {
        self.photoLibraryService = photoLibraryService
    }

    // MARK: - Public Methods

    func saveImage(
        asset: PHAsset,
        newProperties: [String: Any],
        deleteOriginal: Bool
    ) async -> Result<PHAsset, MetaXError> {
        // 1. Ensure MetaX album exists
        let albumResult = await photoLibraryService.createAlbumIfNeeded(title: "MetaX")
        guard case .success = albumResult else {
            return .failure(.albumCreationFailed)
        }

        // 2. Request content editing input and create temp file
        let tempURLResult = await requestContentEditingInput(for: asset, newProperties: newProperties)
        guard case .success(let tempURL) = tempURLResult else {
            if case .failure(let error) = tempURLResult {
                return .failure(error)
            }
            return .failure(.imageEditionFailed)
        }

        // 3. Create new asset from temp file
        let createResult = await createAsset(from: tempURL)

        // 4. Clean up temp file
        try? FileManager.default.removeItem(at: tempURL)

        guard case .success(let newAsset) = createResult else {
            if case .failure(let error) = createResult {
                return .failure(error)
            }
            return .failure(.imageCreationFailed)
        }

        // 5. Delete original if requested
        if deleteOriginal {
            _ = await photoLibraryService.deleteAsset(asset)
        }

        return .success(newAsset)
    }

    // MARK: - Private Methods

    private func requestContentEditingInput(
        for asset: PHAsset,
        newProperties: [String: Any]
    ) async -> Result<URL, MetaXError> {
        await withCheckedContinuation { continuation in
            let options = PHContentEditingInputRequestOptions()
            options.isNetworkAccessAllowed = true

            asset.requestContentEditingInput(with: options) { contentEditingInput, _ in
                guard let imageURL = contentEditingInput?.fullSizeImageURL else {
                    continuation.resume(returning: .failure(.imageEditionFailed))
                    return
                }

                guard let ciImage = CIImage(contentsOf: imageURL) else {
                    continuation.resume(returning: .failure(.imageEditionFailed))
                    return
                }

                let context = CIContext(options: nil)
                var tmpUrl = URL(fileURLWithPath: NSTemporaryDirectory() + imageURL.lastPathComponent)

                guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent),
                      let cgImageSource = CGImageSourceCreateWithURL(imageURL as CFURL, nil),
                      let sourceType = CGImageSourceGetType(cgImageSource) else {
                    continuation.resume(returning: .failure(.imageEditionFailed))
                    return
                }

                var createdDestination = CGImageDestinationCreateWithURL(tmpUrl as CFURL, sourceType, 1, nil)

                if createdDestination == nil {
                    // media type is unsupported: delete temp file, create new one with extension [.JPG]
                    try? FileManager.default.removeItem(at: tmpUrl)
                    tmpUrl = URL(fileURLWithPath: NSTemporaryDirectory() + imageURL.deletingPathExtension().lastPathComponent + ".JPG")
                    createdDestination = CGImageDestinationCreateWithURL(tmpUrl as CFURL, "public.jpeg" as CFString, 1, nil)
                }

                guard let destination = createdDestination else {
                    continuation.resume(returning: .failure(.imageEditionFailed))
                    return
                }

                CGImageDestinationAddImage(destination, cgImage, newProperties as CFDictionary)
                if CGImageDestinationFinalize(destination) {
                    continuation.resume(returning: .success(tmpUrl))
                } else {
                    continuation.resume(returning: .failure(.imageEditionFailed))
                }
            }
        }
    }

    private func createAsset(from tempURL: URL) async -> Result<PHAsset, MetaXError> {
        var localId: String = ""

        do {
            try await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: tempURL)
                localId = request?.placeholderForCreatedAsset?.localIdentifier ?? ""

                let fetchOptions = PHFetchOptions()
                fetchOptions.predicate = NSPredicate(format: "title = %@", "MetaX")
                let collection = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)

                if let album = collection.firstObject,
                   let placeholder = request?.placeholderForCreatedAsset {
                    let albumChangeRequest = PHAssetCollectionChangeRequest(for: album)
                    albumChangeRequest?.addAssets([placeholder] as NSArray)
                }
            }

            let results = PHAsset.fetchAssets(withLocalIdentifiers: [localId], options: nil)
            guard let asset = results.firstObject else {
                return .failure(.imageCreationFailed)
            }

            return .success(asset)
        } catch {
            return .failure(.imageCreationFailed)
        }
    }
}
