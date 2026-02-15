//
//  AppCoordinator.swift
//  MetaX
//
//  Created by Yuhan Chen on 2026/02/12.
//

import CoreLocation
import MapKit
import Photos
import UIKit

enum AppRoute {
    case photoGrid(fetchResult: PHFetchResult<PHAsset>, collection: PHAssetCollection?, title: String)
    case assetDetail(asset: PHAsset, collection: PHAssetCollection?, source: UIViewController)
    case settings(from: UIViewController)
    case locationMap(location: CLLocation)
    case metadataEdit(metadata: Metadata, source: DetailInfoViewController)
    case locationSearch(source: MetadataEditViewController)
}

/// The central coordinator that owns all navigation and flow orchestration.
/// VCs report intents via closures; the coordinator decides where to go and how to sequence steps.
@MainActor
final class AppCoordinator: NSObject {
    private let splitViewController = UISplitViewController()
    private let masterNavigationController = UINavigationController()
    private let container: DependencyContainer

    init(container: DependencyContainer) {
        self.container = container
        super.init()
        setupSplitView()
    }

    func rootViewController() -> UIViewController {
        return splitViewController
    }

    var albumViewController: AlbumViewController? {
        masterNavigationController.viewControllers.first as? AlbumViewController
    }

    private func setupSplitView() {
        splitViewController.delegate = self
        splitViewController.preferredDisplayMode = .oneBesideSecondary

        let albumVC = makeAlbumViewController()
        masterNavigationController.viewControllers = [albumVC]

        let photoGridVC = makeDefaultPhotoGridViewController()
        let detailNav = UINavigationController(rootViewController: photoGridVC)

        splitViewController.viewControllers = [masterNavigationController, detailNav]
    }
}

// MARK: - Navigation Central

extension AppCoordinator {
    func navigate(to route: AppRoute) {
        switch route {
        case let .photoGrid(fetchResult, collection, title):
            showPhotoGrid(fetchResult: fetchResult, collection: collection, title: title)

        case let .assetDetail(asset, collection, source):
            showAssetDetail(asset: asset, collection: collection, from: source)

        case let .settings(source):
            showSettings(from: source)

        case let .locationMap(location):
            openLocationMap(for: location)

        case let .metadataEdit(metadata, source):
            Task { await startEditFlow(for: metadata, from: source) }

        case let .locationSearch(source):
            presentLocationSearch(from: source)
        }
    }
}

// MARK: - VC Factory

extension AppCoordinator {
    fileprivate func makeAlbumViewController() -> AlbumViewController {
        let vc = AlbumViewController(container: container)
        vc.onSelectAlbum = { [weak self] fetchResult, collection, title in
            self?.navigate(to: .photoGrid(fetchResult: fetchResult, collection: collection, title: title))
        }
        vc.onRequestSettings = { [weak self, weak vc] in
            guard let vc else { return }
            self?.navigate(to: .settings(from: vc))
        }
        return vc
    }

    fileprivate func makeDefaultPhotoGridViewController() -> PhotoGridViewController {
        let vc = PhotoGridViewController(container: container)
        vc.title = String(localized: .viewAllPhotos)
        wirePhotoGridViewController(vc)
        return vc
    }

    fileprivate func makePhotoGridViewController(
        fetchResult: PHFetchResult<PHAsset>,
        collection: PHAssetCollection?,
        title: String
    ) -> PhotoGridViewController {
        let vc = PhotoGridViewController(container: container)
        vc.configureWithViewModel(fetchResult: fetchResult, collection: collection)
        vc.title = title
        wirePhotoGridViewController(vc)
        return vc
    }

    fileprivate func wirePhotoGridViewController(_ vc: PhotoGridViewController) {
        vc.onSelectAsset = { [weak self, weak vc] asset, collection in
            guard let vc else { return }
            self?.navigate(to: .assetDetail(asset: asset, collection: collection, source: vc))
        }
    }
}

// MARK: - Navigation (Internal)

extension AppCoordinator {
    fileprivate func showPhotoGrid(fetchResult: PHFetchResult<PHAsset>, collection: PHAssetCollection?, title: String) {
        let destination = makePhotoGridViewController(fetchResult: fetchResult, collection: collection, title: title)
        let nav = UINavigationController(rootViewController: destination)
        splitViewController.showDetailViewController(nav, sender: nil)
    }

