//
//  KeyboardObserver.swift
//  MetaX
//
//  Created by Yuhan Chen on 2026/02/09.
//

import UIKit

@MainActor
final class KeyboardObserver {
    private weak var scrollView: UIScrollView?

    private nonisolated(unsafe) var observers: [NSObjectProtocol] = []

    init(scrollView: UIScrollView) {
        self.scrollView = scrollView
    }

    deinit {
        // NotificationCenter.removeObserver is thread-safe.
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func startObserving() {
        // Guard against double registration.
        stopObserving()

        let showObserver = NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let keyboardFrame = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?
                .cgRectValue
            MainActor.assumeIsolated {
                self?.handleKeyboard(keyboardFrame: keyboardFrame, isShowing: true)
            }
        }

        let hideObserver = NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.handleKeyboard(keyboardFrame: nil, isShowing: false)
            }
        }

        observers = [showObserver, hideObserver]
    }

    func stopObserving() {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
    }

    private func handleKeyboard(keyboardFrame: CGRect?, isShowing: Bool) {
        guard let scrollView = scrollView else { return }

        if isShowing {
            guard let keyboardFrame = keyboardFrame else { return }
            let contentInsets = UIEdgeInsets(top: 0, left: 0, bottom: keyboardFrame.height, right: 0)
            scrollView.contentInset = contentInsets
            scrollView.verticalScrollIndicatorInsets = contentInsets
        } else {
            scrollView.contentInset = .zero
            scrollView.verticalScrollIndicatorInsets = .zero
        }
    }
}
