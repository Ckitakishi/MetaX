//
//  SettingsViewController.swift
//  MetaX
//
//  Created by Yuhan Chen on 2026/02/15.
//

import UIKit

final class SettingsViewController: UIViewController {

    // MARK: - ViewModel

    private let viewModel: SettingsViewModel

    // MARK: - Properties

    private let tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .grouped)
        tv.backgroundColor = .clear
        tv.separatorStyle = .none
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()

    // MARK: - Initialization

    init(viewModel: SettingsViewModel) {
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
    }

    // MARK: - UI Setup

    private func setupUI() {
        title = String(localized: .settingsTitle)
        view.backgroundColor = Theme.Colors.mainBackground

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            style: .plain,
            target: self,
            action: #selector(didTapClose)
        )

        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(
            SettingsTableViewCell.self,
            forCellReuseIdentifier: String(describing: SettingsTableViewCell.self)
        )
    }

    @objc private func didTapClose() {
        dismiss(animated: true)
    }
}

// MARK: - UITableViewDataSource & Delegate

extension SettingsViewController: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int {
        return SettingsSection.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let settingsSection = SettingsSection.allCases[section]
        return viewModel.items(for: settingsSection).count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: String(describing: SettingsTableViewCell.self),
            for: indexPath
        ) as? SettingsTableViewCell
        let settingsCell = cell ?? SettingsTableViewCell(
            style: .default,
            reuseIdentifier: String(describing: SettingsTableViewCell.self)
        )

        let section = SettingsSection.allCases[indexPath.section]
        let items = viewModel.items(for: section)
        if indexPath.row < items.count {
            settingsCell.configure(with: items[indexPath.row])
        }

        return settingsCell
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let settingsCell = cell as? SettingsTableViewCell else { return }
        let rowCount = tableView.numberOfRows(inSection: indexPath.section)
        settingsCell.applyCardBorders(
            isFirst: indexPath.row == 0,
            isLast: indexPath.row == rowCount - 1
        )
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerView = DetailSectionHeaderView()
        let settingsSection = SettingsSection.allCases[section]
        headerView.headerTitle = settingsSection.title
        headerView.indicatorColor = viewModel.color(for: settingsSection)
        return headerView
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return Theme.Layout.sectionHeaderHeight
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let section = SettingsSection.allCases[indexPath.section]
        let items = viewModel.items(for: section)

        guard indexPath.row < items.count else { return }
        let item = items[indexPath.row]

        if item.type == .appearance {
            showAppearanceMenu(at: indexPath)
        } else {
            viewModel.performAction(for: item, from: self)
        }
    }

    private func showAppearanceMenu(at indexPath: IndexPath) {
        let options: [(String, String, UIUserInterfaceStyle)] = [
            (String(localized: .settingsAppearanceSystem), "circle.lefthalf.filled", .unspecified),
            (String(localized: .settingsAppearanceLight), "sun.max", .light),
            (String(localized: .settingsAppearanceDark), "moon", .dark),
        ]

        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

        for (name, icon, style) in options {
            let action = UIAlertAction(title: name, style: .default) { [weak self] _ in
                self?.viewModel.updateAppearance(style)
                self?.tableView.reloadRows(at: [indexPath], with: .none)
            }
            if let image = UIImage(systemName: icon) {
                action.setValue(image, forKey: "image")
            }
            alert.addAction(action)
        }

        alert.addAction(UIAlertAction(title: String(localized: .alertCancel), style: .cancel))

        if let cell = tableView.cellForRow(at: indexPath) {
            alert.popoverPresentationController?.sourceView = cell
            alert.popoverPresentationController?.sourceRect = cell.bounds
        }

        present(alert, animated: true)
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 20
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return UIView()
    }
}
