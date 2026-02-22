//
//  ImageSaveService.swift
//  MetaX
//
//  Created by Chen Yuhan on 2026/02/03.
//  Copyright © 2026 Chen Yuhan. All rights reserved.
//

import CoreImage
import Photos
import UniformTypeIdentifiers

/// Protocol defining image save operations
protocol ImageSaveServiceProtocol: Sendable {
    /// Create a new asset with modified metadata
    func saveImageAsNewAsset(
        asset: PHAsset,
        newProperties: [String: Any]
    ) async -> Result<PHAsset, MetaXError>

    /// Edit existing asset metadata using non-destructive editing
    func editAssetMetadata(
        asset: PHAsset,
        newProperties: [String: Any]
    ) async -> Result<PHAsset, MetaXError>

    /// Apply a comprehensive metadata update intent (both file and DB properties)
    func applyMetadataIntent(
        _ intent: MetadataUpdateIntent,
        to asset: PHAsset,
        mode: SaveWorkflowMode
    ) async -> Result<PHAsset, MetaXError>
}

/// Service for saving images with modified metadata
final class ImageSaveService: ImageSaveServiceProtocol {

    // MARK: - Dependencies

    private let photoLibraryService: PhotoLibraryServiceProtocol
    private let ciContext: CIContext = {
        if let device = MTLCreateSystemDefaultDevice() {
            return CIContext(mtlDevice: device, options: [.useSoftwareRenderer: false])
        }
        return CIContext(options: [.useSoftwareRenderer: false])
    }()

    // [String: Any] is not Sendable. Wrap it at the @MainActor boundary before passing to
    // nonisolated methods. Safe because the value is only read after transfer, never mutated.
    private struct MetadataBox: @unchecked Sendable {
        let value: [String: Any]
    }

    // MARK: - Initialization

    init(photoLibraryService: PhotoLibraryServiceProtocol) {
        self.photoLibraryService = photoLibraryService
    }

    // MARK: - Public Methods

    func saveImageAsNewAsset(
        asset: PHAsset,
        newProperties: [String: Any]
    ) async -> Result<PHAsset, MetaXError> {
        // 1. Generate new image data to temp file.
        let box = MetadataBox(value: newProperties)
        let tempURLResult = await generateModifiedImageFile(for: asset, newProperties: box)
        guard case let .success(tempURL) = tempURLResult else {
            return .failure(tempURLResult.error ?? .imageSave(.editionFailed))
        }

        // 2. Ensure MetaX album exists
        let albumResult = await photoLibraryService.createAlbumIfNeeded(title: "MetaX")
        guard case .success = albumResult else {
            try? FileManager.default.removeItem(at: tempURL)
            return .failure(.imageSave(.albumCreationFailed))
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
        let box = MetadataBox(value: newProperties)
        if asset.mediaSubtypes.contains(.photoLive) {
            return await editLivePhotoMetadata(asset: asset, newProperties: box)
        }
        return await editStillPhotoMetadata(asset: asset, newProperties: box)
    }

    func applyMetadataIntent(
        _ intent: MetadataUpdateIntent,
        to asset: PHAsset,
        mode: SaveWorkflowMode
    ) async -> Result<PHAsset, MetaXError> {
        let result: Result<PHAsset, MetaXError>
        let originalToDelete: PHAsset?

        switch mode {
        case .updateOriginal:
            result = await editAssetMetadata(asset: asset, newProperties: intent.fileProperties)
            originalToDelete = nil
        case let .saveAsCopy(deleteOriginal):
            result = await saveImageAsNewAsset(asset: asset, newProperties: intent.fileProperties)
            originalToDelete = deleteOriginal ? asset : nil
        }

        switch result {
        case let .success(newAsset):
            // 2. Sync database properties (Date and Location) only if changed
            let dateChanged: Bool = {
                guard let newDate = intent.dbDate else { return false }
                guard let current = newAsset.creationDate else { return true }
                return abs(newDate.timeIntervalSince(current)) > 1
            }()

            let locationChanged: Bool = {
                if let newLoc = intent.dbLocation, let curLoc = newAsset.location {
                    return abs(newLoc.coordinate.latitude - curLoc.coordinate.latitude) > 0.00001
                        || abs(newLoc.coordinate.longitude - curLoc.coordinate.longitude) > 0.00001
                }
                // Handle deletion semantic: intentional nil vs existing location
                return (intent.dbLocation == nil) != (newAsset.location == nil)
            }()

            if dateChanged || locationChanged {
                _ = await photoLibraryService.updateAssetProperties(
                    newAsset,
                    date: dateChanged ? intent.dbDate : nil,
                    location: locationChanged ? intent.dbLocation : newAsset.location
                )
            }

            // 3. Delete original if requested
            if let oldAsset = originalToDelete {
                _ = await photoLibraryService.deleteAsset(oldAsset)
            }

            return .success(newAsset)

        case let .failure(error):
            return .failure(error)
        }
    }

    private nonisolated func editStillPhotoMetadata(
        asset: PHAsset,
        newProperties: MetadataBox
    ) async -> Result<PHAsset, MetaXError> {
        do {
            let options = PHContentEditingInputRequestOptions()
            options.isNetworkAccessAllowed = true

            let input = try await asset.fetchContentEditingInput(with: options)
            guard let imageURL = input.fullSizeImageURL else {
                return .failure(.imageSave(.editionFailed))
            }

            let output = PHContentEditingOutput(contentEditingInput: input)

            guard writeModifiedImage(
                sourceURL: imageURL,
                destinationURL: output.renderedContentURL,
                newProperties: newProperties.value
            ) else {
                return .failure(.imageSave(.editionFailed))
            }

            output.adjustmentData = Self.makeAdjustmentData()

            return await withCheckedContinuation { (continuation: CheckedContinuation<
                Result<PHAsset, MetaXError>,
                Never
            >) in
                let onceGuard = OnceGuard(continuation)
                PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest(for: asset).contentEditingOutput = output
                } completionHandler: { success, _ in
                    if !success {
                        onceGuard.resume(returning: .failure(.imageSave(.editionFailed)))
                    } else {
                        // Return the original pre-change asset object so that
                        // PHPhotoLibraryChangeObserver.changeDetails(for:) can locate it
                        // and fire assetContentChanged = true to trigger a metadata reload.
                        // (changeDetails requires the object to have been fetched before the change.)
                        // The observer's objectAfterChanges supplies the fresh post-change object.
                        onceGuard.resume(returning: .success(asset))
                    }
                }
            }
        } catch {
            return .failure(.imageSave(.editionFailed))
        }
    }

