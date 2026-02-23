//
//  KeyboardObserver.swift
//  MetaX
//
//  Created by Yuhan Chen on 2026/02/09.
//

import os
import UIKit

/// An observer that adjusts a scroll view's content insets in response to keyboard frame changes.
@MainActor
final class KeyboardObserver {

    // MARK: - Properties

    private weak var scrollView: UIScrollView?
    private let tasks = OSAllocatedUnfairLock(initialState: [Task<Void, Never>]())

    // MARK: - Initialization

    init(scrollView: UIScrollView) {
        self.scrollView = scrollView
    }

    deinit {
        tasks.withLock { $0.forEach { $0.cancel() } }
    }

    // MARK: - Observation

    func startObserving() {
        stopObserving()

        let task = Task { [weak self] in
            for await notification in NotificationCenter.default
                .notifications(named: UIResponder.keyboardWillChangeFrameNotification) {
                self?.handleKeyboard(notification: notification)
            }
        }
        tasks.withLock { $0.append(task) }
    }

    func stopObserving() {
        tasks.withLock {
            $0.forEach { $0.cancel() }
            $0.removeAll()
        }
    }

    // MARK: - Private Methods

    private func handleKeyboard(notification: Notification) {
        guard let scrollView, let userInfo = notification.userInfo else { return }

        let keyboardFrame = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue ?? .zero
        let windowHeight = scrollView.window?.bounds.height ?? UIScreen.main.bounds.height
        let isShowing = keyboardFrame.minY < windowHeight

        let bottomInset: CGFloat
        if isShowing {
            let superview = scrollView.superview ?? scrollView
            let kbFrameInSuperview = superview.convert(keyboardFrame, from: nil)
            bottomInset = max(0, scrollView.frame.maxY - kbFrameInSuperview.minY)
        } else {
            bottomInset = 0
        }

        let duration = (userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue ?? 0.25
        let curveRaw = (userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber)?.uintValue ?? 7
        let options = UIView.AnimationOptions(rawValue: curveRaw << 16)

        var targetOffset = scrollView.contentOffset
        if isShowing, let firstResponder = scrollView.findFirstResponder() {
            let fieldBottomInWindow = firstResponder.convert(
                CGPoint(x: 0, y: firstResponder.bounds.maxY), to: nil
            ).y
            let desiredBottomInWindow = keyboardFrame.minY - 16
            let delta = fieldBottomInWindow - desiredBottomInWindow
            if delta > 0 {
                targetOffset.y += delta
            }
        }

        UIView.animate(withDuration: duration, delay: 0, options: options) {
            scrollView.contentInset.bottom = bottomInset
            scrollView.verticalScrollIndicatorInsets.bottom = bottomInset
            if isShowing {
                scrollView.contentOffset = targetOffset
            }
        }
    }
}

// MARK: - Helper Extension

extension UIView {
    fileprivate func findFirstResponder() -> UIView? {
        if isFirstResponder { return self }
        for subview in subviews {
            if let responder = subview.findFirstResponder() { return responder }
        }
        return nil
    }
}
