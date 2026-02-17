//
//  ImageSaveService.swift
//  MetaX
//
//  Created by Chen Yuhan on 2026/02/03.
//  Copyright © 2026 Chen Yuhan. All rights reserved.
//

import CoreImage
@preconcurrency import Photos
import UniformTypeIdentifiers

/// Protocol defining image save operations
/// Methods are @MainActor because `[String: Any]` parameters are not Sendable.
protocol ImageSaveServiceProtocol: Sendable {
    /// Create a new asset with modified metadata
    @MainActor func saveImageAsNewAsset(
        asset: PHAsset,
        newProperties: [String: Any]
    ) async -> Result<PHAsset, MetaXError>

    /// Edit existing asset metadata using non-destructive editing
    @MainActor func editAssetMetadata(
        asset: PHAsset,
        newProperties: [String: Any]
    ) async -> Result<PHAsset, MetaXError>
}

/// Service for saving images with modified metadata
@MainActor
final class ImageSaveService: ImageSaveServiceProtocol {

    // MARK: - Dependencies

    private let photoLibraryService: PhotoLibraryServiceProtocol
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    // MARK: - Initialization

    init(photoLibraryService: PhotoLibraryServiceProtocol) {
        self.photoLibraryService = photoLibraryService
    }

    // MARK: - Public Methods

    func saveImageAsNewAsset(
        asset: PHAsset,
        newProperties: [String: Any]
    ) async -> Result<PHAsset, MetaXError> {
        // 1. Ensure MetaX album exists
        let albumResult = await photoLibraryService.createAlbumIfNeeded(title: "MetaX")
        guard case .success = albumResult else {
            return .failure(.imageSave(.albumCreationFailed))
        }

        // 2. Generate new image data to temp file
        let tempURLResult = await generateModifiedImageFile(for: asset, newProperties: newProperties)
        guard case let .success(tempURL) = tempURLResult else {
            return .failure(tempURLResult.error ?? .imageSave(.editionFailed))
        }

        // 3. Create new asset from temp file
        let createResult = await createAssetInMetaXAlbum(from: tempURL)

        // 4. Clean up temp file
        try? FileManager.default.removeItem(at: tempURL)

        return createResult
    }

    func editAssetMetadata(
        asset: PHAsset,
        newProperties: [String: Any]
    ) async -> Result<PHAsset, MetaXError> {
        if asset.mediaSubtypes.contains(.photoLive) {
            return await editLivePhotoMetadata(asset: asset, newProperties: newProperties)
        }
        return await editStillPhotoMetadata(asset: asset, newProperties: newProperties)
    }

