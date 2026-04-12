//
//  BatchChangeSummaryViewController.swift
//  MetaX
//
//  Created by Yuhan Chen on 2026/04/10.
//

import UIKit

@MainActor
final class BatchChangeSummaryViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    struct Row {
        let title: String
        let value: String?
    }

    struct Section {
        let title: String
        let rows: [Row]
    }

    private struct SummarySection {
        let title: String
        let rows: [DetailCellModel]
    }

    private enum DisplayRow {
        case header(String)
        case updateItem(DetailCellModel, isFirst: Bool, isLast: Bool)
        case clearItem(String, isFirst: Bool, isLast: Bool)
    }

    static func present(
        title: String,
        sections: [Section],
        confirmTitle: String,
        cancelTitle: String,
        on presenter: UIViewController
    ) async -> Bool {
        await withCheckedContinuation { continuation in
            let vc = BatchChangeSummaryViewController(
                titleText: title,
                sections: sections,
                confirmTitle: confirmTitle,
                cancelTitle: cancelTitle
            )
            vc.onDecision = { confirmed in
                continuation.resume(returning: confirmed)
            }

            let nav = UINavigationController(rootViewController: vc)
            if let sheet = nav.sheetPresentationController {
                sheet.detents = [.medium(), .large()]
                sheet.prefersGrabberVisible = true
                sheet.preferredCornerRadius = 20
            }
            presenter.present(nav, animated: true)
        }
    }

    private let titleText: String
    private let confirmTitle: String
    private let cancelTitle: String
    private let displayRows: [DisplayRow]
    private var onDecision: ((Bool) -> Void)?
    private var didResolve = false

    private let tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = Theme.Colors.mainBackground
        tableView.separatorStyle = .none
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 64
        tableView.sectionHeaderTopPadding = 0
        return tableView
    }()

    init(titleText: String, sections: [Section], confirmTitle: String, cancelTitle: String) {
        self.titleText = titleText
        self.confirmTitle = confirmTitle
        self.cancelTitle = cancelTitle
        let displaySections: [SummarySection] = sections.map { sourceSection in
            let isClearSection = sourceSection.rows.allSatisfy { $0.value == nil }
            return SummarySection(
                title: sourceSection.title,
                rows: sourceSection.rows.map { row in
                    DetailCellModel(
                        prop: row.title,
                        value: isClearSection ? "" : (row.value ?? "")
                    )
                }
            )
        }
        displayRows = displaySections.flatMap { summarySection in
            let isClearSection = summarySection.rows.allSatisfy(\.value.isEmpty)
            let items = summarySection.rows.enumerated().map { index, row in
                if isClearSection {
                    return DisplayRow.clearItem(
                        row.prop,
                        isFirst: index == 0,
                        isLast: index == summarySection.rows.count - 1
                    )
                } else {
                    return DisplayRow.updateItem(
                        row,
                        isFirst: index == 0,
                        isLast: index == summarySection.rows.count - 1
                    )
                }
            }
            return [.header(summarySection.title)] + items
        }
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if !didResolve {
            resolve(false)
        }
    }

    private func setupUI() {
        title = titleText
        view.backgroundColor = Theme.Colors.mainBackground

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: cancelTitle,
            style: .plain,
            target: self,
            action: #selector(cancelTapped)
        )
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: confirmTitle,
            style: .done,
            target: self,
            action: #selector(confirmTapped)
        )
        navigationItem.rightBarButtonItem?.tintColor = Theme.Colors.accent

        tableView.dataSource = self
        tableView.delegate = self
        tableView.contentInset = UIEdgeInsets(top: 12, left: 0, bottom: 24, right: 0)
        tableView.register(
            DetailTableViewCell.self,
            forCellReuseIdentifier: String(describing: DetailTableViewCell.self)
        )
        tableView.register(
            BatchChangeSummaryHeaderCell.self,
            forCellReuseIdentifier: String(describing: BatchChangeSummaryHeaderCell.self)
        )
        tableView.register(
            BatchChangeSummaryClearCell.self,
            forCellReuseIdentifier: String(describing: BatchChangeSummaryClearCell.self)
        )

        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    @objc private func cancelTapped() {
        didResolve = true
        dismiss(animated: true) { [weak self] in
            self?.resolve(false)
        }
    }

    @objc private func confirmTapped() {
        didResolve = true
        dismiss(animated: true) { [weak self] in
            self?.resolve(true)
        }
    }

    private func resolve(_ confirmed: Bool) {
        let handler = onDecision
        onDecision = nil
        guard let handler else { return }
        handler(confirmed)
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        displayRows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch displayRows[indexPath.row] {
        case let .header(title):
            guard let cell = tableView.dequeueReusableCell(
                withIdentifier: String(describing: BatchChangeSummaryHeaderCell.self),
                for: indexPath
            ) as? BatchChangeSummaryHeaderCell else {
                return UITableViewCell()
            }
            cell.configure(title: title)
            return cell
        case let .updateItem(model, isFirst, isLast):
            guard let cell = tableView.dequeueReusableCell(
                withIdentifier: String(describing: DetailTableViewCell.self),
                for: indexPath
            ) as? DetailTableViewCell else {
                return UITableViewCell()
            }

            cell.cellDataSource = model
            cell.applyCardBorders(isFirst: isFirst, isLast: isLast)
            return cell
        case let .clearItem(title, isFirst, isLast):
            guard let cell = tableView.dequeueReusableCell(
                withIdentifier: String(describing: BatchChangeSummaryClearCell.self),
                for: indexPath
            ) as? BatchChangeSummaryClearCell else {
                return UITableViewCell()
            }
            cell.configure(title: title, isFirst: isFirst, isLast: isLast)
            return cell
        }
    }
}

private final class BatchChangeSummaryHeaderCell: UITableViewCell {

    private let headerView = DetailSectionHeaderView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear

        headerView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(headerView)
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            headerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            headerView.heightAnchor.constraint(equalToConstant: Theme.Layout.sectionHeaderHeight),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError()
    }

    func configure(title: String) {
        headerView.headerTitle = title
    }
}

private final class BatchChangeSummaryClearCell: UITableViewCell {

    private let neoContainer = NeoBrutalistContainerView(contentPadding: 12)

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = Theme.Typography.bodyMedium
        label.textColor = Theme.Colors.text
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear

        neoContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(neoContainer)
        neoContainer.contentView.addSubview(titleLabel)

        let padding: CGFloat = 12
        let contentInset = padding + 1

        NSLayoutConstraint.activate([
            neoContainer.topAnchor.constraint(equalTo: contentView.topAnchor),
            neoContainer.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor,
                constant: Theme.Layout.standardPadding
            ),
            neoContainer.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor,
                constant: -Theme.Layout.standardPadding
            ),
            neoContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            titleLabel.topAnchor.constraint(equalTo: neoContainer.contentView.topAnchor, constant: padding),
            titleLabel.leadingAnchor.constraint(
                equalTo: neoContainer.contentView.leadingAnchor,
                constant: contentInset
            ),
            titleLabel.trailingAnchor.constraint(
                equalTo: neoContainer.contentView.trailingAnchor,
                constant: -contentInset
            ),
            titleLabel.bottomAnchor.constraint(equalTo: neoContainer.contentView.bottomAnchor, constant: -padding),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError()
    }

    func configure(title: String, isFirst: Bool, isLast: Bool) {
        titleLabel.text = title
        neoContainer.updateBorders(isFirst: isFirst, isLast: isLast)
    }
}
