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
///
/// @unchecked Sendable: all mutable state is protected by `OSAllocatedUnfairLock`.
final class OnceGuard<T: Sendable, E: Error>: @unchecked Sendable {

    /// Stored as Optional so the continuation is freed after the first resume.
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

// MARK: - Specialization

extension OnceGuard where T == Void {
    func resume() {
        resume(returning: ())
    }
}
