//
//  DetailInfoViewModel.swift
//  MetaX
//
//  Created by Chen Yuhan on 2026/02/03.
//  Copyright © 2026 Chen Yuhan. All rights reserved.
//

import CoreLocation
import Observation
import Photos
import UIKit

/// Represents the type of content shown in the hero header.
enum HeroContent {
    case photo(UIImage)
    case livePhoto(PHLivePhoto)
}

/// Represents a warning message for destructive operations.
struct SaveWarning {
    let title: String
    let message: String
}

/// ViewModel for DetailInfoViewController.
@Observable @MainActor
final class DetailInfoViewModel: NSObject {

    // MARK: - Nested Types

    /// Exhaustive states of the detail session.
    enum SessionState {
        case loading(progress: Double)
        case ready(Metadata)
        case saving(Metadata)
        case deleting
        case deleted
        case failure(MetaXError)

        var metadata: Metadata? {
            switch self {
            case let .ready(meta), let .saving(meta): return meta
            default: return nil
            }
        }

        var isSaving: Bool {
            switch self {
            case .saving, .deleting: return true
            default: return false
            }
        }

        var isLoading: Bool {
            if case .loading = self { return true }
            return false
        }

        var error: MetaXError? {
            if case let .failure(error) = self { return error }
            return nil
        }

        static func == (lhs: SessionState, rhs: SessionState) -> Bool {
            switch (lhs, rhs) {
            case (.loading, .loading): return true
            case (.deleting, .deleting): return true
            case (.deleted, .deleted): return true
            case (.ready, .ready): return true
            case (.saving, .saving): return true
            case (.failure, .failure): return true
            default: return false
            }
        }
    }

    /// Internal actions that trigger state transitions.
    private enum Action {
        case prepareLoad
        case updateLoadingProgress(Double)
        case loadSuccess(Metadata)
        case loadFailure(MetaXError)
        case actionFailure(MetaXError)
        case prepareSave(Metadata)
        case markAsDeleted
        case dismissError
    }

    struct RowModel: Identifiable {
        let id: String
        let type: RowType
        let model: DetailCellModel

        enum RowType {
            case standard
            case location(CLLocation)
        }
    }

    struct SectionModel: Sendable {
        let section: MetadataSection
        var rows: [RowModel]
    }

    struct UIModel {
        var heroContent: HeroContent?
        var currentLocation: CLLocation?
        var sections: [SectionModel] = []
    }

    // MARK: - Properties

    private(set) var state: SessionState = .loading(progress: 0)
    private(set) var actionError: MetaXError?
    private(set) var ui = UIModel()
    private(set) var hasMetaXEdit: Bool = false

    var metadata: Metadata? { state.metadata }
    var heroContent: HeroContent? { ui.heroContent }
    var currentLocation: CLLocation? { ui.currentLocation }
    var sections: [SectionModel] { ui.sections }

    var isLoading: Bool { state.isLoading }
    var isSaving: Bool { state.isSaving }
    var isDeleted: Bool { state == .deleted }
    var error: MetaXError? { state.error ?? actionError }

    var loadingProgress: Double {
        if case let .loading(p) = state { return p }
        return 0
    }

    var isDownloadingFromICloud: Bool {
        if case let .loading(p) = state { return p > 0 && p < 1.0 }
        return false
    }

    var isLivePhoto: Bool {
        asset?.isLivePhoto ?? false
    }

    // MARK: - Reducer

    private func send(_ action: Action) {
        switch (state, action) {
        case (_, .prepareLoad):
            state = .loading(progress: 0)

        case let (.loading, .updateLoadingProgress(p)):
            state = .loading(progress: p)

        case let (_, .loadSuccess(meta)):
            updateDisplayData(from: meta)
            state = .ready(meta)

        case let (_, .loadFailure(error)):
            state = .failure(error)

        case let (.saving(meta), .actionFailure(error)):
            actionError = error
            state = .ready(meta)

        case let (_, .prepareSave(meta)):
            state = .saving(meta)

        case (_, .markAsDeleted):
            state = .deleted

        case (_, .dismissError):
            actionError = nil
            if case .failure = state {
                if let meta = metadata {
                    state = .ready(meta)
                } else {
                    state = .loading(progress: 0)
                }
            }

        default:
            break
        }
    }

    // MARK: - Dependencies

    private let metadataService: MetadataServiceProtocol
    private let imageSaveService: ImageSaveServiceProtocol
    private let photoLibraryService: PhotoLibraryServiceProtocol

    // MARK: - State

    private(set) var asset: PHAsset?
    private(set) var assetCollection: PHAssetCollection?
    private var heroLoadTask: Task<Void, Never>?
    private let geocoder = CLGeocoder()
    private var geocodingTask: Task<Void, Never>?

