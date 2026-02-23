//
//  AppConstants.swift
//  MetaX
//
//  Created by Yuhan Chen on 2026/02/15.
//

import Foundation

enum AppConstants {
    static let appID = "1376589355"
    static let feedbackEmail = "misoshido.team@gmail.com"
    static let adjustmentFormatID = "ckitakishi.com.MetaX"

    static var writeReviewURL: URL? {
        URL(string: "https://apps.apple.com/app/id\(appID)?action=write-review")
    }

    static var feedbackEmailURL: URL? {
        let subject = "MetaX Feedback"
        let body = "\n\n--- App Version: \(Bundle.main.appVersion) ---"
        let urlString = "mailto:\(feedbackEmail)?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&body=\(body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        return URL(string: urlString)
    }

    static let termsOfServiceURL = URL(string: "https://misoshido.com/metax/terms/")!
    static let privacyPolicyURL = URL(string: "https://misoshido.com/metax/privacy/")!
}

extension Bundle {
    var appVersion: String {
        guard let version = infoDictionary?["CFBundleShortVersionString"] as? String,
              let build = infoDictionary?["CFBundleVersion"] as? String
        else {
            return "1.0.0"
        }
        return "\(version) (\(build))"
    }
}
