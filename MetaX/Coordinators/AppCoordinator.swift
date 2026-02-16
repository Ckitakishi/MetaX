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
    var childCoordinators: [Coordinator] = []
    var navigationController: UINavigationController = .init()

    private let splitViewController = UISplitViewController(style: .doubleColumn)
    private let container: DependencyContainer

    init(container: DependencyContainer) {
        self.container = container
        super.init()
        setupSplitView()
    }

    func rootViewController() -> UIViewController {
        return splitViewController
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

    var albumViewController: AlbumViewController? {
        navigationController.viewControllers.first as? AlbumViewController
    }

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
        return true
    }
}