    // MARK: - Initialization

    init(
        metadataService: MetadataServiceProtocol,
        imageSaveService: ImageSaveServiceProtocol,
        photoLibraryService: PhotoLibraryServiceProtocol
    ) {
        self.metadataService = metadataService
        self.imageSaveService = imageSaveService
        self.photoLibraryService = photoLibraryService
    }

    // MARK: - Configuration

    func configure(with asset: PHAsset, collection: PHAssetCollection?) {
        self.asset = asset
        assetCollection = collection
    }

    func updateAsset(_ asset: PHAsset?) {
        self.asset = asset
    }

    // MARK: - Public API

    func warning(for mode: SaveWorkflowMode) -> SaveWarning? {
        guard case .saveAsCopy = mode, let asset else { return nil }

        var messages = [String]()
        var title = String(localized: .alertLivePhotoCopyTitle)

        if asset.isRAW {
            title = String(localized: .alertRawConversionTitle)
            messages.append(String(localized: .alertRawConversionMessage))
        }

        if asset.isLivePhoto {
            messages.append(String(localized: .alertLivePhotoCopyMessage))
        }

        guard !messages.isEmpty else { return nil }
        return SaveWarning(title: title, message: messages.joined(separator: "\n\n"))
    }

    func loadHeroContent(targetSize: CGSize) {
        guard let asset else { return }

        heroLoadTask?.cancel()
        heroLoadTask = Task { @MainActor in
            if isLivePhoto {
                for await (livePhoto, _) in photoLibraryService.requestLivePhotoStream(
                    for: asset,
                    targetSize: targetSize
                ) {
                    guard !Task.isCancelled else { break }
                    if let livePhoto { ui.heroContent = .livePhoto(livePhoto) }
                }
            } else {
                for await (image, _) in photoLibraryService.requestThumbnailStream(for: asset, targetSize: targetSize) {
                    guard !Task.isCancelled else { break }
                    if let image { ui.heroContent = .photo(image) }
                }
            }
        }
    }

    func loadMetadata() async {
        guard let assetId = asset?.localIdentifier else { return }

        if let freshAsset = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil).firstObject {
            asset = freshAsset
        }

        guard let asset else {
            send(.loadFailure(.photoLibrary(.assetNotFound)))
            return
        }

        guard asset.mediaType == .image else {
            send(.loadFailure(.metadata(.unsupportedMediaType)))
            return
        }

        send(.prepareLoad)

