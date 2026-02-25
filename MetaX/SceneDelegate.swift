//
//  SceneDelegate.swift
//  MetaX
//
//  Created by Yuhan Chen on 2026/2/6.
//  Copyright © 2026 Yuhan Chen. All rights reserved.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    // MARK: - Properties

    var window: UIWindow?
    private var splashWindow: UIWindow?
    private var container: DependencyContainer?
    private var coordinator: AppCoordinator?

    // MARK: - Scene Lifecycle

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        // Bootstrap the dependency graph and record this launch for tipping logic.
        let container = DependencyContainer()
        self.container = container
        container.tippingManager.recordLaunch()

        // Wire up the coordinator and root window.
        let coordinator = AppCoordinator(container: container)
        self.coordinator = coordinator

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = coordinator.rootViewController()
        window.tintColor = Theme.Colors.accent
        window.overrideUserInterfaceStyle = container.settingsService.userInterfaceStyle
        window.makeKeyAndVisible()
        self.window = window

        coordinator.start()

        // Show splash over the main window until the photo library is ready.
        if let albumVC = coordinator.albumViewController {
            setupSplashWindow(in: windowScene, dismissalTrigger: albumVC)
        }
    }

    // MARK: - Private Methods

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
            guard let self else { return }
            UIView.animate(withDuration: Theme.Animation.splashFade, delay: 0, options: .curveEaseOut) {
                self.splashWindow?.alpha = 0
            } completion: { _ in
                self.splashWindow = nil

                Task {
                    try? await Task.sleep(for: .seconds(1))
                    await self.coordinator?.showTippingAlertIfNeeded()
                }
            }
        }
    }
}
