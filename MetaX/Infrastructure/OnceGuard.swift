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
/// If deallocated before an explicit `resume`, automatically resumes with the
/// fallback provided at init time, preventing leaked continuations.
///
/// @unchecked Sendable: all mutable state is protected by `OSAllocatedUnfairLock`.
final class OnceGuard<T: Sendable, E: Error>: @unchecked Sendable {

    private let state: OSAllocatedUnfairLock<CheckedContinuation<T, E>?>
    private let deinitBody: @Sendable (CheckedContinuation<T, E>) -> Void

    init(
        _ continuation: CheckedContinuation<T, E>,
        onDeinit: @escaping @Sendable (CheckedContinuation<T, E>) -> Void
    ) {
        state = OSAllocatedUnfairLock(initialState: continuation)
        deinitBody = onDeinit
    }

    convenience init(_ continuation: CheckedContinuation<T, E>, fallback: T) {
        self.init(continuation, onDeinit: { $0.resume(returning: fallback) })
    }

    deinit {
        state.withLock { continuation in
            if let continuation { deinitBody(continuation) }
            continuation = nil
        }
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
    convenience init(_ continuation: CheckedContinuation<T, E>) {
        self.init(continuation, fallback: ())
    }

    func resume() {
        resume(returning: ())
    }
}

extension OnceGuard where T: ExpressibleByNilLiteral {
    convenience init(_ continuation: CheckedContinuation<T, E>) {
        self.init(continuation, fallback: nil)
    }
}
