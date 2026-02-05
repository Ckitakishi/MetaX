import UIKit

// MARK: - Generic Cell Protocols

protocol CellConfig: AnyObject {
    associatedtype DataSource
    var cellDataSource: DataSource? { get set }
}
