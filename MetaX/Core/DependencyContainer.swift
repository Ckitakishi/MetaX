//
//  DependencyContainer.swift
//  MetaX
//
//  Created by Chen Yuhan on 2026/02/07.
//  Copyright © 2026 Chen Yuhan. All rights reserved.
//

import Foundation

/// Central dependency injection container
/// Manages lifecycle of all services used throughout the app
final class DependencyContainer {

    // MARK: - Services

    let photoLibraryService: PhotoLibraryServiceProtocol
    let metadataService: MetadataServiceProtocol
    let imageSaveService: ImageSaveServiceProtocol

    // MARK: - Initialization

    init() {
        let photoLibrary = PhotoLibraryService()
        self.photoLibraryService = photoLibrary
        self.metadataService = MetadataService()
        self.imageSaveService = ImageSaveService(photoLibraryService: photoLibrary)
    }
}
