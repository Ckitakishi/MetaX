//
//  SceneDelegate.swift
//  MetaX
//
//  Created by Yuhan Chen on 2025/2/6.
//  Copyright © 2025 Yuhan Chen. All rights reserved.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate, UISplitViewControllerDelegate {

    var window: UIWindow?
    private var splashWindow: UIWindow?
    private var container: DependencyContainer?
    private var coordinator: AppCoordinator?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        let container = DependencyContainer()
        self.container = container

        let albumVC = AlbumViewController(container: container)
        let masterNav = UINavigationController(rootViewController: albumVC)

        let photoGridVC = PhotoGridViewController(container: container)
        photoGridVC.title = String(localized: .viewAllPhotos)
        let detailNav = UINavigationController(rootViewController: photoGridVC)

        let splitVC = UISplitViewController()
        splitVC.viewControllers = [masterNav, detailNav]
        splitVC.delegate = self
        splitVC.preferredDisplayMode = .oneBesideSecondary
        
        // Initialize Global Coordinator
        self.coordinator = AppCoordinator(navigationController: masterNav, container: container)
        albumVC.router = coordinator

        window.rootViewController = splitVC
        window.tintColor = Theme.Colors.accent
        window.makeKeyAndVisible()
        self.window = window

        setupSplashWindow(in: windowScene, dismissalTrigger: albumVC)
    }

    private func setupSplashWindow(in scene: UIWindowScene, dismissalTrigger: AlbumViewController) {
        let splashWindow = UIWindow(windowScene: scene)
        splashWindow.windowLevel = .normal + 1
        splashWindow.rootViewController = UIViewController()
        splashWindow.rootViewController?.view.backgroundColor = .clear
        
        let splashView = SplashView(frame: splashWindow.bounds)
        splashView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        splashWindow.rootViewController?.view.addSubview(splashView)
        
        splashWindow.makeKeyAndVisible()
        self.splashWindow = splashWindow
        
        dismissalTrigger.splashDismissHandler = { [weak self] in
            guard let self = self else { return }
            UIView.animate(withDuration: Theme.Animation.splashFade, delay: 0, options: .curveEaseOut) {
                self.splashWindow?.alpha = 0
            } completion: { _ in
                self.splashWindow = nil
            }
        }
    }

    // MARK: - UISplitViewControllerDelegate

    // Ensures that on iPhone (collapsed), we start with the Album list.
    func splitViewController(_ splitViewController: UISplitViewController, collapseSecondary secondaryViewController: UIViewController, onto primaryViewController: UIViewController) -> Bool {
        // Return true to indicate that we have handled the collapse,
        // which will cause the UISplitViewController to show the Primary (Master) view on top for iPhone.
        return true
    }
}
