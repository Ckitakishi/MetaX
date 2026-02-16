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

    private let splitViewController = UISplitViewController()
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

        // The PhotoFlowCoordinator will handle setting up the master and detail VCs
        // We'll call start() which will configure the navigationController

        // Initial placeholder for detail
        let placeholderVC = UIViewController()
        placeholderVC.view.backgroundColor = Theme.Colors.mainBackground
        let detailNav = UINavigationController(rootViewController: placeholderVC)

        splitViewController.viewControllers = [navigationController, detailNav]
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
