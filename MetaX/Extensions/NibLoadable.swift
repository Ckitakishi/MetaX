import UIKit

protocol NibLoadable: AnyObject {
    static var nibName: String { get }
}

extension NibLoadable where Self: UIView {
    static var nibName: String {
        return String(describing: self)
    }
}

extension UIView {
    func instantiateFromNib<T: NibLoadable>(_ type: T.Type) -> T {
        let nib = UINib(nibName: type.nibName, bundle: nil)
        return nib.instantiate(withOwner: nil, options: nil).first as! T
    }
}
