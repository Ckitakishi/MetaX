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
        
        self.prop = propValue.map { $0.0 } [0]
        let valueAny = propValue.map { $0.1 } [0]
        self.value = self.typeExtension(valueAny: valueAny)
        self.value = self.symbolAndFormmatExtension()
    }
}

extension DetailCellModel {
    
    func typeExtension(valueAny: Any) -> String {
        
        if valueAny is Int {
            return String(describing: valueAny)
        } else if valueAny is Double {
            if (self.prop == "ExposureTime") {
                let rational = Rational.init(approximationOf: valueAny as! Double)
                if rational.num < rational.den {
                    return (String(describing: rational.num) + "/" + String(describing: rational.den))
                }
            }
            return String(describing: valueAny)
        } else if valueAny is [Int] {
            let valueAry = valueAny as! [Int]
            return valueAry.reduce("") { str, val in
                return str + String(describing: val)
            }
        } else {
           return valueAny as! String
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

