//
//  KeyboardObserver.swift
//  MetaX
//
//  Created by Yuhan Chen on 2026/02/09.
//

import UIKit

final class KeyboardObserver {
    private weak var scrollView: UIScrollView?
    private var observers: [NSObjectProtocol] = []

    init(scrollView: UIScrollView) {
        self.scrollView = scrollView
    }

    deinit {
        stopObserving()
    }

    func startObserving() {
        // Guard against double registration.
        stopObserving()

        let showObserver = NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleKeyboard(notification: notification, isShowing: true)
        }

        let hideObserver = NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleKeyboard(notification: notification, isShowing: false)
        }

        observers = [showObserver, hideObserver]
    }

    func stopObserving() {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
    }

    private func handleKeyboard(notification: Notification, isShowing: Bool) {
        guard let scrollView = scrollView else { return }

        if isShowing {
            guard let userInfo = notification.userInfo,
                  let keyboardFrame = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue else { return }

            let contentInsets = UIEdgeInsets(top: 0, left: 0, bottom: keyboardFrame.height, right: 0)
            scrollView.contentInset = contentInsets
            scrollView.verticalScrollIndicatorInsets = contentInsets
        } else {
            scrollView.contentInset = .zero
            scrollView.verticalScrollIndicatorInsets = .zero
        }
    }
}