    private func editStillPhotoMetadata(
        asset: PHAsset,
        newProperties: [String: Any]
    ) async -> Result<PHAsset, MetaXError> {
        return await withCheckedContinuation { continuation in
            let options = PHContentEditingInputRequestOptions()
            options.isNetworkAccessAllowed = true

            asset.requestContentEditingInput(with: options) { input, info in
                if let error = info[PHContentEditingInputErrorKey] as? Error {
                    print("[MetaX] editStillPhotoMetadata: requestContentEditingInput error: \(error)")
                }
                guard let input = input, let imageURL = input.fullSizeImageURL else {
                    print("[MetaX] editStillPhotoMetadata: no input or fullSizeImageURL")
                    continuation.resume(returning: .failure(.imageSave(.editionFailed)))
                    return
                }

                let output = PHContentEditingOutput(contentEditingInput: input)

                guard self.writeModifiedImage(
                    sourceURL: imageURL,
                    destinationURL: output.renderedContentURL,
                    newProperties: newProperties
                ) else {
                    print("[MetaX] editStillPhotoMetadata: writeModifiedImage failed")
                    continuation.resume(returning: .failure(.imageSave(.editionFailed)))
                    return
                }

                output.adjustmentData = Self.makeAdjustmentData()

                PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest(for: asset).contentEditingOutput = output
                } completionHandler: { success, error in
                    if success {
                        continuation.resume(returning: .success(asset))
                    } else {
                        print("[MetaX] editStillPhotoMetadata: performChanges failed: \(String(describing: error))")
                        continuation.resume(returning: .failure(.imageSave(.editionFailed)))
                    }
                }
            }
        }
    }

    private func editLivePhotoMetadata(
        asset: PHAsset,
        newProperties: [String: Any]
    ) async -> Result<PHAsset, MetaXError> {
        return await withCheckedContinuation { continuation in
            let options = PHContentEditingInputRequestOptions()
            options.isNetworkAccessAllowed = true

            asset.requestContentEditingInput(with: options) { input, _ in
                guard let input = input,
                      let context = PHLivePhotoEditingContext(livePhotoEditingInput: input)
                else {
                    print("[MetaX] editLivePhotoMetadata: no input or context")
                    continuation.resume(returning: .failure(.imageSave(.editionFailed)))
                    return
                }

                let output = PHContentEditingOutput(contentEditingInput: input)

                // Inject metadata into the still image frame via CIImage.settingProperties.
                // This lets Photos write the complete Live Photo output (still + video) in one
                // pass, so the private content-identifier that pairs still and video is never
                // touched by us and cannot be corrupted.
                //
                // NOTE: This is a shallow merge — `newProperties` must contain complete
                // sub-dicts (e.g. the full {Exif} dict). This is guaranteed because
                // MetadataService always builds from the full `sourceProperties`.
                context.frameProcessor = { frame, _ in
                    guard frame.type == .photo else { return frame.image }
                    let image = frame.image
                    var merged = image.properties
                    for (key, value) in newProperties { merged[key] = value }
                    return image.settingProperties(merged as [AnyHashable: Any])
                }

                context.saveLivePhoto(to: output) { success, error in
                    guard success else {
                        print("[MetaX] editLivePhotoMetadata: saveLivePhoto failed: \(String(describing: error))")
                        continuation.resume(returning: .failure(.imageSave(.editionFailed)))
                        return
                    }

                    output.adjustmentData = Self.makeAdjustmentData()

                    PHPhotoLibrary.shared().performChanges {
                        PHAssetChangeRequest(for: asset).contentEditingOutput = output
                    } completionHandler: { success, error in
                        if success {
                            continuation.resume(returning: .success(asset))
                        } else {
                            print("[MetaX] editLivePhotoMetadata: performChanges failed: \(String(describing: error))")
                            continuation.resume(returning: .failure(.imageSave(.editionFailed)))
                        }
                    }
                }
            }
        }
    }

    private nonisolated static func makeAdjustmentData() -> PHAdjustmentData {
        let dataPayload = ["app": "MetaX", "edit": "metadata", "date": Date()] as [String: Any]
        let archivedData = try? NSKeyedArchiver.archivedData(withRootObject: dataPayload, requiringSecureCoding: false)
        return PHAdjustmentData(
            formatIdentifier: Bundle.main.bundleIdentifier ?? "com.yuhan.metax",
            formatVersion: "1.0",
            data: archivedData ?? "MODIFIED".data(using: .utf8)!
        )
    }

    // MARK: - Private Methods

    private func generateModifiedImageFile(
        for asset: PHAsset,
        newProperties: [String: Any]
    ) async -> Result<URL, MetaXError> {
        await withCheckedContinuation { continuation in
            let options = PHContentEditingInputRequestOptions()
            options.isNetworkAccessAllowed = true

            asset.requestContentEditingInput(with: options) { input, _ in
                guard let imageURL = input?.fullSizeImageURL else {
                    continuation.resume(returning: .failure(.imageSave(.editionFailed)))
                    return
                }

                // Construct a new filename with suffix, avoiding duplicates
                let resources = PHAssetResource.assetResources(for: asset)
                let originalName = resources.first?.originalFilename ?? "IMG.JPG"
                let nameURL = URL(fileURLWithPath: originalName)
                let baseName = nameURL.deletingPathExtension().lastPathComponent
                let ext = nameURL.pathExtension.isEmpty ? "JPG" : nameURL.pathExtension

                let suffix = "_MetaX"
                let finalBaseName = baseName.hasSuffix(suffix) ? baseName : (baseName + suffix)
                let newFileName = "\(finalBaseName).\(ext)"

                let tmpUrl = URL(fileURLWithPath: NSTemporaryDirectory() + newFileName)

                // Remove existing temp file if it exists
                try? FileManager.default.removeItem(at: tmpUrl)

                let success = self.writeModifiedImage(
                    sourceURL: imageURL,
                    destinationURL: tmpUrl,
                    newProperties: newProperties
                )

                if success {
                    continuation.resume(returning: .success(tmpUrl))
                } else {
                    continuation.resume(returning: .failure(.imageSave(.editionFailed)))
                }
            }
        }
    }

    private nonisolated func writeModifiedImage(
        sourceURL: URL,
        destinationURL: URL,
        newProperties: [String: Any]
    ) -> Bool {
        // Copy pixel data as-is (no decode/re-encode) and only replace metadata.
        // This avoids recompression loss on JPEG/HEIC.
        guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
              let sourceType = CGImageSourceGetType(source)
        else {
            print("[MetaX] writeModifiedImage: CGImageSource creation or type detection failed")
            return false
        }

        // For editAssetMetadata, Photos dictates the format via renderedContentURL's extension
        // (always .JPG regardless of source). Derive encoding type from destination extension,
        // falling back to source type if unknown.
        let destExtension = destinationURL.pathExtension.lowercased()
        let encodingType: CFString
        let tempExtension: String
        if !destExtension.isEmpty, let destUTType = UTType(filenameExtension: destExtension) {
            encodingType = destUTType.identifier as CFString
            tempExtension = destExtension
        } else {
            encodingType = sourceType
            tempExtension = UTType(sourceType as String)?.preferredFilenameExtension ?? "jpg"
        }

        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(tempExtension)

        guard let destination = CGImageDestinationCreateWithURL(tempURL as CFURL, encodingType, 1, nil) else {
            print("[MetaX] writeModifiedImage: CGImageDestinationCreateWithURL failed for type \(encodingType)")
            return false
        }

        // When source and destination formats match, copy pixel data as-is (lossless).
        // When formats differ (e.g. HEIC source → JPG required by Photos' renderedContentURL),
        // fall back to pixel decode — format conversion requires it.
        let sourceFormatStr = CGImageSourceGetType(source) as String? ?? ""
        let destFormatStr = encodingType as String
        if sourceFormatStr == destFormatStr {
            // Same format: copy pixel data as-is, only replace metadata (lossless).
            CGImageDestinationAddImageFromSource(destination, source, 0, newProperties as CFDictionary)
        } else {
            // Cross-format (e.g. HEIC → JPEG): must decode pixels.
            // CIImage handles wide color, HDR, and HEIC correctly; baking orientation
            // into pixels and setting orientation=1 is required for Photos to accept the output.
            guard let ciImage = CIImage(contentsOf: sourceURL, options: [.applyOrientationProperty: true]),
                  let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent)
            else {
                print(
                    "[MetaX] writeModifiedImage: CIImage decode failed for cross-format \(sourceFormatStr) → \(destFormatStr)"
                )
                try? FileManager.default.removeItem(at: tempURL)
                return false
            }
            var finalProps = newProperties
            finalProps[kCGImagePropertyOrientation as String] = 1
            CGImageDestinationAddImage(destination, cgImage, finalProps as CFDictionary)
        }

        guard CGImageDestinationFinalize(destination) else {
            print("[MetaX] writeModifiedImage: CGImageDestinationFinalize failed")
            try? FileManager.default.removeItem(at: tempURL)
            return false
        }

        do {
            try FileManager.default.createDirectory(
                at: destinationURL.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: nil
            )
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.moveItem(at: tempURL, to: destinationURL)
            return true
        } catch {
            print("[MetaX] writeModifiedImage: Failed to move rendered content: \(error)")
            try? FileManager.default.removeItem(at: tempURL)
            return false
        }
    }

    private nonisolated func createAssetInMetaXAlbum(from tempURL: URL) async -> Result<PHAsset, MetaXError> {
        var localId = ""

        do {
            try await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: tempURL)
                localId = request?.placeholderForCreatedAsset?.localIdentifier ?? ""

                let fetchOptions = PHFetchOptions()
                fetchOptions.predicate = NSPredicate(format: "title = %@", "MetaX")
                let collection = PHAssetCollection.fetchAssetCollections(
                    with: .album,
                    subtype: .any,
                    options: fetchOptions
                )

                if let album = collection.firstObject,
                   let placeholder = request?.placeholderForCreatedAsset {
                    let albumChangeRequest = PHAssetCollectionChangeRequest(for: album)
                    albumChangeRequest?.addAssets([placeholder] as NSArray)
                }
            }

            let results = PHAsset.fetchAssets(withLocalIdentifiers: [localId], options: nil)
            guard let asset = results.firstObject else {
                return .failure(.imageSave(.creationFailed))
            }

            return .success(asset)
        } catch {
            return .failure(.imageSave(.creationFailed))
        }
    }
}

extension Result {
    fileprivate var error: Failure? {
        if case let .failure(error) = self { return error }
        return nil
    }
}