    private nonisolated func editLivePhotoMetadata(
        asset: PHAsset,
        newProperties: MetadataBox
    ) async -> Result<PHAsset, MetaXError> {
        do {
            let options = PHContentEditingInputRequestOptions()
            options.isNetworkAccessAllowed = true

            let input = try await asset.fetchContentEditingInput(with: options)
            guard let context = PHLivePhotoEditingContext(livePhotoEditingInput: input) else {
                return .failure(.imageSave(.editionFailed))
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
                for (key, value) in newProperties.value { merged[key] = value }
                return image.settingProperties(merged as [AnyHashable: Any])
            }

            return await withCheckedContinuation { (continuation: CheckedContinuation<
                Result<PHAsset, MetaXError>,
                Never
            >) in
                let onceGuard = OnceGuard(continuation)
                context.saveLivePhoto(to: output) { success, _ in
                    guard success else {
                        onceGuard.resume(returning: .failure(.imageSave(.editionFailed)))
                        return
                    }

                    output.adjustmentData = Self.makeAdjustmentData()

                    PHPhotoLibrary.shared().performChanges {
                        PHAssetChangeRequest(for: asset).contentEditingOutput = output
                    } completionHandler: { success, _ in
                        onceGuard.resume(returning: success ? .success(asset) : .failure(.imageSave(.editionFailed)))
                    }
                }
            }
        } catch {
            return .failure(.imageSave(.editionFailed))
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

    private nonisolated func generateModifiedImageFile(
        for asset: PHAsset,
        newProperties: MetadataBox
    ) async -> Result<URL, MetaXError> {
        do {
            let options = PHContentEditingInputRequestOptions()
            options.isNetworkAccessAllowed = true

            let input = try await asset.fetchContentEditingInput(with: options)
            guard let imageURL = input.fullSizeImageURL else {
                return .failure(.imageSave(.editionFailed))
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

            let success = writeModifiedImage(
                sourceURL: imageURL,
                destinationURL: tmpUrl,
                newProperties: newProperties.value
            )
            return success ? .success(tmpUrl) : .failure(.imageSave(.editionFailed))
        } catch {
            return .failure(.imageSave(.editionFailed))
        }
    }

    private nonisolated func writeModifiedImage(
        sourceURL: URL,
        destinationURL: URL,
        newProperties: [String: Any]
    ) -> Bool {
        guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
              let sourceType = CGImageSourceGetType(source)
        else { return false }

        // Photos dictates the output format via renderedContentURL's extension (.JPG for all assets).
        // Derive the encoding type from the destination extension, falling back to the source type.
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
            return false
        }

        let sourceFormatStr = CGImageSourceGetType(source) as String? ?? ""
        let destFormatStr = encodingType as String
        let sourceProps = (CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any]) ?? [:]
        let isJPEG = UTType(sourceFormatStr)?.conforms(to: .jpeg) == true

        // Lossless path (AddImageFromSource) is preferred but has two known ImageIO limitations:
        // 1. Cannot create a TIFF/IFD0 block from scratch — pixel re-encode required.
        // 2. Cannot reliably overwrite existing Artist/Copyright values in a JPEG IFD0.
        let sourceHasTIFF = sourceProps[kCGImagePropertyTIFFDictionary as String] != nil
        let needsTIFFWrite = newProperties[kCGImagePropertyTIFFDictionary as String] != nil
        let mustInitTIFF = needsTIFFWrite && !sourceHasTIFF
        let mustRewriteTIFF = isJPEG && isRewritingExistingTIFFText(in: sourceProps, with: newProperties)
        let canUseLossless = sourceFormatStr == destFormatStr && !mustInitTIFF && !mustRewriteTIFF

        if canUseLossless {
            // Lossless: copy pixels verbatim, only patch metadata.
            let finalProps = mergedProperties(base: sourceProps, overrides: newProperties, removeJFIF: isJPEG)
            CGImageDestinationAddImageFromSource(destination, source, 0, finalProps as CFDictionary)
        } else {
            // Lossy: pixel decode + re-encode at 0.95 quality. Required for format conversion,
            // missing IFD0 creation, or overwriting existing Artist/Copyright (ImageIO workaround).
            guard let ciImage = CIImage(contentsOf: sourceURL, options: [.applyOrientationProperty: true]),
                  let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent)
            else {
                try? FileManager.default.removeItem(at: tempURL)
                return false
            }
            let merged = mergedProperties(base: sourceProps, overrides: newProperties, removeJFIF: isJPEG)
            // For lossy encoding, we must strip NSNull values as they are only used as
            // removal markers for the lossless (AddImageFromSource) path.
            var finalProps = stripNulls(from: merged)

            // CIImage bakes orientation into pixels; reset the tag so Photos reads it correctly.
            finalProps[kCGImagePropertyOrientation as String] = 1
            finalProps[kCGImageDestinationLossyCompressionQuality as String] = 0.95
            CGImageDestinationAddImage(destination, cgImage, finalProps as CFDictionary)
        }

        guard CGImageDestinationFinalize(destination) else {
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
            try? FileManager.default.removeItem(at: tempURL)
            return false
        }
    }

