//
//  UITableView+Reusable.swift
//  MetaX
//
//  Created by Ckitakishi on 2018/3/19.
//  Copyright © 2018 Yuhan Chen. All rights reserved.
//

import UIKit

protocol Reusable: AnyObject {
    static var reuseIdentifier: String { get }
    static var nib: UINib? { get }
}

extension Reusable {
    static var reuseIdentifier: String {
        return String(describing: Self.self)
    }

    static var nib: UINib? {
        return nil
    }
}

extension UITableView {

    func registerReusableCell<T: UITableViewCell & Reusable>(_: T.Type) {
        if let nib = T.nib {
            register(nib, forCellReuseIdentifier: T.reuseIdentifier)
        } else {
            register(T.self, forCellReuseIdentifier: T.reuseIdentifier)
        }
    }

    func dequeueReusableCell<T: UITableViewCell & Reusable>(indexPath: IndexPath) -> T {
        guard let cell = dequeueReusableCell(withIdentifier: T.reuseIdentifier, for: indexPath) as? T else {
            assertionFailure(
                "Failed to dequeue cell with identifier: \(T.reuseIdentifier). Did you forget to register it?"
            )
            return T() // Fallback to avoid crash in production, though UI will be wrong
        }
        return cell
    }
}
