//
//  ImageSaveService.swift
//  MetaX
//
//  Created by Chen Yuhan on 2026/02/03.
//  Copyright © 2026 Chen Yuhan. All rights reserved.
//

import CoreImage
import CoreLocation
import Photos
import UniformTypeIdentifiers

// MARK: - Metadata Sync Logic

public enum MetadataSyncLogic {
    public static func shouldSyncDate(_ newDate: Date?, with currentDate: Date?) -> Bool {
        guard let newDate = newDate else { return false }
        guard let current = currentDate else { return true }
        return abs(newDate.timeIntervalSince(current)) > 1
    }

    public static func shouldSyncLocation(_ newLocation: CLLocation?, with currentLoc: CLLocation?) -> Bool {
        if let new = newLocation, let current = currentLoc {
            let latitudeDiff = abs(new.coordinate.latitude - current.coordinate.latitude)
            let longitudeDiff = abs(new.coordinate.longitude - current.coordinate.longitude)
            return latitudeDiff > 0.00001 || longitudeDiff > 0.00001
        }
        return (newLocation == nil) != (currentLoc == nil)
    }
}

// MARK: - Save Policy

struct SavePolicy {
    let sourceUTType: UTType
    let isLivePhoto: Bool
    let destinationURL: URL?

    var targetUTType: UTType {
        // 1. Respect the destination URL extension if provided (dictated by Photos or caller)
        if let ext = destinationURL?.pathExtension, let type = UTType(filenameExtension: ext) {
            return type
        }
        // 2. RAW and Live Photos are standardized to JPEG for metadata stability
        if sourceUTType.conforms(to: .rawImage) || isLivePhoto {
            return .jpeg
        }
        return sourceUTType
    }

    var targetExtension: String {
        targetUTType.preferredFilenameExtension?.uppercased() ?? "JPG"
    }

    /// Properties that are often stripped by CIImage/CGImage during re-encoding
    /// but MUST be restored to maintain file identity (e.g., Live Photo pairing).
    var identityKeys: [String] {
        [
            MetadataKeys.appleDict,
            MetadataKeys.pngDict,
            MetadataKeys.iccProfile,
            kCGImagePropertyColorModel as String,
            kCGImagePropertyProfileName as String,
        ]
    }

    func canUseLossless(intent: MetadataUpdateIntent, mustRewriteTIFF: Bool, hasNewTIFF: Bool) -> Bool {
        !intent.forceReencode && (sourceUTType == targetUTType) && !mustRewriteTIFF && !hasNewTIFF
    }
}

// MARK: - Service Protocol

protocol ImageSaveServiceProtocol: Sendable {
    func saveImageAsNewAsset(asset: PHAsset, intent: MetadataUpdateIntent) async -> Result<PHAsset, MetaXError>
    func editAssetMetadata(asset: PHAsset, intent: MetadataUpdateIntent) async -> Result<PHAsset, MetaXError>
    func applyMetadataIntent(_ intent: MetadataUpdateIntent, to asset: PHAsset, mode: SaveWorkflowMode) async
        -> Result<PHAsset, MetaXError>
}

// MARK: - Service Implementation

final class ImageSaveService: ImageSaveServiceProtocol {
    private let photoLibraryService: PhotoLibraryServiceProtocol
    private let ciContext: CIContext = {
        if let device = MTLCreateSystemDefaultDevice() {
            return CIContext(mtlDevice: device, options: [.useSoftwareRenderer: false])
        }
        return CIContext(options: [.useSoftwareRenderer: false])
    }()

    init(photoLibraryService: PhotoLibraryServiceProtocol) {
        self.photoLibraryService = photoLibraryService
    }

    // MARK: - Public API

    func saveImageAsNewAsset(asset: PHAsset, intent: MetadataUpdateIntent) async -> Result<PHAsset, MetaXError> {
        let tempURLResult = await generateModifiedImageFile(for: asset, intent: intent)
        guard case let .success(tempURL) = tempURLResult
        else { return .failure(tempURLResult.error ?? .imageSave(.editionFailed)) }

        _ = await photoLibraryService.createAlbumIfNeeded(title: "MetaX")
        let createResult = await createAssetInMetaXAlbum(from: tempURL)
        try? FileManager.default.removeItem(at: tempURL)
        return createResult
    }

