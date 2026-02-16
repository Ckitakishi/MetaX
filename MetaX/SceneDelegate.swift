//
//  SceneDelegate.swift
//  MetaX
//
//  Created by Yuhan Chen on 2025/2/6.
//  Copyright © 2025 Yuhan Chen. All rights reserved.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    private var splashWindow: UIWindow?
    private var container: DependencyContainer?
    private var coordinator: AppCoordinator?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let container = DependencyContainer()
        self.container = container

        let coordinator = AppCoordinator(container: container)
        self.coordinator = coordinator
        coordinator.start()

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = coordinator.rootViewController()
        window.tintColor = Theme.Colors.accent
        window.overrideUserInterfaceStyle = container.settingsService.userInterfaceStyle
        window.makeKeyAndVisible()
        self.window = window

        if let albumVC = coordinator.albumViewController {
            setupSplashWindow(in: windowScene, dismissalTrigger: albumVC)
        }
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
}
