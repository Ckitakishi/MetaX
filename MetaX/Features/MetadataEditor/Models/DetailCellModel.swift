//
//  DetailCellModel.swift
//  MetaX
//
//  Created by Ckitakishi on 2018/4/2.
//  Copyright © 2018 Yuhan Chen. All rights reserved.
//

import CoreLocation
import UIKit

protocol DetailCellModelRepresentable {
    var prop: String { get }
    var value: String { get }
}

struct DetailCellModel: DetailCellModelRepresentable {

    let prop: String
    let value: String
    let rawKey: String

    // MARK: - EXIF Enum Mappings

    private static let exifEnumMappings: [String: [String: String]] = {
        guard let url = Bundle.main.url(forResource: "ExifEnumMappings", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tags = json["tags"] as? [String: Any] else { return [:] }
        var result: [String: [String: String]] = [:]
        for (tagName, tagInfo) in tags {
            if let info = tagInfo as? [String: Any],
               let values = info["values"] as? [String: String] {
                result[tagName] = values
            }
        }
        return result
    }()

    init(prop: String, value: String, rawKey: String = "") {
        self.prop = prop
        self.value = value
        self.rawKey = rawKey
    }

    init(propValue: [String: Any]) {
        guard let firstProp = propValue.first else {
            prop = "-"
            value = "-"
            rawKey = ""
            return
        }

        let rawProp = firstProp.key
        rawKey = rawProp

        let localizedProp: String
        switch rawProp {
        case MetadataKeys.dateTimeOriginal: localizedProp = String(localized: .viewAddDate)
        case MetadataKeys.location: localizedProp = String(localized: .viewAddLocation)
        case MetadataKeys.exposureTime: localizedProp = String(localized: .exposureTime)
        case MetadataKeys.fNumber: localizedProp = String(localized: .fnumber)
        case MetadataKeys.isoSpeedRatings: localizedProp = String(localized: .isospeedRatings)
        case MetadataKeys.exposureBiasValue: localizedProp = String(localized: .exposureBiasValue)
        case MetadataKeys.exposureProgram: localizedProp = String(localized: .exposureProgram)
        case MetadataKeys.meteringMode: localizedProp = String(localized: .meteringMode)
        case MetadataKeys.make: localizedProp = String(localized: .make)
        case MetadataKeys.model: localizedProp = String(localized: .model)
        case MetadataKeys.whiteBalance: localizedProp = String(localized: .whiteBalance)
        case MetadataKeys.flash: localizedProp = String(localized: .flash)
        case MetadataKeys.lensMake: localizedProp = String(localized: .lensMake)
        case MetadataKeys.lensModel: localizedProp = String(localized: .lensModel)
        case MetadataKeys.focalLength: localizedProp = String(localized: .focalLength)
        case MetadataKeys.focalLenIn35mmFilm: localizedProp = String(localized: .focalLenIn35MmFilm)
        case "PixelWidth": localizedProp = String(localized: .pixelWidth)
        case "PixelHeight": localizedProp = String(localized: .pixelHeight)
        case "ProfileName": localizedProp = String(localized: .profileName)
        case MetadataKeys.artist: localizedProp = String(localized: .artist)
        case MetadataKeys.copyright: localizedProp = String(localized: .copyright)
        default: localizedProp = NSLocalizedString(rawProp, comment: "")
        }

        prop = localizedProp

        let rawValue = DetailCellModel.formatValue(rawValue: firstProp.value, forProp: rawProp)
        value = DetailCellModel.applySymbol(toValue: rawValue, forProp: rawProp)
    }

    private static func formatValue(rawValue: Any, forProp prop: String) -> String {
        // Handle CLLocation
        if let location = rawValue as? CLLocation {
            return String(format: "%.4f, %.4f", location.coordinate.latitude, location.coordinate.longitude)
        }

        // Try EXIF enum lookup first
        if let enumFormatted = formatEnumValue(rawValue, forProp: prop) {
            return enumFormatted
        }

        // DateTimeOriginal special formatting
        if prop == MetadataKeys.dateTimeOriginal, let dateStr = rawValue as? String {
            if let date = DateFormatter.yMdHms.date(from: dateStr) {
                let displayFormatter = DateFormatter()
                displayFormatter.dateStyle = .medium
                displayFormatter.timeStyle = .short
                return displayFormatter.string(from: date)
            }
        }

        // ExposureBiasValue special formatting
        if prop == MetadataKeys.exposureBiasValue, let val = rawValue as? Double {
            return formatExposureBias(val)
        }

        // Generic formatting
        if let val = rawValue as? Int {
            return String(val)
        } else if let val = rawValue as? Double {
            if prop == MetadataKeys.exposureTime {
                let rational = Rational(approximationOf: val)
                if rational.num < rational.den {
                    return "\(rational.num)/\(rational.den)"
                }
            }
            return String(val)
        } else if let valueAry = rawValue as? [Int] {
            return valueAry.map { String($0) }.joined()
        } else {
            return String(describing: rawValue)
        }
    }

    private static func formatEnumValue(_ rawValue: Any, forProp prop: String) -> String? {
        guard let mappings = exifEnumMappings[prop] else { return nil }
        guard let intVal = rawValue as? Int else { return nil }
        guard let specName = mappings[String(intVal)] else { return nil }
        let locKey = prop + "." + specName
        return NSLocalizedString(locKey, comment: "")
    }

    private static func formatExposureBias(_ value: Double) -> String {
        if value == 0 { return "0 EV" }
        let formatted = value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
        return (value > 0 ? "+" : "") + formatted + " EV"
    }

    private static func applySymbol(toValue value: String, forProp prop: String) -> String {
        switch prop {
        case MetadataKeys.exposureTime:
            return value + "s"
        case MetadataKeys.fNumber:
            return "f/" + value
        case MetadataKeys.focalLenIn35mmFilm, MetadataKeys.focalLength:
            return value + "mm"
        default:
            return value
        }
    }
}
