//
//  AppDelegate.swift
//  MetaX
//
//  Created by Ckitakishi on 2018/3/14.
//  Copyright © 2018年 Yuhan Chen. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UISplitViewControllerDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        guard let splitViewController = window?.rootViewController as? UISplitViewController else {
            fatalError("Unable to get splitViewController.")
        }
        splitViewController.delegate = self
        splitViewController.preferredDisplayMode = .allVisible

        window?.makeKeyAndVisible()

        return true
    }
}