    fileprivate func showAssetDetail(asset: PHAsset, collection: PHAssetCollection?, from source: UIViewController) {
        let detailVC = DetailInfoViewController(container: container)
        detailVC.configure(with: asset, collection: collection)

        detailVC.onRequestEdit = { [weak self, weak detailVC] metadata in
            guard let self, let detailVC else { return }
            self.navigate(to: .metadataEdit(metadata: metadata, source: detailVC))
        }
        detailVC.onRequestLocationMap = { [weak self] location in
            self?.navigate(to: .locationMap(location: location))
        }
        detailVC.requestSaveMode = { [weak self] presenter in
            await self?.pickSaveMode(on: presenter)
        }

        let nav = source.navigationController ?? masterNavigationController
        nav.pushViewController(detailVC, animated: true)
    }

    fileprivate func showSettings(from source: UIViewController) {
        let settingsVC = SettingsViewController(container: container)
        let wrapper = UINavigationController(rootViewController: settingsVC)
        source.present(wrapper, animated: true)
    }

    fileprivate func openLocationMap(for location: CLLocation) {
        let mapVC = UIViewController()
        mapVC.title = String(localized: .location)
        let fullMapView = MKMapView()
        fullMapView.translatesAutoresizingMaskIntoConstraints = false
        fullMapView.setRegion(
            MKCoordinateRegion(center: location.coordinate, latitudinalMeters: 1000, longitudinalMeters: 1000),
            animated: false
        )

        let annotation = MKPointAnnotation()
        annotation.coordinate = location.coordinate
        fullMapView.addAnnotation(annotation)

        mapVC.view.addSubview(fullMapView)
        NSLayoutConstraint.activate([
            fullMapView.topAnchor.constraint(equalTo: mapVC.view.topAnchor),
            fullMapView.leadingAnchor.constraint(equalTo: mapVC.view.leadingAnchor),
            fullMapView.trailingAnchor.constraint(equalTo: mapVC.view.trailingAnchor),
            fullMapView.bottomAnchor.constraint(equalTo: mapVC.view.bottomAnchor),
        ])

        let nav = UINavigationController(rootViewController: mapVC)
        mapVC.navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done, target: self, action: #selector(dismissMap)
        )
        masterNavigationController.present(nav, animated: true)
    }

    @objc fileprivate func dismissMap() {
        masterNavigationController.dismiss(animated: true)
    }

    fileprivate func presentLocationSearch(from source: MetadataEditViewController) {
        let searchVC = LocationSearchViewController(container: container)
        let nav = UINavigationController(rootViewController: searchVC)
        searchVC.onSelect = { [weak source] model in
            source?.updateLocation(from: model)
        }
        source.present(nav, animated: true)
    }
}

// MARK: - Flow Orchestration

extension AppCoordinator {
    fileprivate func startEditFlow(for metadata: Metadata, from source: DetailInfoViewController) async {
        let vc = MetadataEditViewController(metadata: metadata, container: container)
        let nav = UINavigationController(rootViewController: vc)

        vc.onRequestLocationSearch = { [weak self, weak vc] in
            guard let vc else { return }
            self?.navigate(to: .locationSearch(source: vc))
        }

        source.present(nav, animated: true) {
            nav.presentationController?.delegate = vc
        }

        while true {
            guard let fields = await awaitEditorResult(on: vc, source: source) else { return }
            guard let mode = await pickSaveMode(on: nav) else { continue }

            let success = await source.viewModel.applyMetadataFields(fields, saveMode: mode) { warning in
                await Alert.confirm(title: warning.title, message: warning.message, on: nav)
            }

            if success {
                source.dismiss(animated: true)
                return
            }
        }
    }
}

// MARK: - Async Presentation Bridges

extension AppCoordinator {
    fileprivate func pickSaveMode(on presenter: UIViewController? = nil) async -> SaveWorkflowMode? {
        let host = presenter ?? masterNavigationController

        return await withCheckedContinuation { (continuation: CheckedContinuation<SaveWorkflowMode?, Never>) in
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

            host.present(vc, animated: true)
        }
    }

    fileprivate func awaitEditorResult(
        on vc: MetadataEditViewController,
        source: UIViewController
    ) async -> [MetadataField: Any]? {
        await withCheckedContinuation { continuation in
            var isResumed = false
            vc.onSave = { fields in
                guard !isResumed else { return }
                isResumed = true
                continuation.resume(returning: fields)
            }
            vc.onCancel = { [weak source] in
                guard !isResumed else { return }
                isResumed = true
                source?.dismiss(animated: true)
                continuation.resume(returning: nil)
            }
        }
    }
}

// MARK: - UISplitViewControllerDelegate

extension AppCoordinator: UISplitViewControllerDelegate {
    func splitViewController(
        _ splitViewController: UISplitViewController,
        collapseSecondary secondaryViewController: UIViewController,
        onto primaryViewController: UIViewController
    ) -> Bool {
        return true
    }
}
