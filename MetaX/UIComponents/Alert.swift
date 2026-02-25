//
//  Alert.swift
//  MetaX
//
//  Created by Yuhan Chen on 2026/02/15.
//

import UIKit

@MainActor
final class Alert {
    private init() {}

    /// Presents a confirmation dialog with customizable button titles.
    /// Returns `true` if the user chose the confirm action, `false` otherwise.
    static func confirm(
        title: String,
        message: String,
        confirmTitle: String,
        cancelTitle: String,
        on presenter: UIViewController
    ) async -> Bool {
        await withCheckedContinuation { continuation in
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: cancelTitle, style: .cancel) { _ in
                continuation.resume(returning: false)
            })
            alert.addAction(UIAlertAction(title: confirmTitle, style: .default) { _ in
                continuation.resume(returning: true)
            })
            presenter.present(alert, animated: true)
        }
    }

    /// Presents an informational dialog with a single dismiss button.
    static func show(title: String, message: String, on presenter: UIViewController) async {
        await withCheckedContinuation { continuation in
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: String(localized: .alertConfirm), style: .default) { _ in
                continuation.resume()
            })
            presenter.present(alert, animated: true)
        }
    }

    /// Presents a confirmation dialog with "Continue" and "Cancel" buttons.
    /// Returns `true` if the user chose "Continue", `false` otherwise.
    static func confirm(title: String, message: String, on presenter: UIViewController) async -> Bool {
        await confirm(
            title: title,
            message: message,
            confirmTitle: String(localized: .alertContinue),
            cancelTitle: String(localized: .alertCancel),
            on: presenter
        )
    }
}
