//
//  LocationSearchViewModelTests.swift
//  MetaXTests
//

import Foundation
import MapKit
@testable import MetaX
import Testing

// MARK: - Mocks

class MockHistoryService: LocationHistoryServiceProtocol {
    var history: [HistoryLocation] = []
    func save(_ location: HistoryLocation) {
        history.removeAll { $0.identifier == location.identifier }
        history.insert(location, at: 0)
        if history.count > 10 {
            history = Array(history.prefix(10))
        }
    }

    func fetchAll() -> [HistoryLocation] { history }
    func delete(at index: Int) {
        guard index < history.count else { return }
        history.remove(at: index)
    }

    func clearAll() { history.removeAll() }
}

class MockSearchService: LocationSearchServiceProtocol {
    var delegate: LocationSearchServiceDelegate?
    func search(query: String) {}
    @MainActor func resolve(at index: Int) async throws -> LocationModel {
        throw NSError(domain: "test", code: 0)
    }
}

// MARK: - Tests

@Suite("Location Search Tests")
@MainActor
struct LocationSearchViewModelTests {

    let historyService: MockHistoryService
    let searchService: MockSearchService
    let viewModel: LocationSearchViewModel

    init() {
        historyService = MockHistoryService()
        searchService = MockSearchService()
        viewModel = LocationSearchViewModel(historyService: historyService, searchService: searchService)
    }

    @Test("Initial state is empty")
    func initialState() {
        #expect(viewModel.sections.isEmpty)
        #expect(viewModel.isEmpty == true)
        #expect(searchService.delegate != nil) // VM registers itself as delegate during init
    }

    @Test("Shows history when search is empty")
    func showsHistory() {
        historyService.save(HistoryLocation(title: "Home", subtitle: "123 St", latitude: 0, longitude: 0))

        let newViewModel = LocationSearchViewModel(historyService: historyService, searchService: searchService)
        #expect(newViewModel.sections.count == 1)
        #expect(newViewModel.isEmpty == false)
    }

    @Test("Selecting history moves it to top")
    func historyReordering() async {
        let locA = HistoryLocation(title: "A", subtitle: "SubA", latitude: 1, longitude: 1)
        let locB = HistoryLocation(title: "B", subtitle: "SubB", latitude: 2, longitude: 2)
        historyService.save(locA)
        historyService.save(locB) // History: [B, A]

        let newViewModel = LocationSearchViewModel(historyService: historyService, searchService: searchService)
        _ = await newViewModel.selectItem(at: IndexPath(row: 1, section: 0)) // Select A

        #expect(historyService.fetchAll()[0].title == "A")
    }

    @Test("Delete history row")
    func deleteHistory() {
        historyService.save(HistoryLocation(title: "A", subtitle: "", latitude: 0, longitude: 0))
        viewModel.deleteHistory(at: 0)
        #expect(viewModel.isEmpty == true)
    }

    @Test("Error closure is triggered")
    func errorHandling() async {
        var receivedError: Error?
        viewModel.onError = { receivedError = $0 }

        searchService.delegate?.didFail(with: NSError(domain: "test", code: 1))
        await Task.yield()

        #expect(receivedError != nil)
    }

    @Test("Section switching logic")
    func sectionSwitching() async {
        // Create a fresh VM with one pre-loaded history item
        historyService.save(HistoryLocation(title: "H", subtitle: "", latitude: 0, longitude: 0))
        let vm = LocationSearchViewModel(historyService: historyService, searchService: searchService)

        // History mode: one section with a non-nil header title
        #expect(vm.sections.count == 1)
        #expect(vm.sections[0].title != nil)

        // Search mode: simulate search results arriving via delegate callback
        vm.searchText = "Tokyo"
        vm.didUpdate(results: [])
        await Task.yield()

        // Search section has no header title (regardless of result count)
        #expect(vm.sections.count == 1)
        #expect(vm.sections[0].title == nil)
    }
}
