//
//  OnceGuard.swift
//  MetaX
//
//  Created by Chen Yuhan on 2026/02/18.
//  Copyright © 2026 Chen Yuhan. All rights reserved.
//

import Foundation
import os

/// Wraps a `CheckedContinuation` and ensures it is resumed at most once.
/// Subsequent calls to `resume` are silently ignored.
///
/// `@unchecked Sendable`: all mutable state is protected by `OSAllocatedUnfairLock`.
final class OnceGuard<T: Sendable, E: Error>: @unchecked Sendable {

    /// Stored inside the lock as Optional so the continuation is freed after first resume.
    /// nil acts as the "already resumed" sentinel, avoiding a separate Bool flag.
    private let state: OSAllocatedUnfairLock<CheckedContinuation<T, E>?>

    init(_ continuation: CheckedContinuation<T, E>) {
        state = OSAllocatedUnfairLock(initialState: continuation)
    }

    func resume(returning value: T) {
        state.withLock { continuation in
            continuation?.resume(returning: value)
            continuation = nil
        }
    }

    func resume(throwing error: E) {
        state.withLock { continuation in
            continuation?.resume(throwing: error)
            continuation = nil
        }
    }
}

extension OnceGuard where T == Void {
    func resume() {
        resume(returning: ())
    }
}
