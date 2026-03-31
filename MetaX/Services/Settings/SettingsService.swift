//
//  SettingsService.swift
//  MetaX
//
//  Created by Yuhan Chen on 2026/02/15.
//

import UIKit

#if DEBUG
    enum DebugBatchProgressMode: Int, CaseIterable {
        case off
        case success
        case partialFailure
        case failure
        case cancelled
    }
#endif

protocol SettingsServiceProtocol: AnyObject {
    var userInterfaceStyle: UIUserInterfaceStyle { get set }
    var launchCount: Int { get set }
    var hasShownTipAlert: Bool { get set }
    #if DEBUG
        var debugAlwaysShowTipAlert: Bool { get set }
        var debugBatchProgressMode: DebugBatchProgressMode { get set }
        var debugBatchProgressDelay: Double { get set }
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
            static let debugBatchProgressMode = "com.metax.settings.debugBatchProgressMode"
            static let debugBatchProgressDelay = "com.metax.settings.debugBatchProgressDelay"
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

        var debugBatchProgressMode: DebugBatchProgressMode {
            get {
                let rawValue = defaults.integer(forKey: Keys.debugBatchProgressMode)
                return DebugBatchProgressMode(rawValue: rawValue) ?? .off
            }
            set {
                defaults.set(newValue.rawValue, forKey: Keys.debugBatchProgressMode)
            }
        }

        var debugBatchProgressDelay: Double {
            get { defaults.double(forKey: Keys.debugBatchProgressDelay) }
            set { defaults.set(newValue, forKey: Keys.debugBatchProgressDelay) }
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
