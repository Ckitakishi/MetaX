//
//  BatchEditViewModel.swift
//  MetaX
//
//  Created by Yuhan Chen on 2026/03/27.
//  Copyright © 2026 Yuhan Chen. All rights reserved.
//

import Observation
import Photos

/// Orchestrates batch metadata write or clear operations across multiple assets.
@Observable @MainActor
final class BatchEditViewModel {

    // MARK: - Types

    enum State: Sendable {
        case idle
        case processing(completed: Int, total: Int)
        case finished(BatchResult)
    }

    struct BatchResult: Sendable {
        let succeeded: Int
        let failed: Int
        let cancelled: Bool
        let errors: [(String, MetaXError)] // localIdentifier + error, capped for display
    }

    // MARK: - Properties

    private(set) var state: State = .idle

    private let metadataService: MetadataServiceProtocol
    private let imageSaveService: ImageSaveServiceProtocol
    private let settingsService: SettingsServiceProtocol

    // MARK: - Initialization

    init(
        metadataService: MetadataServiceProtocol,
        imageSaveService: ImageSaveServiceProtocol,
        settingsService: SettingsServiceProtocol
    ) {
        self.metadataService = metadataService
        self.imageSaveService = imageSaveService
        self.settingsService = settingsService
    }

    // MARK: - Batch Edit

    /// Applies the given fields to all assets. Only non-nil fields are written.
    func execute(
        assets: [PHAsset],
        fields: [MetadataField: MetadataFieldValue],
        mode: SaveWorkflowMode
    ) async -> BatchResult {
        guard mode == .updateOriginal else {
            return BatchResult(
                succeeded: 0,
                failed: assets.count,
                cancelled: false,
                errors: []
            )
        }
        let batch = Dictionary(uniqueKeysWithValues: fields.map { ($0.key.key, $0.value.rawValue) })
        return await processBatch(assets: assets) { [metadataService] metadata in
            metadataService.updateMetadata(with: batch, in: metadata)
        }
    }

    // MARK: - Batch Clear

    /// Removes all metadata from the given assets.
    func executeClear(assets: [PHAsset]) async -> BatchResult {
        await processBatch(assets: assets) { [metadataService] metadata in
            metadataService.removeAllMetadata(from: metadata)
        }
    }

    // MARK: - Private

    private func processBatch(
        assets: [PHAsset],
        buildIntent: (Metadata) -> MetadataUpdateIntent
    ) async -> BatchResult {
        let total = assets.count
        #if DEBUG
            if settingsService.debugBatchProgressMode != .off {
                return await simulateBatch(total: total, mode: settingsService.debugBatchProgressMode)
            }
        #endif

        var succeeded = 0
        var errors: [(String, MetaXError)] = []
        var cancelled = false
        state = .processing(completed: 0, total: total)

        for asset in assets {
            guard !Task.isCancelled else {
                cancelled = true
                break
            }

            do {
                let metadata = try await loadMetadata(for: asset)
                let intent = buildIntent(metadata)
                let result = await imageSaveService.applyMetadataIntent(
                    intent, to: asset, mode: .updateOriginal
                )
                switch result {
                case .success:
                    succeeded += 1
                case let .failure(error):
                    errors.append((asset.localIdentifier, error))
                }
            } catch {
                errors.append((asset.localIdentifier, error as? MetaXError ?? .metadata(.readFailed)))
            }

            await applyDebugDelayIfNeeded()
            guard !Task.isCancelled else {
                cancelled = true
                break
            }
            state = .processing(completed: succeeded + errors.count, total: total)
        }

        let result = BatchResult(
            succeeded: succeeded,
            failed: errors.count,
            cancelled: cancelled,
            errors: Array(errors.prefix(5))
        )
        state = .finished(result)
        return result
    }

    private func loadMetadata(for asset: PHAsset) async throws -> Metadata {
        for await event in metadataService.loadMetadataEvents(from: asset) {
            switch event {
            case .progress:
                continue
            case let .success(metadata):
                return metadata
            case let .failure(error):
                throw error
            }
        }
        throw MetaXError.metadata(.readFailed)
    }

    private func applyDebugDelayIfNeeded() async {
        #if DEBUG
            let delay = settingsService.debugBatchProgressDelay
            guard delay > 0 else { return }
            try? await Task.sleep(for: .seconds(delay))
        #endif
    }

    #if DEBUG
        private func simulateBatch(total: Int, mode: DebugBatchProgressMode) async -> BatchResult {
            state = .processing(completed: 0, total: total)

            var completed = 0
            let stopAfter = mode == .cancelled ? max(0, total / 2) : total

            while completed < stopAfter {
                guard !Task.isCancelled else {
                    break
                }
                await applyDebugDelayIfNeeded()
                guard !Task.isCancelled else {
                    break
                }
                completed += 1
                state = .processing(completed: completed, total: total)
            }

            if Task.isCancelled || mode == .cancelled {
                let result = BatchResult(succeeded: completed, failed: 0, cancelled: true, errors: [])
                state = .finished(result)
                return result
            }

            let result: BatchResult
            switch mode {
            case .off, .success:
                result = BatchResult(succeeded: total, failed: 0, cancelled: false, errors: [])
            case .partialFailure:
                let failed = max(1, total / 3)
                let succeeded = max(0, total - failed)
                result = BatchResult(
                    succeeded: succeeded,
                    failed: failed,
                    cancelled: false,
                    errors: debugErrors(count: failed)
                )
            case .failure:
                result = BatchResult(
                    succeeded: 0,
                    failed: total,
                    cancelled: false,
                    errors: debugErrors(count: total)
                )
            case .cancelled:
                result = BatchResult(succeeded: completed, failed: 0, cancelled: true, errors: [])
            }

            state = .finished(result)
            return result
        }

        private func debugErrors(count: Int) -> [(String, MetaXError)] {
            let sampleErrors: [MetaXError] = [
                .metadata(.readFailed),
                .metadata(.iCloudSyncRequired),
                .imageSave(.editionFailed),
                .imageSave(.creationFailed),
                .photoLibrary(.assetNotFound),
            ]

            return (0..<min(count, 5)).map { index in
                let localIdentifier = "debug-asset-\(index + 1)"
                return (localIdentifier, sampleErrors[index % sampleErrors.count])
            }
        }
    #endif
}

enum BatchEditPresentation {
    static func failureDetailsMessage(for result: BatchEditViewModel.BatchResult) -> String {
        guard !result.errors.isEmpty else {
            return String(localized: .batchErrorDetailsMessage)
        }

        return result.errors.enumerated().map { index, entry in
            let (_, error) = entry
            return "\(index + 1). \(error.localizedDescription)"
        }.joined(separator: "\n")
    }
}
