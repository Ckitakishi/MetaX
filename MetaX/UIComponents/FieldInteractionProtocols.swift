//
//  FieldInteractionProtocols.swift
//  MetaX
//
//  Created by Yuhan Chen on 2026/04/13.
//

import UIKit

/// Adopted by form field views that support a batch-edit toggle.
@MainActor
protocol FieldToggleable: AnyObject {
    var onToggleEnabled: ((Bool) -> Void)? { get set }
}

/// Adopted by location field views that trigger location search when tapped.
@MainActor
protocol LocationFieldInteractable: AnyObject {
    var onTapLocationField: (() -> Void)? { get set }
}
