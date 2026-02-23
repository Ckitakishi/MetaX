//
//  ViewModelObserving.swift
//  MetaX
//
//  Created by Chen Yuhan on 2026/02/03.
//  Copyright © 2026 Chen Yuhan. All rights reserved.
//

import UIKit

/// A protocol providing reactive observation capabilities to UIKit components.
/// Bridges Swift's @Observable with UIKit's imperative update model.
@MainActor
protocol ViewModelObserving: AnyObject {}

extension ViewModelObserving where Self: UIViewController {
    /// Observes an @Observable property and triggers a UI update when it changes.
    ///
    /// - Parameters:
    ///   - viewModel: The @Observable view model instance.
    ///   - property: A closure accessing properties to be tracked.
    ///   - update: A closure performing UI updates with the observed value.
    func observe<VM: Sendable & AnyObject, T: Sendable>(
        viewModel: VM,
        property: @escaping @MainActor (VM) -> T,
        update: @escaping @MainActor (T) -> Void
    ) {
        // Read property inside withObservationTracking to register dependencies,
        // then call update() OUTSIDE to avoid spurious triggers from side-effect reads.
        let value = withObservationTracking {
            property(viewModel)
        } onChange: { [weak self, weak viewModel] in
            guard let viewModel else { return }
            Task { @MainActor in
                self?.observe(viewModel: viewModel, property: property, update: update)
            }
        }
        update(value)
    }
}
