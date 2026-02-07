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

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)

        // Master: Album list
        let albumVC = AlbumViewController()
        let masterNav = UINavigationController(rootViewController: albumVC)

        // Detail: Photo grid (empty state initially)
        let photoGridVC = PhotoGridViewController()
        let detailNav = UINavigationController(rootViewController: photoGridVC)

        // Split View Controller
        let splitVC = UISplitViewController()
        splitVC.viewControllers = [masterNav, detailNav]
        splitVC.delegate = self
        splitVC.preferredDisplayMode = .allVisible

        window.rootViewController = splitVC
        window.makeKeyAndVisible()
        self.window = window
    }
}