    /// Recursively removes NSNull values from a dictionary.
    private nonisolated func stripNulls(from dict: [String: Any]) -> [String: Any] {
        var result = [String: Any]()
        for (key, value) in dict {
            if value is NSNull { continue }
            if let subDict = value as? [String: Any] {
                let strippedSub = stripNulls(from: subDict)
                if !strippedSub.isEmpty {
                    result[key] = strippedSub
                }
            } else {
                result[key] = value
            }
        }
        return result
    }

    /// Deep-merges `overrides` into `base`, combining sub-dictionaries key-by-key.
    /// When `removeJFIF` is true, sets the JFIF key to `kCFNull` so ImageIO removes the APP0 block,
    /// preventing APP0/APP1 conflicts without pixel re-encoding.
    private nonisolated func mergedProperties(
        base: [String: Any],
        overrides: [String: Any],
        removeJFIF: Bool
    ) -> [String: Any] {
        var result = base
        for (key, value) in overrides {
            if var existing = result[key] as? [String: Any], let sub = value as? [String: Any] {
                for (subKey, subValue) in sub { existing[subKey] = subValue }
                result[key] = existing
            } else {
                result[key] = value
            }
        }
        if removeJFIF {
            result[kCGImagePropertyJFIFDictionary as String] = kCFNull
        }
        return result
    }

    /// Returns true if `newProperties` changes an already-present Artist or Copyright value in `sourceProps`.
    /// `CGImageDestinationAddImageFromSource` cannot reliably overwrite existing IFD0 string tags in JPEG,
    /// so this signals that a pixel re-encode is needed.
    private nonisolated func isRewritingExistingTIFFText(
        in sourceProps: [String: Any],
        with newProperties: [String: Any]
    ) -> Bool {
        guard let newTIFF = newProperties[kCGImagePropertyTIFFDictionary as String] as? [String: Any],
              let sourceTIFF = sourceProps[kCGImagePropertyTIFFDictionary as String] as? [String: Any]
        else { return false }

        let keys = [kCGImagePropertyTIFFArtist, kCGImagePropertyTIFFCopyright] as [CFString]
        return keys.contains { key in
            let k = key as String
            let newValue = newTIFF[k]
            let oldValue = sourceTIFF[k]

            if newValue is NSNull {
                return oldValue != nil
            }

            guard let newStr = newValue as? String,
                  let oldStr = oldValue as? String else { return false }
            return newStr != oldStr
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
