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

    // MARK: - Properties

    var childCoordinators: [Coordinator] = []
    var navigationController: UINavigationController
    private let container: DependencyContainer
    private let splitViewController: UISplitViewController
    private let saveModePicker = SaveModePicker()

    /// Central navigation map for the Photo flow.
    enum PhotoRoute {
        case albumList
        case photoGrid(fetchResult: PHFetchResult<PHAsset>, collection: PHAssetCollection?, title: String)
        case assetDetail(asset: PHAsset, collection: PHAssetCollection?, source: UIViewController)
        case settings(from: UIViewController)
        case support(from: UIViewController)
        case metadataEdit(metadata: Metadata, source: DetailInfoViewController)
        case locationMap(location: CLLocation)
        case batchEdit(assets: [PHAsset], source: UIViewController)
        case batchClear(assets: [PHAsset], source: UIViewController)
    }

    // MARK: - Flow Controllers

    private lazy var locationSearchPresenter = LocationSearchPresenter(
        historyService: container.locationHistoryService,
        searchService: container.locationSearchService
    )

    private lazy var metadataEditFlow = MetadataEditFlowController(
        container: container,
        saveModePicker: saveModePicker,
        locationSearchPresenter: locationSearchPresenter
    )

    private lazy var batchEditFlow = BatchEditFlowController(
        container: container,
        saveModePicker: saveModePicker,
        locationSearchPresenter: locationSearchPresenter
    )

    // MARK: - Initialization

    init(
        navigationController: UINavigationController,
        splitViewController: UISplitViewController,
        container: DependencyContainer
    ) {
        self.navigationController = navigationController
        self.splitViewController = splitViewController
        self.container = container
    }

    // MARK: - Flow Control

    func start() {
        navigate(to: .albumList)

        // On iPad, default to All Photos grid in the secondary column on startup.
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
        case let .support(source):
            showSupport(from: source)
        case let .metadataEdit(metadata, source):
            Task { await metadataEditFlow.startEditFlow(for: metadata, from: source) }
        case let .locationMap(location):
            openLocationMap(for: location)
        case let .batchEdit(assets, source):
            Task { await batchEditFlow.startBatchEditFlow(assets: assets, from: source) }
        case let .batchClear(assets, source):
            Task { await batchEditFlow.startBatchClearFlow(assets: assets, from: source) }
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
        vc.onBatchEdit = { [weak self, weak vc] assets in
            guard let vc else { return }
            self?.navigate(to: .batchEdit(assets: assets, source: vc))
        }
        vc.onBatchClear = { [weak self, weak vc] assets in
            guard let vc else { return }
            self?.navigate(to: .batchClear(assets: assets, source: vc))
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
            navigate(to: .metadataEdit(metadata: metadata, source: vc))
        }
        vc.onRequestLocationMap = { [weak self] location in
            self?.navigate(to: .locationMap(location: location))
        }
        vc.requestSaveMode = { [weak self] presenter in
            guard let self else { return nil }
            let host = presenter ?? self.navigationController
            return await saveModePicker.pick(on: host)
        }

        let nav = source.navigationController ?? navigationController
        nav.pushViewController(vc, animated: true)
    }

    private func showSettings(from source: UIViewController) {
        let viewModel = SettingsViewModel(
            settingsService: container.settingsService
        )
        let vc = SettingsViewController(viewModel: viewModel)
        viewModel.onNavigateToSupport = { [weak self, weak vc] in
            guard let self, let vc else { return }
            self.navigate(to: .support(from: vc))
        }
        let wrapper = UINavigationController(rootViewController: vc)
        source.present(wrapper, animated: true)
    }

    private func showSupport(from source: UIViewController) {
        let viewModel = SupportViewModel(storeService: container.storeService)
        let vc = SupportViewController(viewModel: viewModel)

        if let nav = source.navigationController {
            nav.pushViewController(vc, animated: true)
        } else {
            let wrapper = UINavigationController(rootViewController: vc)
            source.present(wrapper, animated: true)
        }
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
}
