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
    func observe<VM, T>(
        viewModel: VM,
        property: @escaping (VM) -> T,
        update: @escaping (T) -> Void
    ) where VM: AnyObject {
        withObservationTracking {
            update(property(viewModel))
        } onChange: { [weak self, weak viewModel] in
            guard let viewModel = viewModel else { return }
            Task { @MainActor in
                guard let self = self else { return }
                self.observe(viewModel: viewModel, property: property, update: update)
            }
        }
    }
}
