//
//  DetailCellModel.swift
//  MetaX
//
//  Created by Ckitakishi on 2018/4/2.
//  Copyright © 2018 Yuhan Chen. All rights reserved.
//

import UIKit
import CoreLocation

protocol DetailCellModelRepresentable {
    var prop: String { get }
    var value: String { get }
}

struct DetailCellModel: DetailCellModelRepresentable {

    let prop: String
    let value: String

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
    
    init(prop: String, value: String) {
        self.prop = prop
        self.value = value
    }

    init(propValue: [String: Any]) {
        guard let firstProp = propValue.first else {
            self.prop = "-"
            self.value = "-"
            return
        }
        
        let rawProp = firstProp.key
        
        let localizedProp: String
        switch rawProp {
        case "DateTimeOriginal": localizedProp = String(localized: .viewAddDate)
        case "Location": localizedProp = String(localized: .viewAddLocation)
        case "ExposureTime": localizedProp = String(localized: .exposureTime)
        case "FNumber": localizedProp = String(localized: .fnumber)
        case "ISOSpeedRatings": localizedProp = String(localized: .isospeedRatings)
        case "ExposureBiasValue": localizedProp = String(localized: .exposureBiasValue)
        case "ExposureProgram": localizedProp = String(localized: .exposureProgram)
        case "MeteringMode": localizedProp = String(localized: .meteringMode)
        case "Make": localizedProp = String(localized: .make)
        case "Model": localizedProp = String(localized: .model)
        case "WhiteBalance": localizedProp = String(localized: .whiteBalance)
        case "Flash": localizedProp = String(localized: .flash)
        case "LensMake": localizedProp = String(localized: .lensMake)
        case "LensModel": localizedProp = String(localized: .lensModel)
        case "FocalLength": localizedProp = String(localized: .focalLength)
        case "FocalLenIn35mmFilm": localizedProp = String(localized: .focalLenIn35MmFilm)
        case "PixelWidth": localizedProp = String(localized: .pixelWidth)
        case "PixelHeight": localizedProp = String(localized: .pixelHeight)
        case "ProfileName": localizedProp = String(localized: .profileName)
        case "Artist": localizedProp = String(localized: .artist)
        case "Copyright": localizedProp = String(localized: .copyright)
        default: localizedProp = NSLocalizedString(rawProp, comment: "")
        }
        
        self.prop = localizedProp
        
        let rawValue = DetailCellModel.formatValue(rawValue: firstProp.value, forProp: rawProp)
        self.value = DetailCellModel.applySymbol(toValue: rawValue, forProp: rawProp)
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

        // ExposureBiasValue special formatting
        if prop == "ExposureBiasValue", let val = rawValue as? Double {
            return formatExposureBias(val)
        }

        // Generic formatting
        if let val = rawValue as? Int {
            return String(val)
        } else if let val = rawValue as? Double {
            if prop == "ExposureTime" {
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
        case "ExposureTime":
            return value + "s"
        case "FNumber":
            return "f/" + value
        case "FocalLenIn35mmFilm", "FocalLength":
            return value + "mm"
        default:
            return value
        }
    }
}