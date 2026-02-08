//
//  LocationSearchViewController.swift
//  MetaX
//
//  Created by Ckitakishi on 2018/04/11.
//  Copyright © 2018 Yuhan Chen. All rights reserved.
//

import UIKit
import MapKit
import SVProgressHUD

protocol LocationSearchDelegate: AnyObject {
    func didSelect(_ model: LocationModel)
}

class LocationSearchViewController: UIViewController, ViewModelObserving {

    // MARK: - ViewModel
    private let viewModel = LocationSearchViewModel()

    // MARK: - UI Components
    private let tableView: UITableView = {
        let table = UITableView()
        table.translatesAutoresizingMaskIntoConstraints = false
        return table
    }()

    private let searchController = UISearchController(searchResultsController: nil)

    weak var delegate: LocationSearchDelegate?

    // MARK: - Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupBindings()
    }

    private func setupUI() {
        title = String(localized: .searchLocation)
        view.backgroundColor = .systemBackground

        // Navigation Bar
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
        navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "location.fill"), style: .plain, target: self, action: #selector(neighborSearch))

        // Search Controller
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = String(localized: .searchAddress)
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        definesPresentationContext = true

        // TableView
        view.addSubview(tableView)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(LocationTableViewCell.self, forCellReuseIdentifier: String(describing: LocationTableViewCell.self))
        tableView.keyboardDismissMode = .onDrag

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    // MARK: - Bindings
    private func setupBindings() {
        observe(viewModel: viewModel, property: { $0.searchResults }) { [weak self] _ in
            self?.tableView.reloadData()
        }

        observe(viewModel: viewModel, property: { $0.error }) { [weak self] error in
            if let error = error {
                SVProgressHUD.showCustomErrorHUD(with: error.localizedDescription)
            }
        }
    }

    // MARK: - Actions
    @objc private func cancel() {
        dismiss(animated: true, completion: nil)
    }

    @objc private func neighborSearch() {
        viewModel.requestLocationAuthorization()
    }
}

// MARK: - UISearchResultsUpdating
extension LocationSearchViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        viewModel.search(query: searchController.searchBar.text ?? "")
    }
}

// MARK: - UITableViewDataSource
extension LocationSearchViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.searchResults.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: String(describing: LocationTableViewCell.self),
            for: indexPath
        ) as? LocationTableViewCell else {
            return UITableViewCell()
        }

        if indexPath.row < viewModel.searchResults.count {
            cell.cellDataSource = viewModel.searchResults[indexPath.row]
        }
        return cell
    }
}

// MARK: - UITableViewDelegate
extension LocationSearchViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        dismiss(animated: true) { [weak self] in
            self?.viewModel.selectLocation(at: indexPath.row) { locationModel in
                if let model = locationModel {
                    self?.delegate?.didSelect(model)
                }
            }
        }
    }
}
