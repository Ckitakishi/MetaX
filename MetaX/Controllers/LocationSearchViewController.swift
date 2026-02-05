//
//  LocationSearchViewController.swift
//  MetaX
//
//  Created by Ckitakishi on 2018/04/11.
//  Copyright © 2018年 Yuhan Chen. All rights reserved.
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

    // MARK: - Properties

    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var listTableView: UITableView!

    weak var delegate: LocationSearchDelegate?

    // MARK: - Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        searchBar.delegate = self
        listTableView.delegate = self
        listTableView.dataSource = self
        listTableView.keyboardDismissMode = .onDrag

        setupBindings()
    }

    // MARK: - Bindings

    private func setupBindings() {
        observe(viewModel: viewModel, property: { $0.searchResults }) { [weak self] _ in
            self?.listTableView.reloadData()
        }

        observe(viewModel: viewModel, property: { $0.error }) { [weak self] error in
            if let error = error {
                SVProgressHUD.showCustomErrorHUD(with: error.localizedDescription)
            }
        }
    }

    // MARK: - Actions

    @IBAction func cancel(_ sender: UIBarButtonItem) {
        dismiss(animated: true, completion: nil)
    }

    @IBAction func neighborSearch(_ sender: UIBarButtonItem) {
        viewModel.requestLocationAuthorization()
    }
}

// MARK: - UISearchBarDelegate

extension LocationSearchViewController: UISearchBarDelegate {

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        viewModel.search(query: searchText)
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
