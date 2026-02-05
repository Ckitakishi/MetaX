//
//  DetailTableCellController.swift
//  MetaX
//
//  Created by Ckitakishi on 2018/4/2.
//  Copyright © 2018年 Yuhan Chen. All rights reserved.
//

import UIKit

protocol DetailCellModelRepresentable {
    var prop: String { get }
    var value: String { get }
}

struct DetailCellModel: DetailCellModelRepresentable {
    
    var prop: String 
    var value: String
    
    init() {
        self.prop = "-"
        self.value = "-"
    }
    
    init(propValue: [String: Any]) {
        
        self.init()
        
        guard let firstProp = propValue.first else { return }
        
        self.prop = firstProp.key
        self.value = self.typeExtension(valueAny: firstProp.value)
        self.value = self.symbolAndFormmatExtension()
    }
}

extension DetailCellModel {
    
    func typeExtension(valueAny: Any) -> String {
        
        if let val = valueAny as? Int {
            return String(describing: val)
        } else if let val = valueAny as? Double {
            if (self.prop == "ExposureTime") {
                let rational = Rational.init(approximationOf: val)
                if rational.num < rational.den {
                    return (String(describing: rational.num) + "/" + String(describing: rational.den))
                }
            }
            return String(describing: val)
        } else if let valueAry = valueAny as? [Int] {
            return valueAry.reduce("") { str, val in
                return str + String(describing: val)
            }
        } else {
           return String(describing: valueAny)
        }
    }
    
    func symbolAndFormmatExtension() -> String {
        
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

