//
//  AppCoordinator.swift
//  MetaX
//
//  Created by Yuhan Chen on 2026/02/12.
//

import UIKit

/// The central coordinator that owns all navigation and flow orchestration.
@MainActor
final class AppCoordinator: NSObject, Coordinator {

    // MARK: - Properties

    var childCoordinators: [Coordinator] = []
    var navigationController: UINavigationController = .init()

    private let splitViewController = UISplitViewController(style: .doubleColumn)
    private let container: DependencyContainer

    // MARK: - Initialization

    init(container: DependencyContainer) {
        self.container = container
        super.init()
        setupSplitView()
    }

    // MARK: - Coordinator Flow

    func rootViewController() -> UIViewController {
        splitViewController
    }

    func start() {
        let photoCoordinator = PhotoFlowCoordinator(
            navigationController: navigationController,
            splitViewController: splitViewController,
            container: container
        )
        addChild(photoCoordinator)
        photoCoordinator.start()
    }

    /// Presents the tipping alert if conditions are met, then navigates to the support page if confirmed.
    func showTippingAlertIfNeeded() async {
        guard container.tippingManager.shouldShowTippingAlert() else { return }
        container.tippingManager.markAlertShown()
        let confirmed = await Alert.confirm(
            title: String(localized: .settingsSupportMetaX),
            message: String(localized: .supportMessage),
            confirmTitle: String(localized: .supportAction),
            cancelTitle: String(localized: .supportMaybeLater),
            on: navigationController
        )
        if confirmed { showSupport() }
    }

    func showSupport() {
        let viewModel = SupportViewModel(storeService: container.storeService)
        let viewController = SupportViewController(viewModel: viewModel)
        let nav = UINavigationController(rootViewController: viewController)
        navigationController.present(nav, animated: true)
    }

    var albumViewController: AlbumViewController? {
        navigationController.viewControllers.first as? AlbumViewController
    }

    // MARK: - Private Methods

    private func setupSplitView() {
        splitViewController.delegate = self
        splitViewController.preferredDisplayMode = .oneBesideSecondary
        splitViewController.preferredSplitBehavior = .tile
        splitViewController.setViewController(navigationController, for: .primary)
    }
}

// MARK: - UISplitViewControllerDelegate

extension AppCoordinator: UISplitViewControllerDelegate {

    func splitViewController(
        _ splitViewController: UISplitViewController,
        collapseSecondary secondaryViewController: UIViewController,
        onto primaryViewController: UIViewController
    ) -> Bool {
        // Always collapse onto primary on initial launch for compact devices.
        true
    }
}
