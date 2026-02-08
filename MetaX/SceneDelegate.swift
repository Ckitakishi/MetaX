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
    private var container: DependencyContainer?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        let container = DependencyContainer()
        self.container = container

        // 1. Master: Album list
        let albumVC = AlbumViewController(container: container)
        let masterNav = UINavigationController(rootViewController: albumVC)

        // 2. Detail: Photo grid
        let photoGridVC = PhotoGridViewController(container: container)
        photoGridVC.title = String(localized: .viewAllPhotos)

        let detailNav = UINavigationController(rootViewController: photoGridVC)

        // 3. Split View Controller
        let splitVC = UISplitViewController()
        splitVC.viewControllers = [masterNav, detailNav]
        splitVC.delegate = self
        splitVC.preferredDisplayMode = .allVisible

        window.rootViewController = splitVC
        window.tintColor = UIColor(named: "greenSea") ?? .systemTeal
        window.makeKeyAndVisible()
        self.window = window
    }

    // MARK: - UISplitViewControllerDelegate

    // Ensures that on iPhone (collapsed), we start with the Album list.
    func splitViewController(_ splitViewController: UISplitViewController, collapseSecondary secondaryViewController: UIViewController, onto primaryViewController: UIViewController) -> Bool {
        // Return true to indicate that we have handled the collapse,
        // which will cause the UISplitViewController to show the Primary (Master) view on top for iPhone.
        return true
    }
}
