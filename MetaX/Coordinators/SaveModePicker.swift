//
//  SaveModePicker.swift
//  MetaX
//

import UIKit

/// Bridges `SaveOptionsViewController` into an async/await call.
/// Creates, presents, and awaits the user's save-mode selection.
@MainActor
final class SaveModePicker {

    func pick(
        on presenter: UIViewController,
        batchMode: Bool = false
    ) async -> SaveWorkflowMode? {
        await withCheckedContinuation { continuation in
            let onceGuard = OnceGuard(continuation)
            let vc = SaveOptionsViewController(batchMode: batchMode)
            if UIDevice.current.userInterfaceIdiom == .pad {
                vc.modalPresentationStyle = .pageSheet
            }
            vc.onSelect = { mode in
                onceGuard.resume(returning: mode)
            }
            vc.onCancel = {
                onceGuard.resume(returning: nil)
            }
            presenter.present(vc, animated: true)
        }
    }
}
