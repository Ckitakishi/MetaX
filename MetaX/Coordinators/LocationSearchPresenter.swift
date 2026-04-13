//
//  LocationSearchPresenter.swift
//  MetaX
//

import UIKit

/// Presents location search and awaits the user's selection.
@MainActor
final class LocationSearchPresenter {

    private let historyService: LocationHistoryServiceProtocol
    private let searchService: LocationSearchServiceProtocol

    init(
        historyService: LocationHistoryServiceProtocol,
        searchService: LocationSearchServiceProtocol
    ) {
        self.historyService = historyService
        self.searchService = searchService
    }

    /// Presents a location search sheet on the given presenter.
    /// Returns the selected location model, or nil if the user cancelled.
    func pickLocation(on presenter: UIViewController) async -> LocationModel? {
        await withCheckedContinuation { continuation in
            let onceGuard = OnceGuard(continuation)
            let viewModel = LocationSearchViewModel(
                historyService: historyService,
                searchService: searchService
            )
            let vc = LocationSearchViewController(viewModel: viewModel)
            let nav = UINavigationController(rootViewController: vc)
            vc.onSelect = { model in
                onceGuard.resume(returning: model)
            }
            vc.onCancel = {
                onceGuard.resume(returning: nil)
            }
            presenter.present(nav, animated: true)
        }
    }
}
