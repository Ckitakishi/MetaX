/**
 * LoadableNib.swift
 * LoadableNib
 *
 * Created by Ckitakishi on 2017/10/20.
 * Copyright © 2017年 Yuhan Chen. All rights reserved.
 *
 * [Under the MIT License.]
 */

import UIKit

public protocol Loadable: class {
    static var nibName: String { get }
}

public extension Loadable {
    static var nibName: String { return String(describing: Self.self) }
}

public extension UIView {
    
    func instantiateFromNib<T: UIView>(_:T.Type) -> T where T: Loadable {
        if let nib = UINib(nibName: T.nibName, bundle: nil).instantiate(withOwner: nil, options: nil).first as? T {
            return nib
        } else {
            fatalError("Nib \(T.nibName) is not exist ?!")
        }
    }
    
    func instantiateFromNibOwner<T: UIView>(_:T.Type) where T: Loadable {
        let bundle = Bundle(for: type(of: self))
        if let nib = UINib(nibName: T.nibName, bundle: bundle).instantiate(withOwner: self, options: nil).first as? UIView {
            nib.frame = self.bounds
            nib.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            self.addSubview(nib)
        } else {
            fatalError("Nib \(T.nibName) is not exist ?!")
        }
    }
    
}

