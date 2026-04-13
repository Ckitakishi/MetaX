//
//  BatchEditFlowController.swift
//  MetaX
//

import Photos
import UIKit

/// Orchestrates batch metadata editing and clearing flows:
/// editor → summary → save mode → progress → dismiss.
@MainActor
final class BatchEditFlowController {

    private let container: DependencyContainer
    private let saveModePicker: SaveModePicker
    private let locationSearchPresenter: LocationSearchPresenter

    init(
        container: DependencyContainer,
        saveModePicker: SaveModePicker,
        locationSearchPresenter: LocationSearchPresenter
    ) {
        self.container = container
        self.saveModePicker = saveModePicker
        self.locationSearchPresenter = locationSearchPresenter
    }

    // MARK: - Batch Edit

    func startBatchEditFlow(assets: [PHAsset], from source: UIViewController) async {
        let editVM = BatchMetadataEditViewModel()
        let editVC = BatchMetadataEditViewController(viewModel: editVM, assetCount: assets.count)
        let nav = UINavigationController(rootViewController: editVC)

        if UIDevice.current.userInterfaceIdiom == .pad {
            nav.modalPresentationStyle = .fullScreen
        }

        editVC.onRequestLocationSearch = { [weak self, weak editVC] in
            guard let self, let editVC else { return }
            Task {
                guard let model = await locationSearchPresenter.pickLocation(on: editVC) else { return }
                editVC.updateLocation(from: model)
            }
        }

        source.present(nav, animated: true) {
            nav.presentationController?.delegate = editVC
        }

        var fields: [MetadataField: MetadataFieldValue]?
        while true {
            guard let result = await awaitBatchEditorResult(on: editVC, source: source) else { return }
            guard let mode = await saveModePicker.pick(on: nav, batchMode: true) else { continue }
            guard mode == .updateOriginal else {
                assertionFailure("Batch edit only supports updateOriginal")
                continue
            }
            fields = result
            break
        }
        guard let fields else { return }

        await presentBatchProgress(on: nav, dismissing: source, assets: assets) { batchVM in
            await batchVM.execute(assets: assets, fields: fields, mode: .updateOriginal)
        }
    }

    // MARK: - Batch Clear

    func startBatchClearFlow(assets: [PHAsset], from source: UIViewController) async {
        let confirmed = await Alert.confirm(
            title: String(localized: .viewClearAllMetadata),
            message: String(localized: .batchClearConfirmMessage(assets.count)),
            on: source
        )
        guard confirmed else { return }

        await presentBatchProgress(on: source, dismissing: source, assets: assets) { batchVM in
            await batchVM.executeClear(assets: assets)
        }
    }

    // MARK: - Private

    private func presentBatchProgress(
        on presenter: UIViewController,
        dismissing dismissTarget: UIViewController,
        assets: [PHAsset],
        operation: @escaping (BatchEditViewModel) async -> BatchEditViewModel.BatchResult
    ) async {
        let batchVM = BatchEditViewModel(
            metadataService: container.metadataService,
            imageSaveService: container.imageSaveService,
            settingsService: container.settingsService
        )
        let progressVC = BatchProgressViewController(viewModel: batchVM, totalCount: assets.count)
        progressVC.modalPresentationStyle = .overFullScreen
        progressVC.modalTransitionStyle = .crossDissolve

        let completionAcknowledged = Task { @MainActor in
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                let onceGuard = OnceGuard<Void, Never>(continuation)
                progressVC.onFinishAcknowledged = {
                    onceGuard.resume()
                }
            }
        }

        presenter.present(progressVC, animated: true)

        let batchTask = Task {
            await operation(batchVM)
        }
        progressVC.onCancel = {
            batchTask.cancel()
        }
        _ = await batchTask.value
        await completionAcknowledged.value
        if let photoGrid = dismissTarget as? PhotoGridViewController {
            photoGrid.resetBatchSelectionMode()
        }
        dismissTarget.dismiss(animated: true)
    }

    private func awaitBatchEditorResult(
        on vc: BatchMetadataEditViewController,
        source: UIViewController
    ) async -> [MetadataField: MetadataFieldValue]? {
        await withCheckedContinuation { continuation in
            let onceGuard = OnceGuard(continuation)
            vc.onSave = { fields in
                onceGuard.resume(returning: fields)
            }
            vc.onCancel = { [weak source] in
                source?.dismiss(animated: true)
                onceGuard.resume(returning: nil)
            }
        }
    }
}
