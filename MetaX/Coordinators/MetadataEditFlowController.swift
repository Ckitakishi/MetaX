//
//  MetadataEditFlowController.swift
//  MetaX
//

import CoreLocation
import UIKit

/// Orchestrates the single-photo metadata editing flow:
/// editor presentation → save mode picker → apply → dismiss.
@MainActor
final class MetadataEditFlowController {

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

    // MARK: - Flow

    func startEditFlow(for metadata: Metadata, from source: DetailInfoViewController) async {
        let viewModel = MetadataEditViewModel(metadata: metadata)
        let vc = MetadataEditViewController(metadata: metadata, viewModel: viewModel)
        let nav = UINavigationController(rootViewController: vc)

        if UIDevice.current.userInterfaceIdiom == .pad {
            nav.modalPresentationStyle = .fullScreen
        }

        vc.onRequestLocationSearch = { [weak self, weak vc] in
            guard let self, let vc else { return }
            Task {
                guard let model = await locationSearchPresenter.pickLocation(on: vc) else { return }
                vc.updateLocation(from: model)
            }
        }

        source.present(nav, animated: true) {
            nav.presentationController?.delegate = vc
        }

        while true {
            guard let fields = await awaitEditorResult(on: vc, source: source) else { return }
            guard let mode = await saveModePicker.pick(on: nav) else { continue }

            let success = await source.applyMetadataFields(fields, saveMode: mode) { warning in
                await Alert.confirm(title: warning.title, message: warning.message, on: nav)
            }

            if success {
                source.dismiss(animated: true)
                return
            }
        }
    }

    // MARK: - Private

    private func awaitEditorResult(
        on vc: MetadataEditViewController,
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
