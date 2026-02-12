//
//  MetadataEditViewModel.swift
//  MetaX
//
//  Created by Yuhan Chen on 2026/02/11.
//  Copyright © 2026 Yuhan Chen. All rights reserved.
//

import Foundation

enum MetadataFieldType {
    case iso
    case aperture
    case focalLength
    case shutterSpeed
    case exposureBias
    case focalLength35
    case gear // For Make, Model, Lens info
    case artist
    case copyright
}

struct MetadataEditViewModel {
    
    /// Pure logic to validate if a string change should be allowed for a specific field.
    func validateInput(currentText: String, range: NSRange, replacementString string: String, for fieldType: MetadataFieldType) -> Bool {
        if string.isEmpty { return true } // Always allow backspace
        
        guard let stringRange = Range(range, in: currentText) else { return false }
        let updatedText = currentText.replacingCharacters(in: stringRange, with: string)
        
        // 1. Character length limits
        let maxLength: Int
        switch fieldType {
        case .iso, .focalLength35, .aperture, .focalLength, .exposureBias: maxLength = 10
        case .shutterSpeed: maxLength = 15
        case .gear, .artist: maxLength = 64
        case .copyright: maxLength = 200
        }
        if updatedText.count > maxLength { return false }
        
        switch fieldType {
        case .iso, .focalLength35:
            // Positive Integers
            let allowedCharset = CharacterSet.decimalDigits
            return updatedText.rangeOfCharacter(from: allowedCharset.inverted) == nil
            
        case .aperture, .focalLength:
            // Positive Decimals
            let allowedCharset = CharacterSet(charactersIn: "0123456789.")
            if updatedText.rangeOfCharacter(from: allowedCharset.inverted) != nil { return false }
            let dotCount = updatedText.filter { $0 == "." }.count
            return dotCount <= 1
            
        case .shutterSpeed:
            // Fractions or Decimals
            let allowedCharset = CharacterSet(charactersIn: "0123456789./")
            if updatedText.rangeOfCharacter(from: allowedCharset.inverted) != nil { return false }
            let slashCount = updatedText.filter { $0 == "/" }.count
            let dotCount = updatedText.filter { $0 == "." }.count
            return slashCount <= 1 && dotCount <= 1
            
        case .exposureBias:
            // Signed Decimals
            let allowedCharset = CharacterSet(charactersIn: "0123456789.+-")
            if updatedText.rangeOfCharacter(from: allowedCharset.inverted) != nil { return false }
            
            if updatedText.filter({ $0 == "." }).count > 1 { return false }
            
            let signs = updatedText.filter { $0 == "+" || $0 == "-" }
            if signs.count > 1 { return false }
            if signs.count == 1 {
                return updatedText.hasPrefix("+") || updatedText.hasPrefix("-")
            }
            return true
            
        case .gear, .artist, .copyright:
            return true
        }
    }
}