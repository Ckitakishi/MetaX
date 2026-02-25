//
//  SupportViewModel.swift
//  MetaX
//
//  Created by Yuhan Chen on 2026/02/25.
//

import Observation
import StoreKit

struct SupportAlertItem {
    let title: String
    let message: String
}

/// A display model for a single tip product, free of StoreKit types.
struct TipProduct {
    let id: String
    let price: String
}

@Observable @MainActor
final class SupportViewModel {

    // MARK: - Properties

    private(set) var tipProducts: [TipProduct] = []
    private(set) var isPurchasing = false

    /// The current alert to be displayed by the view.
    var alertItem: SupportAlertItem?

    // MARK: - Dependencies

    private let storeService: StoreServiceProtocol
    private var storeProducts: [Product] = []

    // MARK: - Initialization

    init(storeService: StoreServiceProtocol) {
        self.storeService = storeService
        loadProducts()
    }

    // MARK: - Public Methods

    func loadProducts() {
        Task {
            do {
                storeProducts = try await storeService.fetchProducts()
                tipProducts = AppConstants.allTipProductIDs.compactMap { id in
                    storeProducts.first(where: { $0.id == id }).map { TipProduct(id: id, price: $0.displayPrice) }
                }
            } catch {
                // Silently fail; cells show "---" as a placeholder until products load.
            }
        }
    }

    func purchase(id: String) {
        guard let product = storeProducts.first(where: { $0.id == id }) else { return }
        isPurchasing = true
        Task {
            defer { isPurchasing = false }
            do {
                switch try await storeService.purchase(product) {
                case .completed:
                    alertItem = SupportAlertItem(
                        title: String(localized: .supportSuccessTitle),
                        message: String(localized: .supportSuccessMessage)
                    )
                case .pending:
                    alertItem = SupportAlertItem(
                        title: String(localized: .alertConfirm),
                        message: String(localized: .supportPurchasePending)
                    )
                case .cancelled:
                    break
                }
            } catch {
                handleError(error)
            }
        }
    }

    func dismissAlert() {
        alertItem = nil
    }

    // MARK: - Private Methods

    private func handleError(_ error: Error) {
        if let skError = error as? SKError, skError.code == .paymentCancelled {
            return
        }
        alertItem = SupportAlertItem(
            title: String(localized: .alertConfirm),
            message: error.localizedDescription
        )
    }
}
