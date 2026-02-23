//
//  Coordinator.swift
//  MetaX
//

import UIKit

/// Base protocol for all flow coordinators in the app.
@MainActor
protocol Coordinator: AnyObject {
    var childCoordinators: [Coordinator] { get set }
    var navigationController: UINavigationController { get set }

    /// Starts the coordinator's flow.
    func start()
}

extension Coordinator {
    /// Adds a child coordinator to prevent it from being deallocated.
    func addChild(_ child: Coordinator) {
        childCoordinators.append(child)
    }

    /// Removes a child coordinator once its flow is finished.
    func removeChild(_ child: Coordinator) {
        childCoordinators.removeAll { $0 === child }
    }
}
