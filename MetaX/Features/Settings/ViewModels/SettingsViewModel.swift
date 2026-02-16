//
//  SettingsViewModel.swift
//  MetaX
//
//  Created by Yuhan Chen on 2026/02/15.
//

import Observation
import Photos
import UIKit

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

struct SettingsItem: Identifiable {
    let id = UUID()
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

struct SettingsSectionModel {
    let section: SettingsSection
    let color: UIColor
    let items: [SettingsItem]
}

@Observable @MainActor
final class SettingsViewModel {

    // MARK: - Public State

    private(set) var sectionModels: [SettingsSectionModel] = []

    let appearanceOptions: [(title: String, icon: String, style: UIUserInterfaceStyle)] = [
        (String(localized: .settingsAppearanceSystem), "circle.lefthalf.filled", .unspecified),
        (String(localized: .settingsAppearanceLight), "sun.max", .light),
        (String(localized: .settingsAppearanceDark), "moon", .dark),
    ]

    // MARK: - Dependencies

    private let photoLibraryService: PhotoLibraryServiceProtocol
    private var settingsService: SettingsServiceProtocol

    init(photoLibraryService: PhotoLibraryServiceProtocol, settingsService: SettingsServiceProtocol) {
        self.photoLibraryService = photoLibraryService
        self.settingsService = settingsService
        refresh()
    }

    // MARK: - Public Methods

    func refresh() {
        sectionModels = [
            buildPreferencesSection(),
            buildGeneralSection(),
            buildSupportSection(),
            buildAboutSection(),
        ]
    }

    func updateAppearance(_ style: UIUserInterfaceStyle) {
        settingsService.userInterfaceStyle = style
        refresh()
    }

    func performAction(for item: SettingsItem) {
        switch item.type {
        case .appearance, .version:
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
        }
    }

    // MARK: - Private Builders

    private func buildPreferencesSection() -> SettingsSectionModel {
        SettingsSectionModel(
            section: .preferences,
            color: Theme.Colors.settingsAppearance,
            items: [
                SettingsItem(
                    type: .appearance,
                    icon: "paintbrush",
                    iconColor: Theme.Colors.settingsAppearance,
                    title: String(localized: .settingsAppearance),
                    value: currentAppearanceName
                ),
            ]
        )
    }

    private func buildGeneralSection() -> SettingsSectionModel {
        let blue = Theme.Colors.settingsGeneral
        return SettingsSectionModel(
            section: .general,
            color: blue,
            items: [
                SettingsItem(
                    type: .photoPermissions,
                    icon: "photo",
                    iconColor: blue,
                    title: String(localized: .settingsPhotoPermissions),
                    value: photoPermissionStatus
                ),
                SettingsItem(
                    type: .language,
                    icon: "globe",
                    iconColor: blue,
                    title: String(localized: .settingsLanguage),
                    value: currentLanguageName,
                    isExternal: true
                ),
            ]
        )
    }

    private func buildSupportSection() -> SettingsSectionModel {
        let green = Theme.Colors.settingsSupport
        return SettingsSectionModel(
            section: .support,
            color: green,
            items: [
                SettingsItem(
                    type: .writeReview,
                    icon: "star",
                    iconColor: green,
                    title: String(localized: .settingsWriteReview),
                    isExternal: true
                ),
                SettingsItem(
                    type: .sendFeedback,
                    icon: "envelope",
                    iconColor: green,
                    title: String(localized: .settingsSendFeedback),
                    isExternal: true
                ),
            ]
        )
    }

    private func buildAboutSection() -> SettingsSectionModel {
        let gray = Theme.Colors.settingsAbout
        return SettingsSectionModel(
            section: .about,
            color: gray,
            items: [
                SettingsItem(
                    type: .termsOfService,
                    icon: "doc.text",
                    iconColor: gray,
                    title: String(localized: .settingsTermsOfService),
                    isExternal: true
                ),
                SettingsItem(
                    type: .privacyPolicy,
                    icon: "hand.raised",
                    iconColor: gray,
                    title: String(localized: .settingsPrivacyPolicy),
                    isExternal: true
                ),
                SettingsItem(
                    type: .version,
                    icon: "info.circle",
                    iconColor: gray,
                    title: String(localized: .settingsVersion),
                    value: Bundle.main.appVersion
                ),
            ]
        )
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
}
