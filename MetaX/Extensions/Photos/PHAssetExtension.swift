//
//  PHAssetExtension.swift
//  MetaX
//
//  Created by Chen Yuhan on 2026/02/18.
//  Copyright © 2026 Chen Yuhan. All rights reserved.
//

import Photos
import UniformTypeIdentifiers

/// A thread-safe wrapper to transport non-Sendable PHContentEditingInput across isolation boundaries in Swift 6.
struct PHContentEditingInputSendableBox: @unchecked Sendable {
    let input: PHContentEditingInput
}

extension PHAsset {
    /// Indicates whether the asset is a RAW image.
    var isRAW: Bool {
        // Use KVC for uniformTypeIdentifier to avoid SDK version mismatch errors
        if let uti = value(forKey: "uniformTypeIdentifier") as? String,
           let type = UTType(uti),
           type.conforms(to: UTType.rawImage) {
            return true
        }

        // Fallback: check filename extension
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

    /// Request content editing input as an async throwing method.
    func fetchContentEditingInput(with options: PHContentEditingInputRequestOptions) async throws
        -> PHContentEditingInput {
        let box: PHContentEditingInputSendableBox = try await withCheckedThrowingContinuation { continuation in
            let onceGuard = OnceGuard(continuation)

            self.requestContentEditingInput(with: options) { input, info in
                if let inCloud = info[PHContentEditingInputResultIsInCloudKey] as? Bool, inCloud, input == nil {
                    return
                }

                if let error = info[PHContentEditingInputErrorKey] as? Error {
                    onceGuard.resume(throwing: error)
                } else if let input = input {
                    // Wrap the non-Sendable input in a Sendable box for safe transport
                    onceGuard.resume(returning: PHContentEditingInputSendableBox(input: input))
                } else {
                    onceGuard.resume(throwing: MetaXError.metadata(.readFailed))
                }
            }
        }
        return box.input
    }
}
