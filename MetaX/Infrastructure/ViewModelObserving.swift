//
//  ViewModelObserving.swift
//  MetaX
//
//  Created by Chen Yuhan on 2026/02/03.
//  Copyright © 2026 Chen Yuhan. All rights reserved.
//

import UIKit

/// A protocol that provides reactive observation capabilities to UIKit components.
/// Bridges Swift's @Observable and UIKit's imperative update model.
///
/// Both `self` (the ViewController) and the view model are weakly captured
/// internally, preventing retain cycles while maintaining continuous observation.
@MainActor
protocol ViewModelObserving: AnyObject {}

extension ViewModelObserving where Self: UIViewController {
    /// Observes a property on an @Observable view model and triggers a UI update when it changes.
    ///
    /// Observation automatically re-subscribes after each change until either
    /// `self` or the view model is deallocated — no manual cleanup required.
    ///
    /// - Parameters:
    ///   - viewModel: The @Observable view model instance. Weakly captured internally.
    ///   - property: A closure that accesses observable properties on the view model.
    ///              All properties accessed here will be tracked for changes.
    ///   - update: A closure that performs UI updates with the observed value.
    ///            Use `[weak self]` if referencing the ViewController.
    func observe<VM: Sendable & AnyObject, T: Sendable>(
        viewModel: VM,
        property: @escaping @MainActor (VM) -> T,
        update: @escaping @MainActor (T) -> Void
    ) {
        // Read the property inside withObservationTracking to register dependencies,
        // then call update() OUTSIDE the tracking scope. This ensures only the
        // specified property is tracked — not any @Observable reads that happen
        // as side effects of the update closure (e.g. reloadData reading datasource
        // properties), which would cause spurious extra re-triggers.
        let value = withObservationTracking {
            property(viewModel)
        } onChange: { [weak self, weak viewModel] in
            guard let viewModel = viewModel else { return }
            Task { @MainActor in
                self?.observe(viewModel: viewModel, property: property, update: update)
            }
        }
        update(value)
    }
}
