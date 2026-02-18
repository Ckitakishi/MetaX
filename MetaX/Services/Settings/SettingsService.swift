//
//  SettingsService.swift
//  MetaX
//
//  Created by Yuhan Chen on 2026/02/15.
//

import UIKit

protocol SettingsServiceProtocol {
    var userInterfaceStyle: UIUserInterfaceStyle { get set }
}

final class SettingsService: SettingsServiceProtocol {

    private enum Keys {
        static let userInterfaceStyle = "com.metax.settings.userInterfaceStyle"
    }

    private let defaults = UserDefaults.standard

    var userInterfaceStyle: UIUserInterfaceStyle {
        get {
            let rawValue = defaults.integer(forKey: Keys.userInterfaceStyle)
            return UIUserInterfaceStyle(rawValue: rawValue) ?? .unspecified
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.userInterfaceStyle)
            apply(style: newValue)
        }
    }

    private func apply(style: UIUserInterfaceStyle) {
        Task { @MainActor in
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first(where: { $0.isKeyWindow })
            else {
                return
            }
            window.overrideUserInterfaceStyle = style
        }
    }
}
