//
//  PHAssetExtension.swift
//  MetaX
//
//  Created by Chen Yuhan on 2026/02/18.
//  Copyright © 2026 Chen Yuhan. All rights reserved.
//

import Photos
import UniformTypeIdentifiers

/// A thread-safe wrapper to transport non-Sendable PHContentEditingInput across isolation boundaries.
struct PHContentEditingInputSendableBox: @unchecked Sendable {
    let input: PHContentEditingInput
}

extension PHAsset {

    // MARK: - Properties

    /// Indicates whether the asset is a RAW image.
    var isRAW: Bool {
        // Use KVC for uniformTypeIdentifier to avoid SDK version mismatch errors.
        if let uti = value(forKey: "uniformTypeIdentifier") as? String,
           let type = UTType(uti),
           type.conforms(to: .rawImage) {
            return true
        }

        // Fallback: check common RAW filename extensions.
        let resources = PHAssetResource.assetResources(for: self)
        if let filename = resources.first?.originalFilename.lowercased() {
            let rawExtensions: Set<String> = ["arw", "cr2", "cr3", "nef", "dng", "orf", "raf", "rw2"]
            if let ext = filename.split(separator: ".").last, rawExtensions.contains(String(ext)) {
                return true
            }
        }
        return false
    }

    /// Indicates whether the asset is a Live Photo.
    var isLivePhoto: Bool {
        mediaSubtypes.contains(.photoLive)
    }

    // MARK: - Async Operations

    /// Requests content editing input asynchronously.
    func fetchContentEditingInput(with options: PHContentEditingInputRequestOptions) async throws
        -> PHContentEditingInput {
        let box: PHContentEditingInputSendableBox = try await withCheckedThrowingContinuation { continuation in
            let onceGuard = OnceGuard(continuation)

            requestContentEditingInput(with: options) { input, info in
                if let inCloud = info[PHContentEditingInputResultIsInCloudKey] as? Bool, inCloud, input == nil {
                    // Wait for iCloud download to complete or retry.
                    return
                }

                if let error = info[PHContentEditingInputErrorKey] as? Error {
                    onceGuard.resume(throwing: error)
                } else if let input {
                    onceGuard.resume(returning: PHContentEditingInputSendableBox(input: input))
                } else {
                    onceGuard.resume(throwing: MetaXError.metadata(.readFailed))
                }
            }
        }
        return box.input
    }
}
