//
//  AppRouter.swift
//  MetaX
//
//  Created by Yuhan Chen on 2026/02/12.
//

import UIKit
import Photos
import MapKit
import CoreLocation

/// Intent-based routing for the entire application.
@MainActor
protocol AppRouter {
    /// Presents the save options and returns the chosen workflow mode.
    func pickSaveWorkflow(on presenter: UIViewController?) async -> SaveWorkflowMode?

    /// Opens the location map for a given coordinate.
    func openLocationMap(for location: CLLocation)

    /// Navigates to the asset detail view, pushing onto the given navigation controller.
    func viewAssetDetail(for asset: PHAsset, in collection: PHAssetCollection?, from sourceNav: UINavigationController?)

    /// Navigates to the settings view.
    func viewSettings(from sourceNav: UINavigationController)
}

/// The concrete implementation of navigation logic.
@MainActor
final class AppCoordinator: AppRouter {
    private let navigationController: UINavigationController
    private let container: DependencyContainer

    init(navigationController: UINavigationController, container: DependencyContainer) {
        self.navigationController = navigationController
        self.container = container
    }

    // MARK: - AppRouter Implementation

    func viewSettings(from sourceNav: UINavigationController) {
        let settingsVC = SettingsViewController(container: container)
        settingsVC.router = self
        let wrapper = UINavigationController(rootViewController: settingsVC)
        sourceNav.present(wrapper, animated: true)
    }

    func pickSaveWorkflow(on presenter: UIViewController? = nil) async -> SaveWorkflowMode? {
        await withCheckedContinuation { continuation in
            let vc = SaveOptionsViewController()
            var isResumed = false
            
            vc.onSelect = { mode in
                guard !isResumed else { return }
                isResumed = true
                continuation.resume(returning: mode)
            }
            vc.onCancel = {
                guard !isResumed else { return }
                isResumed = true
                continuation.resume(returning: nil)
            }
            
            let host = presenter ?? navigationController
            host.present(vc, animated: true)
        }
    }

    func openLocationMap(for location: CLLocation) {
        let mapVC = UIViewController()
        mapVC.title = String(localized: .location)
        let fullMapView = MKMapView()
        fullMapView.translatesAutoresizingMaskIntoConstraints = false
        fullMapView.setRegion(MKCoordinateRegion(center: location.coordinate, latitudinalMeters: 1000, longitudinalMeters: 1000), animated: false)

        let annotation = MKPointAnnotation()
        annotation.coordinate = location.coordinate
        fullMapView.addAnnotation(annotation)

        mapVC.view.addSubview(fullMapView)
        NSLayoutConstraint.activate([
            fullMapView.topAnchor.constraint(equalTo: mapVC.view.topAnchor),
            fullMapView.leadingAnchor.constraint(equalTo: mapVC.view.leadingAnchor),
            fullMapView.trailingAnchor.constraint(equalTo: mapVC.view.trailingAnchor),
            fullMapView.bottomAnchor.constraint(equalTo: mapVC.view.bottomAnchor)
        ])

        let nav = UINavigationController(rootViewController: mapVC)
        mapVC.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(dismissMap))
        
        navigationController.present(nav, animated: true)
    }
    
    @objc private func dismissMap() {
        navigationController.dismiss(animated: true)
    }

    func viewAssetDetail(for asset: PHAsset, in collection: PHAssetCollection?, from sourceNav: UINavigationController?) {
        let detailVC = DetailInfoViewController(container: container)
        detailVC.configure(with: asset, collection: collection)
        detailVC.router = self
        let nav = sourceNav ?? navigationController
        nav.pushViewController(detailVC, animated: true)
    }
}
