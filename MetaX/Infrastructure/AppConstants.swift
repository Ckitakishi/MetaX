//
//  AppConstants.swift
//  MetaX
//
//  Created by Yuhan Chen on 2026/02/15.
//

import Foundation

enum AppConstants {
    // MARK: - App Info

    static let appName = "MetaX"
    static let appID = "1376589355"
    static let feedbackEmail = "misoshido.team@gmail.com"

    /// Unique identifier for Photo Library edit adjustments.
    static let adjustmentFormatID = "ckitakishi.com.MetaX"

    // MARK: - External Links

    static var writeReviewURL: URL? {
        URL(string: "https://apps.apple.com/app/id\(appID)?action=write-review")
    }

    static var feedbackEmailURL: URL? {
        let subject = "MetaX Feedback"
        let body = "\n\n--- App Version: \(Bundle.main.appVersion) ---"
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        return URL(string: "mailto:\(feedbackEmail)?subject=\(encodedSubject)&body=\(encodedBody)")
    }

    static let termsOfServiceURL = URL(string: "https://misoshido.com/metax/terms/")!
    static let privacyPolicyURL = URL(string: "https://misoshido.com/metax/privacy/")!
    static let githubURL = URL(string: "https://github.com/ckitakishi/MetaX")!

    // MARK: - IAP (Tips)

    static let tipAppleJuiceID = "com.ckitakishi.metax.tip.apple_juice"
    static let tipApplePieID = "com.ckitakishi.metax.tip.apple_pie"

    static let allTipProductIDs = [tipAppleJuiceID, tipApplePieID]
}

// MARK: - Bundle Extension

extension Bundle {
    /// Returns the app's version and build number (e.g., "1.0.0 (1)").
    var appVersion: String {
        guard let version = infoDictionary?["CFBundleShortVersionString"] as? String,
              let build = infoDictionary?["CFBundleVersion"] as? String
        else {
            return "1.0.0"
        }
        return "\(version) (\(build))"
    }
}