        for await event in metadataService.loadMetadataEvents(from: asset) {
            switch event {
            case let .progress(progress):
                send(.updateLoadingProgress(progress))
            case let .success(metadata):
                send(.loadSuccess(metadata))
                await refreshMetaXEditStatus()
            case let .failure(error):
                send(.loadFailure(error))
            }
        }
    }

    func revertToOriginal() async {
        guard let asset else { return }
        guard let currentMeta = metadata else {
            send(.prepareLoad)
            let result = await photoLibraryService.revertAsset(asset)
            if case .success = result { await loadMetadata() }
            else if case let .failure(e) = result { send(.loadFailure(e)) }
            return
        }

        send(.prepareSave(currentMeta))

        let result = await photoLibraryService.revertAsset(asset)
        switch result {
        case .success:
            await loadMetadata()
        case let .failure(error):
            send(.actionFailure(error))
        }
    }

    @discardableResult
    func clearAllMetadata(
        saveMode: SaveWorkflowMode,
        confirm: ((SaveWarning) async -> Bool)? = nil
    ) async -> Bool {
        guard let metadata else { return false }

        if let warning = warning(for: saveMode), let confirm {
            guard await confirm(warning) else { return false }
        }

        send(.prepareSave(metadata))

        if hasMetaXEdit, case .updateOriginal = saveMode, let asset {
            let revertResult = await photoLibraryService.revertAsset(asset)
            if case let .failure(error) = revertResult {
                send(.actionFailure(error))
                return false
            }

            if let fresh = PHAsset.fetchAssets(withLocalIdentifiers: [asset.localIdentifier], options: nil)
                .firstObject {
                self.asset = fresh
            }
        }

        let intent = metadataService.removeAllMetadata(from: metadata)
        return await performSaveOperation(intent: intent, mode: saveMode, confirm: nil)
    }

    @discardableResult
    func applyMetadataFields(
        _ fields: [MetadataField: MetadataFieldValue],
        saveMode: SaveWorkflowMode,
        confirm: ((SaveWarning) async -> Bool)? = nil
    ) async -> Bool {
        guard let metadata else { return false }
        let batch = Dictionary(uniqueKeysWithValues: fields.map { ($0.key.key, $0.value.rawValue) })
        let intent = metadataService.updateMetadata(with: batch, in: metadata)
        return await performSaveOperation(intent: intent, mode: saveMode, confirm: confirm)
    }

    func cancelRequests() {
        heroLoadTask?.cancel()
        heroLoadTask = nil
        geocodingTask?.cancel()
    }

    func clearError() {
        let wasNil = metadata == nil
        send(.dismissError)
        if wasNil { Task { await loadMetadata() } }
    }

    // MARK: - Private Methods

    @discardableResult
    private func performSaveOperation(
        intent: MetadataUpdateIntent,
        mode: SaveWorkflowMode,
        confirm: ((SaveWarning) async -> Bool)? = nil
    ) async -> Bool {
        guard let asset, let currentMeta = metadata else { return false }

        if let warning = warning(for: mode), let confirm {
            guard await confirm(warning) else { return false }
        }

        if !state.isSaving {
            send(.prepareSave(currentMeta))
        }

        let result = await imageSaveService.applyMetadataIntent(intent, to: asset, mode: mode)

        switch result {
        case let .success(newAsset):
            self.asset = newAsset
            await loadMetadata()
            return true

        case let .failure(error):
            send(.actionFailure(error))
            return false
        }
    }

    private func updateDisplayData(from metadata: Metadata) {
        ui.currentLocation = metadata.rawGPS

        ui.sections = metadata.metaProps.map { section, props in
            SectionModel(
                section: section,
                rows: props.map { propDict in
                    let cellModel = DetailCellModel(propValue: propDict)
                    let type: RowModel
                        .RowType = (cellModel.rawKey == MetadataKeys.location && ui.currentLocation != nil)
                        ? .location(ui.currentLocation!)
                        : .standard
                    return RowModel(id: cellModel.rawKey, type: type, model: cellModel)
                }
            )
        }

        if let location = ui.currentLocation {
            reverseGeocodeLocation(location)
        }
    }

    private func reverseGeocodeLocation(_ location: CLLocation) {
        geocodingTask?.cancel()
        geocoder.cancelGeocode()
        geocodingTask = Task {
            guard let placemarks = try? await geocoder.reverseGeocodeLocation(location),
                  !Task.isCancelled,
                  let placemark = placemarks.first else { return }

            let infos = [placemark.thoroughfare, placemark.locality, placemark.administrativeArea, placemark.country]
            let displayText = infos.compactMap { $0 }.joined(separator: ", ")
            if displayText.isEmpty { return }

            updateLocationTextInDataSource(displayText)
        }
    }

    private func updateLocationTextInDataSource(_ text: String) {
        for sIdx in ui.sections.indices {
            guard ui.sections[sIdx].section == .basicInfo else { continue }

            for rIdx in ui.sections[sIdx].rows.indices {
                let row = ui.sections[sIdx].rows[rIdx]
                if row.id == MetadataKeys.location {
                    let newModel = DetailCellModel(prop: row.model.prop, value: text, rawKey: row.model.rawKey)
                    ui.sections[sIdx].rows[rIdx] = RowModel(id: row.id, type: row.type, model: newModel)
                    return
                }
            }
        }
    }

    private func refreshMetaXEditStatus() async {
        guard let asset else { hasMetaXEdit = false; return }
        hasMetaXEdit = await Self.fetchMetaXEditStatus(for: asset)
    }

    private nonisolated static func fetchMetaXEditStatus(for asset: PHAsset) async -> Bool {
        let options = PHContentEditingInputRequestOptions()
        options.isNetworkAccessAllowed = false
        options.canHandleAdjustmentData = { adjustmentData in
            adjustmentData.formatIdentifier == Bundle.main.bundleIdentifier
        }

        do {
            let input = try await asset.fetchContentEditingInput(with: options)
            return input.adjustmentData?.formatIdentifier == Bundle.main.bundleIdentifier
        } catch {
            return false
        }
    }

    // MARK: - Photo Library Observer

    func registerPhotoLibraryObserver() {
        photoLibraryService.registerChangeObserver(self)
    }

    func unregisterPhotoLibraryObserver() {
        photoLibraryService.unregisterChangeObserver(self)
    }
}

// MARK: - PHPhotoLibraryChangeObserver

extension DetailInfoViewModel: PHPhotoLibraryChangeObserver {
    nonisolated func photoLibraryDidChange(_ changeInstance: PHChange) {
        Task { @MainActor in
            guard !state.isSaving else { return }
            guard let curAsset = asset, let details = changeInstance.changeDetails(for: curAsset) else { return }

            let newAsset = details.objectAfterChanges
            updateAsset(newAsset)

            if details.objectWasDeleted || asset == nil {
                send(.markAsDeleted)
                return
            }

            if details.assetContentChanged {
                await loadMetadata()
            }
        }
    }
}
