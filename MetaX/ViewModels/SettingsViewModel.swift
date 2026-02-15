//
//  SettingsViewModel.swift
//  MetaX
//
//  Created by Yuhan Chen on 2026/02/15.
//

import UIKit
import Photos

enum SettingsSection: CaseIterable {
    case preferences
    case general
    case support
    case about
    
    var title: String {
        switch self {
        case .preferences: return String(localized: .settingsPreferences)
        case .general: return String(localized: .settingsGeneral)
        case .support: return String(localized: .settingsSupport)
        case .about: return String(localized: .settingsAbout)
        }
    }
}

struct SettingsItem {
    let type: ItemType
    let icon: String
    let iconColor: UIColor
    let title: String
    var value: String? = nil
    var isExternal: Bool = false
    
    enum ItemType: Hashable {
        case appearance
        case language
        case photoPermissions
        case writeReview
        case sendFeedback
        case termsOfService
        case privacyPolicy
        case version
    }
}

final class SettingsViewModel {
    
    private let photoLibraryService: PhotoLibraryServiceProtocol
    private var settingsService: SettingsServiceProtocol
    
    init(container: DependencyContainer) {
        self.photoLibraryService = container.photoLibraryService
        self.settingsService = container.settingsService
    }
    
    func items(for section: SettingsSection) -> [SettingsItem] {
        switch section {
        case .preferences:
            return [
                SettingsItem(type: .appearance, icon: "paintbrush", iconColor: Theme.Colors.settingsAppearance, title: String(localized: .settingsAppearance), value: currentAppearanceName)
            ]
        case .general:
            let blue = Theme.Colors.settingsGeneral
            return [
                SettingsItem(type: .photoPermissions, icon: "photo", iconColor: blue, title: String(localized: .settingsPhotoPermissions), value: photoPermissionStatus),
                SettingsItem(type: .language, icon: "globe", iconColor: blue, title: String(localized: .settingsLanguage), value: currentLanguageName, isExternal: true)
            ]
        case .support:
            let green = Theme.Colors.settingsSupport
            return [
                SettingsItem(type: .writeReview, icon: "star", iconColor: green, title: String(localized: .settingsWriteReview), isExternal: true),
                SettingsItem(type: .sendFeedback, icon: "envelope", iconColor: green, title: String(localized: .settingsSendFeedback), isExternal: true)
            ]
        case .about:
            let gray = Theme.Colors.settingsAbout
            return [
                SettingsItem(type: .termsOfService, icon: "doc.text", iconColor: gray, title: String(localized: .settingsTermsOfService), isExternal: true),
                SettingsItem(type: .privacyPolicy, icon: "hand.raised", iconColor: gray, title: String(localized: .settingsPrivacyPolicy), isExternal: true),
                SettingsItem(type: .version, icon: "info.circle", iconColor: gray, title: String(localized: .settingsVersion), value: Bundle.main.appVersion)
            ]
        }
    }
    
    func color(for section: SettingsSection) -> UIColor {
        switch section {
        case .preferences:
            return Theme.Colors.settingsAppearance
        case .general:
            return Theme.Colors.settingsGeneral
        case .support:
            return Theme.Colors.settingsSupport
        case .about:
            return Theme.Colors.settingsAbout
        }
    }
    
    private var photoPermissionStatus: String {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .authorized: return String(localized: .settingsStatusAuthorized)
        case .limited: return String(localized: .settingsStatusLimited)
        case .denied, .restricted: return String(localized: .settingsStatusDenied)
        default: return ""
        }
    }
    
    private var currentLanguageName: String {
        guard let code = Locale.current.language.languageCode?.identifier else { return "" }
        return Locale.current.localizedString(forLanguageCode: code) ?? code
    }
    
    private var currentAppearanceName: String {
        switch settingsService.userInterfaceStyle {
        case .light: return String(localized: .settingsAppearanceLight)
        case .dark: return String(localized: .settingsAppearanceDark)
        default: return String(localized: .settingsAppearanceSystem)
        }
    }
    
    func updateAppearance(_ style: UIUserInterfaceStyle) {
        settingsService.userInterfaceStyle = style
    }
    
    func performAction(for item: SettingsItem, from vc: UIViewController) {
        switch item.type {
        case .appearance:
            break
        case .language, .photoPermissions:
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        case .writeReview:
            if let url = AppConstants.writeReviewURL {
                UIApplication.shared.open(url)
            }
        case .sendFeedback:
            if let url = AppConstants.feedbackEmailURL {
                UIApplication.shared.open(url)
            }
        case .termsOfService:
            UIApplication.shared.open(AppConstants.termsOfServiceURL)
        case .privacyPolicy:
            UIApplication.shared.open(AppConstants.privacyPolicyURL)
        case .version:
            break
        }
    }
}