    func editAssetMetadata(asset: PHAsset, intent: MetadataUpdateIntent) async -> Result<PHAsset, MetaXError> {
        do {
            let input = try await asset.fetchContentEditingInput(with: makeEditingOptions())
            guard let imageURL = input.fullSizeImageURL else { return .failure(.imageSave(.editionFailed)) }

            // For Live Photos, updating the still component while preserving the Asset ID
            // allows the system to maintain the pairing without a video re-render.
            let output = PHContentEditingOutput(contentEditingInput: input)
            guard writeModifiedImage(sourceURL: imageURL, destinationURL: output.renderedContentURL, intent: intent)
            else {
                return .failure(.imageSave(.editionFailed))
            }

            output.adjustmentData = makeAdjustmentData()

            return await withCheckedContinuation { continuation in
                PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest(for: asset).contentEditingOutput = output
                } completionHandler: { success, error in
                    if !success, let error = error { print("[MetaX] performChanges failed: \(error)") }
                    continuation.resume(returning: success ? .success(asset) : .failure(.imageSave(.editionFailed)))
                }
            }
        } catch {
            return .failure(.imageSave(.editionFailed))
        }
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
            result = await editAssetMetadata(asset: asset, intent: intent)
            originalToDelete = nil
        case let .saveAsCopy(deleteOriginal):
            result = await saveImageAsNewAsset(asset: asset, intent: intent)
            originalToDelete = deleteOriginal ? asset : nil
        }

        if case let .success(newAsset) = result {
            let dateChanged = MetadataSyncLogic.shouldSyncDate(intent.dbDate, with: newAsset.creationDate)
            let locationChanged = MetadataSyncLogic.shouldSyncLocation(intent.dbLocation, with: newAsset.location)

            if dateChanged || locationChanged {
                _ = await photoLibraryService.updateAssetProperties(
                    newAsset,
                    date: dateChanged ? intent.dbDate : nil,
                    location: locationChanged ? intent.dbLocation : newAsset.location
                )
            }
            if let assetToRemove = originalToDelete { _ = await photoLibraryService.deleteAsset(assetToRemove) }
            return .success(newAsset)
        }
        return result
    }

    // MARK: - Internal Helpers

    private func makeEditingOptions() -> PHContentEditingInputRequestOptions {
        let options = PHContentEditingInputRequestOptions()
        options.isNetworkAccessAllowed = true
        options.canHandleAdjustmentData = { $0.formatIdentifier == AppConstants.adjustmentFormatID }
        return options
    }

    private func makeAdjustmentData() -> PHAdjustmentData {
        let payload: [String: Any] = ["app": "MetaX", "edit": "metadata", "date": Date()]
        let data = try? NSKeyedArchiver.archivedData(withRootObject: payload, requiringSecureCoding: false)
        return PHAdjustmentData(
            formatIdentifier: AppConstants.adjustmentFormatID,
            formatVersion: "1.0",
            data: data ?? Data()
        )
    }

    nonisolated func generateModifiedImageFile(
        for asset: PHAsset,
        intent: MetadataUpdateIntent
    ) async -> Result<URL, MetaXError> {
        do {
            let input = try await asset.fetchContentEditingInput(with: makeEditingOptions())
            guard let imageURL = input.fullSizeImageURL else { return .failure(.imageSave(.editionFailed)) }

            let resources = PHAssetResource.assetResources(for: asset)
            let utIdentifier = resources.first?.uniformTypeIdentifier
            let policy = SavePolicy(
                sourceUTType: utIdentifier.flatMap { UTType($0) } ?? .jpeg,
                isLivePhoto: asset.isLivePhoto,
                destinationURL: nil
            )

            let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(policy.targetExtension)
            return writeModifiedImage(sourceURL: imageURL, destinationURL: tempURL, intent: intent) ? .success(
                tempURL
            ) :
                .failure(.imageSave(.editionFailed))
        } catch {
            return .failure(.imageSave(.editionFailed))
        }
    }

    nonisolated func writeModifiedImage(sourceURL: URL, destinationURL: URL, intent: MetadataUpdateIntent) -> Bool {
        guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
              let sourceUTType = (CGImageSourceGetType(source) as String?).flatMap({ UTType($0) }),
              let sourceProps = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any]
        else { return false }

        let policy = SavePolicy(
            sourceUTType: sourceUTType,
            isLivePhoto: sourceProps[MetadataKeys.appleDict] != nil,
            destinationURL: destinationURL
        )
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(policy.targetExtension)
        guard let destination = CGImageDestinationCreateWithURL(
            tempURL as CFURL,
            policy.targetUTType.identifier as CFString,
            1,
            nil
        ) else { return false }

        let mustRewriteTIFF = isRewritingExistingTIFFText(in: sourceProps, with: intent.fileProperties)
        if policy.canUseLossless(
            intent: intent,
            mustRewriteTIFF: mustRewriteTIFF,
            hasNewTIFF: isAddingNewTIFF(sourceProps, intent.fileProperties)
        ) {
            CGImageDestinationAddImageFromSource(destination, source, 0, intent.fileProperties as CFDictionary)
        } else {
            guard let ciImage = CIImage(contentsOf: sourceURL, options: [.applyOrientationProperty: true])
            else { return false }

            // Preserve wide color space (e.g. Display P3) if present
            let outputColorSpace = ciImage.colorSpace ?? CGColorSpaceCreateDeviceRGB()
            guard let cgImage = ciContext.createCGImage(
                ciImage,
                from: ciImage.extent,
                format: .RGBA8,
                colorSpace: outputColorSpace
            ) else { return false }

            var cleanProps = stripNulls(from: intent.fileProperties)
            // Remove physical attributes to let the encoder generate them from new pixels.
            let forbidden = [
                kCGImagePropertyPixelWidth, kCGImagePropertyPixelHeight,
                kCGImagePropertyDPIWidth, kCGImagePropertyDPIHeight,
                kCGImagePropertyOrientation, kCGImagePropertyJFIFDictionary,
            ] as [CFString]
            forbidden.forEach { cleanProps.removeValue(forKey: $0 as String) }
            ["PixelWidth", "PixelHeight", "Orientation"].forEach { cleanProps.removeValue(forKey: $0) }

            // Orientation is applied to pixels during CIImage load; reset tag to 1.
            cleanProps[kCGImagePropertyOrientation as String] = 1
            cleanProps[kCGImageDestinationLossyCompressionQuality as String] = 0.95

            // Restore identity keys to ensure system-level asset pairing (e.g. Live Photo)
            policy.identityKeys.forEach { if let val = sourceProps[$0] { cleanProps[$0] = val } }

            CGImageDestinationAddImage(destination, cgImage, cleanProps as CFDictionary)
        }

        guard CGImageDestinationFinalize(destination) else { return false }
        try? FileManager.default.removeItem(at: destinationURL)
        return (try? FileManager.default.moveItem(at: tempURL, to: destinationURL)) != nil
    }

    // MARK: - Utilities

    nonisolated func stripNulls(from dictionary: [String: Any]) -> [String: Any] {
        var result = [String: Any]()
        for (key, value) in dictionary {
            if value is NSNull || (value as AnyObject) === kCFNull { continue }
            if let sub = value as? [String: Any] {
                let cleaned = stripNulls(from: sub)
                if !cleaned.isEmpty { result[key] = cleaned }
            } else { result[key] = value }
        }
        return result
    }

    private nonisolated func isAddingNewTIFF(_ source: [String: Any], _ overrides: [String: Any]) -> Bool {
        overrides[kCGImagePropertyTIFFDictionary as String] != nil && source[
            kCGImagePropertyTIFFDictionary as String
        ] ==
            nil
    }

    private nonisolated func isRewritingExistingTIFFText(
        in source: [String: Any],
        with overrides: [String: Any]
    ) -> Bool {
        guard let newTIFF = overrides[kCGImagePropertyTIFFDictionary as String] as? [String: Any],
              let sourceTIFF = source[kCGImagePropertyTIFFDictionary as String] as? [String: Any] else { return false }
        let targetKeys = [
            kCGImagePropertyTIFFArtist,
            kCGImagePropertyTIFFCopyright,
            kCGImagePropertyTIFFMake,
            kCGImagePropertyTIFFModel,
            kCGImagePropertyTIFFSoftware,
            kCGImagePropertyTIFFDateTime,
        ] as [CFString]
        return targetKeys.contains { (sourceTIFF[$0 as String] as? String) != (newTIFF[$0 as String] as? String) }
    }

    private nonisolated func createAssetInMetaXAlbum(from url: URL) async -> Result<PHAsset, MetaXError> {
        var localId = ""
        do {
            try await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: url)
                localId = request?.placeholderForCreatedAsset?.localIdentifier ?? ""
                let fetchOptions = PHFetchOptions()
                fetchOptions.predicate = NSPredicate(format: "title = %@", "MetaX")
                if let album = PHAssetCollection.fetchAssetCollections(
                    with: .album,
                    subtype: .any,
                    options: fetchOptions
                ).firstObject, let placeholder = request?.placeholderForCreatedAsset {
                    PHAssetCollectionChangeRequest(for: album)?.addAssets([placeholder] as NSArray)
                }
            }
            return PHAsset.fetchAssets(withLocalIdentifiers: [localId], options: nil).firstObject
                .map { .success($0) } ?? .failure(.imageSave(.creationFailed))
        } catch { return .failure(.imageSave(.creationFailed)) }
    }
}

extension Result {
    fileprivate var error: Failure? { if case let .failure(error) = self { return error }; return nil }
}
