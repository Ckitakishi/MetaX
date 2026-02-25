//
//  SettingsService.swift
//  MetaX
//
//  Created by Yuhan Chen on 2026/02/15.
//

import UIKit

protocol SettingsServiceProtocol: AnyObject {
    var userInterfaceStyle: UIUserInterfaceStyle { get set }
    var launchCount: Int { get set }
    var hasShownTipAlert: Bool { get set }
    #if DEBUG
        var debugAlwaysShowTipAlert: Bool { get set }
    #endif
}

final class SettingsService: SettingsServiceProtocol {

    // MARK: - Constants

    private enum Keys {
        static let userInterfaceStyle = "com.metax.settings.userInterfaceStyle"
        static let launchCount = "com.metax.settings.launchCount"
        static let hasShownTipAlert = "com.metax.settings.hasShownTipAlert"
        #if DEBUG
            static let debugAlwaysShowTipAlert = "com.metax.settings.debugAlwaysShowTipAlert"
        #endif
    }

    // MARK: - Properties

    private let defaults = UserDefaults.standard

    // MARK: - Settings

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

    var launchCount: Int {
        get { defaults.integer(forKey: Keys.launchCount) }
        set { defaults.set(newValue, forKey: Keys.launchCount) }
    }

    var hasShownTipAlert: Bool {
        get { defaults.bool(forKey: Keys.hasShownTipAlert) }
        set { defaults.set(newValue, forKey: Keys.hasShownTipAlert) }
    }

    #if DEBUG
        var debugAlwaysShowTipAlert: Bool {
            get { defaults.bool(forKey: Keys.debugAlwaysShowTipAlert) }
            set { defaults.set(newValue, forKey: Keys.debugAlwaysShowTipAlert) }
        }
    #endif

    // MARK: - Private Methods

    private func apply(style: UIUserInterfaceStyle) {
        Task { @MainActor in
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first(where: { $0.isKeyWindow })
            else { return }

            window.overrideUserInterfaceStyle = style
        }
    }
}
