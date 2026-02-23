//
//  UITableView+Reusable.swift
//  MetaX
//
//  Created by Ckitakishi on 2018/3/19.
//  Copyright © 2018 Yuhan Chen. All rights reserved.
//

import UIKit

/// Protocol to provide easy reuse identifiers for cells.
protocol Reusable: AnyObject {
    static var reuseIdentifier: String { get }
    static var nib: UINib? { get }
}

extension Reusable {
    static var reuseIdentifier: String { String(describing: Self.self) }
    static var nib: UINib? { nil }
}

extension UITableView {

    /// Registers a reusable cell type.
    func registerReusableCell<T: UITableViewCell & Reusable>(_: T.Type) {
        if let nib = T.nib {
            register(nib, forCellReuseIdentifier: T.reuseIdentifier)
        } else {
            register(T.self, forCellReuseIdentifier: T.reuseIdentifier)
        }
    }

    /// Dequeues a reusable cell type for a specific indexPath.
    func dequeueReusableCell<T: UITableViewCell & Reusable>(indexPath: IndexPath) -> T {
        guard let cell = dequeueReusableCell(withIdentifier: T.reuseIdentifier, for: indexPath) as? T else {
            assertionFailure("Failed to dequeue cell with identifier: \(T.reuseIdentifier)")
            return T()
        }
        return cell
    }
}
