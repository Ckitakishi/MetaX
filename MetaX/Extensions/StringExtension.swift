//
//  StringExtension.swift
//  MetaX
//
//  Created by Ckitakishi on 2018/4/20.
//  Copyright © 2018年 Yuhan Chen. All rights reserved.
//

import Foundation

extension String {
    
    func localized(bundle: Bundle = .main, tableName: String = "Localizable") -> String {
        return NSLocalizedString(self, tableName: tableName, value: "\(self)", comment: "")
    }
}
