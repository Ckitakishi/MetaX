//
//  DependencyContainer.swift
//  MetaX
//
//  Created by Chen Yuhan on 2026/02/07.
//  Copyright © 2026 Chen Yuhan. All rights reserved.
//

import Foundation

/// Central dependency injection container managing the lifecycle of app services.
@MainActor
final class DependencyContainer {

    // MARK: - Services

    let photoLibraryService: PhotoLibraryServiceProtocol
    let metadataService: MetadataServiceProtocol
    let imageSaveService: ImageSaveServiceProtocol
    let locationHistoryService: LocationHistoryServiceProtocol
    let locationSearchService: LocationSearchServiceProtocol
    let settingsService: SettingsServiceProtocol
    let storeService: StoreServiceProtocol
    let tippingManager: TippingManager

    // MARK: - Initialization

    init() {
        let photoLibrary = PhotoLibraryService()
        let settings = SettingsService()

        photoLibraryService = photoLibrary
        metadataService = MetadataService()
        imageSaveService = ImageSaveService(photoLibraryService: photoLibrary)
        locationHistoryService = LocationHistoryService()
        locationSearchService = LocationSearchService()
        settingsService = settings
        storeService = StoreService()
        tippingManager = TippingManager(settingsService: settings)
    }
}
