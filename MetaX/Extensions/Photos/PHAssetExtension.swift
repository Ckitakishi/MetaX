//
//  PHAssetExtension.swift
//  MetaX
//
//  Created by Chen Yuhan on 2026/02/18.
//  Copyright © 2026 Chen Yuhan. All rights reserved.
//

@preconcurrency import Photos

extension PHAsset {
    /// Request content editing input as an async throwing method.
    /// Handles iCloud downloading (waits for the final result) and ensures safe single resume using OnceGuard.
    func fetchContentEditingInput(with options: PHContentEditingInputRequestOptions) async throws
        -> PHContentEditingInput {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<PHContentEditingInput, Error>) in
            let onceGuard = OnceGuard(continuation)

            self.requestContentEditingInput(with: options) { input, info in
                // If the asset is in iCloud and downloading, wait for the final result.
                // This callback might be triggered multiple times by Photos framework.
                if let inCloud = info[PHContentEditingInputResultIsInCloudKey] as? Bool, inCloud, input == nil {
                    return
                }

                if let error = info[PHContentEditingInputErrorKey] as? Error {
                    onceGuard.resume(throwing: error)
                } else if let input = input {
                    onceGuard.resume(returning: input)
                } else {
                    // Fallback for unexpected cases where both input and error are nil
                    onceGuard.resume(throwing: MetaXError.metadata(.readFailed))
                }
            }
        }
    }
}
