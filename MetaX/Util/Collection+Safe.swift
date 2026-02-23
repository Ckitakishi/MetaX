//
//  Collection+Safe.swift
//  MetaX
//
//  Created by Yuhan Chen on 2026/02/21.
//  Copyright © 2026 Yuhan Chen. All rights reserved.
//

import Foundation

extension Collection {
    /// Returns the element at the specified index if it is within bounds, otherwise returns nil.
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
