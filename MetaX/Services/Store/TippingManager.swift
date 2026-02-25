//
//  TippingManager.swift
//  MetaX
//
//  Created by Yuhan Chen on 2026/02/25.
//

import Foundation

@MainActor
final class TippingManager {

    private let settingsService: SettingsServiceProtocol

    init(settingsService: SettingsServiceProtocol) {
        self.settingsService = settingsService
    }

    /// Records a launch. Must be called once per app launch.
    func recordLaunch() {
        settingsService.launchCount += 1
    }

    /// Returns whether the tipping alert should be presented on this launch.
    func shouldShowTippingAlert() -> Bool {
        #if DEBUG
            settingsService
                .debugAlwaysShowTipAlert || (settingsService.launchCount >= 6 && !settingsService.hasShownTipAlert)
        #else
            settingsService.launchCount >= 6 && !settingsService.hasShownTipAlert
        #endif
    }

    /// Marks the alert as having been shown so it is not repeated.
    func markAlertShown() {
        settingsService.hasShownTipAlert = true
    }
}
