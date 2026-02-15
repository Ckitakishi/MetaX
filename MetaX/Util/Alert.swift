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

    /// Presents a confirmation dialog with "Continue" and "Cancel" buttons.
    /// - Parameters:
    ///   - title: The title of the alert.
    ///   - message: The message of the alert.
    ///   - presenter: The view controller to present the alert on.
    /// - Returns: `true` if the user chose "Continue", `false` if "Cancel" or dismissed.
    static func confirm(title: String, message: String, on presenter: UIViewController) async -> Bool {
        await withCheckedContinuation { continuation in
            let alert = UIAlertController(
                title: title,
                message: message,
                preferredStyle: .alert
            )

            let continueAction = UIAlertAction(title: String(localized: .alertContinue), style: .default) { _ in
                continuation.resume(returning: true)
            }

            let cancelAction = UIAlertAction(title: String(localized: .alertCancel), style: .cancel) { _ in
                continuation.resume(returning: false)
            }

            alert.addAction(continueAction)
            alert.addAction(cancelAction)

            presenter.present(alert, animated: true)
        }
    }
}
