//
//  PhotoFlowCoordinator.swift
//  MetaX
//

import CoreLocation
import MapKit
import Photos
import UIKit

@MainActor
final class PhotoFlowCoordinator: NSObject, Coordinator {
    var childCoordinators: [Coordinator] = []
    var navigationController: UINavigationController
    private let container: DependencyContainer
    private let splitViewController: UISplitViewController

    /// Central navigation map for the Photo flow.
    enum PhotoRoute {
        case albumList
        case photoGrid(fetchResult: PHFetchResult<PHAsset>, collection: PHAssetCollection?, title: String)
        case assetDetail(asset: PHAsset, collection: PHAssetCollection?, source: UIViewController)
        case settings(from: UIViewController)
        case metadataEdit(metadata: Metadata, source: DetailInfoViewController)
        case locationSearch(source: MetadataEditViewController)
        case locationMap(location: CLLocation)
    }

    init(
        navigationController: UINavigationController,
        splitViewController: UISplitViewController,
        container: DependencyContainer
    ) {
        self.navigationController = navigationController
        self.splitViewController = splitViewController
        self.container = container
    }

    func start() {
        navigate(to: .albumList)

        // On iPad, default to All Photos grid in the secondary column on startup
        if UIDevice.current.userInterfaceIdiom == .pad {
            let fetchResult = container.photoLibraryService.fetchAllPhotos()
            navigate(to: .photoGrid(
                fetchResult: fetchResult,
                collection: nil,
                title: String(localized: .viewAllPhotos)
            ))
        }
    }

    /// The single entry point for all navigation within this flow.
    func navigate(to route: PhotoRoute) {
        switch route {
        case .albumList:
            showAlbumList()
        case let .photoGrid(fetchResult, collection, title):
            showPhotoGrid(fetchResult: fetchResult, collection: collection, title: title)
        case let .assetDetail(asset, collection, source):
            showAssetDetail(asset: asset, collection: collection, from: source)
        case let .settings(source):
            showSettings(from: source)
        case let .metadataEdit(metadata, source):
            Task { await startEditFlow(for: metadata, from: source) }
        case let .locationSearch(source):
            presentLocationSearch(from: source)
        case let .locationMap(location):
            openLocationMap(for: location)
        }
    }

    // MARK: - Navigation Implementations

    private func showAlbumList() {
        let viewModel = AlbumViewModel(photoLibraryService: container.photoLibraryService)
        let vc = AlbumViewController(viewModel: viewModel)
        vc.onSelectAlbum = { [weak self] fetchResult, collection, title in
            self?.navigate(to: .photoGrid(fetchResult: fetchResult, collection: collection, title: title))
        }
        vc.onRequestSettings = { [weak self, weak vc] in
            guard let vc else { return }
            self?.navigate(to: .settings(from: vc))
        }
        navigationController.viewControllers = [vc]
    }

    private func showPhotoGrid(fetchResult: PHFetchResult<PHAsset>, collection: PHAssetCollection?, title: String) {
        let viewModel = PhotoGridViewModel(photoLibraryService: container.photoLibraryService)
        viewModel.configure(with: fetchResult, collection: collection)

        let vc = PhotoGridViewController(viewModel: viewModel)
        vc.title = title
        vc.onSelectAsset = { [weak self, weak vc] asset, collection in
            guard let vc else { return }
            self?.navigate(to: .assetDetail(asset: asset, collection: collection, source: vc))
        }

        let detailNav = UINavigationController(rootViewController: vc)
        splitViewController.showDetailViewController(detailNav, sender: nil)
    }

    private func showAssetDetail(asset: PHAsset, collection: PHAssetCollection?, from source: UIViewController) {
        let viewModel = DetailInfoViewModel(
            metadataService: container.metadataService,
            imageSaveService: container.imageSaveService,
            photoLibraryService: container.photoLibraryService
        )
        viewModel.configure(with: asset, collection: collection)

        let vc = DetailInfoViewController(viewModel: viewModel)
        vc.onRequestEdit = { [weak self, weak vc] metadata in
            guard let self, let vc else { return }
            self.navigate(to: .metadataEdit(metadata: metadata, source: vc))
        }
        vc.onRequestLocationMap = { [weak self] location in
            self?.navigate(to: .locationMap(location: location))
        }
        vc.requestSaveMode = { [weak self] presenter in
            await self?.pickSaveMode(on: presenter)
        }

        let nav = source.navigationController ?? navigationController
        nav.pushViewController(vc, animated: true)
    }

    private func showSettings(from source: UIViewController) {
        let viewModel = SettingsViewModel(
            photoLibraryService: container.photoLibraryService,
            settingsService: container.settingsService
        )
        let vc = SettingsViewController(viewModel: viewModel)
        let wrapper = UINavigationController(rootViewController: vc)
        source.present(wrapper, animated: true)
    }

    private func openLocationMap(for location: CLLocation) {
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
        navigationController.present(nav, animated: true)
    }

    @objc private func dismissMap() {
        navigationController.dismiss(animated: true)
    }

    private func startEditFlow(for metadata: Metadata, from source: DetailInfoViewController) async {
        let viewModel = MetadataEditViewModel(metadata: metadata)
        let vc = MetadataEditViewController(metadata: metadata, viewModel: viewModel)
        let nav = UINavigationController(rootViewController: vc)
        if UIDevice.current.userInterfaceIdiom == .pad {
            nav.modalPresentationStyle = .fullScreen
        }

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

            let success = await source.applyMetadataFields(fields, saveMode: mode) { warning in
                await Alert.confirm(title: warning.title, message: warning.message, on: nav)
            }

            if success {
                source.dismiss(animated: true)
                return
            }
        }
    }

    private func presentLocationSearch(from source: MetadataEditViewController) {
        let viewModel = LocationSearchViewModel(
            historyService: container.locationHistoryService,
            searchService: container.locationSearchService
        )
        let vc = LocationSearchViewController(viewModel: viewModel)
        let nav = UINavigationController(rootViewController: vc)
        vc.onSelect = { [weak source] model in
            source?.updateLocation(from: model)
        }
        source.present(nav, animated: true)
    }

    // MARK: - Utils

    private func pickSaveMode(on presenter: UIViewController? = nil) async -> SaveWorkflowMode? {
        let host = presenter ?? navigationController
        return await withCheckedContinuation { (continuation: CheckedContinuation<SaveWorkflowMode?, Never>) in
            let onceGuard = OnceGuard(continuation)
            let vc = SaveOptionsViewController()
            if UIDevice.current.userInterfaceIdiom == .pad {
                vc.modalPresentationStyle = .pageSheet
            }
            vc.onSelect = { mode in
                onceGuard.resume(returning: mode)
            }
            vc.onCancel = {
                onceGuard.resume(returning: nil)
            }
            host.present(vc, animated: true)
        }
    }

    private func awaitEditorResult(
        on vc: MetadataEditViewController,
        source: UIViewController
    ) async -> [MetadataField: MetadataFieldValue]? {
        await withCheckedContinuation { (continuation: CheckedContinuation<
            [MetadataField: MetadataFieldValue]?,
            Never
        >) in
            let onceGuard = OnceGuard(continuation)
            vc.onSave = { fields in
                onceGuard.resume(returning: fields)
            }
            vc.onCancel = { [weak source] in
                source?.dismiss(animated: true)
                onceGuard.resume(returning: nil)
            }
        }
    }
}
