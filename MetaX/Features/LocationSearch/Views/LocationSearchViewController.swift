//
//  LocationSearchViewController.swift
//  MetaX
//
//  Created by Ckitakishi on 2018/04/11.
//  Copyright © 2018 Yuhan Chen. All rights reserved.
//

import MapKit
import UIKit

class LocationSearchViewController: UIViewController, ViewModelObserving, UITextFieldDelegate {

    // MARK: - ViewModel

    private let viewModel: LocationSearchViewModel

    // MARK: - UI Components

    private let searchBarContainer: UIView = {
        let view = UIView()
        view.backgroundColor = Theme.Colors.mainBackground
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let searchTextField: UITextField = {
        let tf = UITextField()
        tf.backgroundColor = Theme.Colors.tagBackground
        tf.layer.borderWidth = 2
        tf.layer.borderColor = Theme.Colors.border.cgColor
        tf.layer.cornerRadius = 0
        tf.font = Theme.Typography.bodyMedium
        tf.placeholder = String(localized: .searchAddress)
        tf.autocorrectionType = .no
        tf.returnKeyType = .search
        tf.clearButtonMode = .whileEditing

        // Left padding with icon
        let iconView = UIImageView(image: UIImage(systemName: "magnifyingglass"))
        iconView.tintColor = .secondaryLabel
        iconView.contentMode = .center
        let padding = UIView(frame: CGRect(x: 0, y: 0, width: 40, height: 44))
        iconView.frame = CGRect(x: 10, y: 0, width: 24, height: 44)
        padding.addSubview(iconView)
        tf.leftView = padding
        tf.leftViewMode = .always

        tf.translatesAutoresizingMaskIntoConstraints = false
        return tf
    }()

    private let tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .grouped)
        table.backgroundColor = .clear
        table.separatorStyle = .none
        table.showsVerticalScrollIndicator = false
        table.translatesAutoresizingMaskIntoConstraints = false
        return table
    }()

    private let emptyStateLabel: UILabel = {
        let label = UILabel()
        label.text = String(localized: .searchEmptyHint)
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = Theme.Typography.bodyMedium
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isHidden = true
        return label
    }()

    var onSelect: ((LocationModel) -> Void)?
    var onCancel: (() -> Void)?

    private var isSearchActive: Bool {
        !(searchTextField.text?.isEmpty ?? true)
    }

    // MARK: - Initialization

    init(viewModel: LocationSearchViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupBindings()
    }

    private func setupUI() {
        title = String(localized: .searchLocation)
        view.backgroundColor = Theme.Colors.mainBackground

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancel)
        )

        view.addSubview(searchBarContainer)
        searchBarContainer.addSubview(searchTextField)
        view.addSubview(tableView)
        view.addSubview(emptyStateLabel)

        searchTextField.delegate = self
        searchTextField.addTarget(self, action: #selector(searchTextChanged), for: .editingChanged)

        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(
            LocationTableViewCell.self,
            forCellReuseIdentifier: String(describing: LocationTableViewCell.self)
        )
        tableView.keyboardDismissMode = .onDrag

        NSLayoutConstraint.activate([
            searchBarContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            searchBarContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchBarContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            searchBarContainer.heightAnchor.constraint(equalToConstant: 64),

            searchTextField.topAnchor.constraint(equalTo: searchBarContainer.topAnchor, constant: 10),
            searchTextField.leadingAnchor.constraint(equalTo: searchBarContainer.leadingAnchor, constant: 16),
            searchTextField.trailingAnchor.constraint(equalTo: searchBarContainer.trailingAnchor, constant: -16),
            searchTextField.bottomAnchor.constraint(equalTo: searchBarContainer.bottomAnchor, constant: -10),

            tableView.topAnchor.constraint(equalTo: searchBarContainer.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyStateLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -20),
            emptyStateLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            emptyStateLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
        ])

        // Auto-focus search bar
        searchTextField.becomeFirstResponder()

        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (
            self: LocationSearchViewController,
            _: UITraitCollection
        ) in
            self.searchTextField.layer.borderColor = Theme.Colors.border.cgColor
        }
    }

    // MARK: - Bindings

    private func setupBindings() {
        observe(viewModel: viewModel, property: { $0.searchResults }) { [weak self] _ in
            self?.updateUI()
        }

        observe(viewModel: viewModel, property: { $0.history }) { [weak self] _ in
            self?.updateUI()
        }

        observe(viewModel: viewModel, property: { $0.error }) { error in
            if let error = error {
                HUD.showError(with: error.localizedDescription)
            }
        }
    }

    private func updateUI() {
        tableView.reloadData()

        if isSearchActive {
            emptyStateLabel.isHidden = !viewModel.searchResults.isEmpty
        } else {
            emptyStateLabel.isHidden = !viewModel.history.isEmpty
        }
    }

    // MARK: - Actions

    @objc private func cancel() {
        dismiss(animated: true) { [weak self] in
            self?.onCancel?()
        }
    }

    @objc private func searchTextChanged() {
        viewModel.search(query: searchTextField.text ?? "")
    }

    // MARK: - UITextFieldDelegate

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

// MARK: - UITableViewDataSource

extension LocationSearchViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if isSearchActive { return nil }
        return viewModel.history.isEmpty ? nil : String(localized: .viewRecentHistory).uppercased()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return isSearchActive ? viewModel.searchResults.count : viewModel.history.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: String(describing: LocationTableViewCell.self),
            for: indexPath
        ) as? LocationTableViewCell else {
            return UITableViewCell()
        }

        if isSearchActive {
            cell.cellDataSource = viewModel.searchResults[indexPath.row]
        } else {
            let item = viewModel.history[indexPath.row]
            cell.cellDataSource = LocationModel(title: item.title, subtitle: item.subtitle)
        }
        return cell
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return !isSearchActive
    }

    func tableView(
        _ tableView: UITableView,
        commit editingStyle: UITableViewCell.EditingStyle,
        forRowAt indexPath: IndexPath
    ) {
        if editingStyle == .delete {
            viewModel.deleteHistory(at: indexPath.row)
        }
    }
}

// MARK: - UITableViewDelegate

extension LocationSearchViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        if isSearchActive {
            // Resolve first while the VC (and its ViewModel) are still alive,
            // then dismiss once we have a result. The original pattern of dismissing
            // first caused the ViewModel to be deallocated before MKLocalSearch
            // could complete, so the callback (and history save) never fired.
            view.isUserInteractionEnabled = false
            Task {
                let locationModel = await viewModel.selectLocation(at: indexPath.row)
                view.isUserInteractionEnabled = true
                guard let model = locationModel else { return }
                dismiss(animated: true) {
                    self.onSelect?(model)
                }
            }
        } else {
            if let model = viewModel.selectHistory(at: indexPath.row) {
                dismiss(animated: true) { [weak self] in
                    self?.onSelect?(model)
                }
            }
        }
    }
}
