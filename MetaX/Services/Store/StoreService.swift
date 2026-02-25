//
//  StoreService.swift
//  MetaX
//
//  Created by Yuhan Chen on 2026/02/25.
//

import Foundation
import StoreKit

enum PurchaseOutcome: Sendable {
    case completed(Transaction)
    case pending
    case cancelled
}

protocol StoreServiceProtocol: Sendable {
    func fetchProducts() async throws -> [Product]
    func purchase(_ product: Product) async throws -> PurchaseOutcome
}

final class StoreService: StoreServiceProtocol {

    private let transactionListenerTask: Task<Void, Never>

    init() {
        transactionListenerTask = Task.detached {
            for await verificationResult in Transaction.updates {
                switch verificationResult {
                case let .verified(transaction):
                    await transaction.finish()
                case .unverified:
                    break
                }
            }
        }
    }

    deinit {
        transactionListenerTask.cancel()
    }

    func fetchProducts() async throws -> [Product] {
        try await Product.products(for: AppConstants.allTipProductIDs)
    }

    func purchase(_ product: Product) async throws -> PurchaseOutcome {
        let result = try await product.purchase()

        switch result {
        case let .success(verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            return .completed(transaction)
        case .pending:
            return .pending
        case .userCancelled:
            return .cancelled
        @unknown default:
            return .cancelled
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw MetaXError.store(.purchaseFailed)
        case let .verified(safe):
            return safe
        }
    }
}
