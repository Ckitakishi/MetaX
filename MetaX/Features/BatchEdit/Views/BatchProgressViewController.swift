//
//  BatchProgressViewController.swift
//  MetaX
//
//  Created by Yuhan Chen on 2026/03/27.
//  Copyright © 2026 Yuhan Chen. All rights reserved.
//

import UIKit

private final class FilmstripProgressView: UIView {
    private let segmentCount = 12
    private var segmentViews: [UIView] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        setupUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError()
    }

    func setProgress(_ progress: Float, animated: Bool) {
        let clamped = max(0, min(1, progress))
        let activeSegments = Int(round(clamped * Float(segmentCount)))
        let updates = {
            for (index, segment) in self.segmentViews.enumerated() {
                segment.backgroundColor = index < activeSegments ? Theme.Colors.accent : Theme.Colors.cardBackground
            }
        }

        if animated {
            UIView.animate(withDuration: 0.2, animations: updates)
        } else {
            updates()
        }
    }

    private func setupUI() {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .fill
        stack.distribution = .fillEqually
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            heightAnchor.constraint(equalToConstant: 20),
        ])

        for _ in 0..<segmentCount {
            let segment = UIView()
            segment.backgroundColor = Theme.Colors.cardBackground
            segment.translatesAutoresizingMaskIntoConstraints = false
            Theme.Shadows.applyCardBorder(to: segment.layer)
            stack.addArrangedSubview(segment)
            segmentViews.append(segment)
        }
    }
}

/// Displays progress during batch metadata operations.
@MainActor
final class BatchProgressViewController: UIViewController, ViewModelObserving {

    private enum ActionMode {
        case cancel
        case close
    }

    var onCancel: (() -> Void)?
    var onFinishAcknowledged: (() -> Void)?

    private let viewModel: BatchEditViewModel
    private let totalCount: Int
    private var stackedLayer: UIView?
    private var actionMode: ActionMode = .cancel
    private var isCancellationPending = false

    private var headerForegroundColor: UIColor {
        Theme.Colors.cardBackground
    }

    // MARK: - UI

    private let blurView: UIVisualEffectView = {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
        view.alpha = 0.55
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let dimmingView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let cardView: UIView = {
        let view = UIView()
        view.backgroundColor = Theme.Colors.cardBackground
        Theme.Shadows.applyCardBorder(to: view.layer)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let headerBar: UIView = {
        let view = UIView()
        view.backgroundColor = Theme.Colors.accent.withAlphaComponent(0.9)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let headerDivider: UIView = {
        let view = UIView()
        view.backgroundColor = Theme.Colors.border
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let headerIconView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.preferredSymbolConfiguration = .init(pointSize: 12, weight: .bold)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let headerLabel: UILabel = {
        let label = UILabel()
        label.font = Theme.Typography.captionMono.withSize(13)
        label.textAlignment = .left
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.font = Theme.Typography.subheadline
        label.textColor = Theme.Colors.text
        label.textAlignment = .left
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let detailLabel: UILabel = {
        let label = UILabel()
        label.font = Theme.Typography.body
        label.textColor = Theme.Colors.text.withAlphaComponent(0.72)
        label.textAlignment = .left
        label.numberOfLines = 0
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let headerCountLabel: UILabel = {
        let label = UILabel()
        label.font = Theme.Typography.captionMono.withSize(13)
        label.textAlignment = .center
        label.numberOfLines = 1
        label.backgroundColor = .clear
        label.layer.borderWidth = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let progressView = FilmstripProgressView()

    private lazy var actionButton: UIButton = {
        var config = UIButton.Configuration.gray()
        config.baseForegroundColor = Theme.Colors.text
        config.background.backgroundColor = Theme.Colors.cardBackground
        config.background.strokeColor = Theme.Colors.border
        config.background.strokeWidth = 1.0
        config.cornerStyle = .fixed
        config.background.cornerRadius = 0
        config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 18, bottom: 10, trailing: 18)
        config.titleAlignment = .center
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = Theme.Typography.captionMono.withSize(13)
            return outgoing
        }

        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(actionTapped), for: .touchUpInside)
        return button
    }()

    // MARK: - Initialization

    init(viewModel: BatchEditViewModel, totalCount: Int) {
        self.viewModel = viewModel
        self.totalCount = totalCount
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError()
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupBindings()
        updateThemeColors()
    }

    private func setupUI() {
        view.backgroundColor = .clear
        isModalInPresentation = true

        view.addSubview(blurView)
        view.addSubview(dimmingView)
        view.addSubview(cardView)
        cardView.addSubview(headerBar)
        headerBar.addSubview(headerIconView)
        headerBar.addSubview(headerLabel)
        headerBar.addSubview(headerCountLabel)
        cardView.addSubview(headerDivider)
        cardView.addSubview(statusLabel)
        cardView.addSubview(detailLabel)
        cardView.addSubview(progressView)
        cardView.addSubview(actionButton)

        NSLayoutConstraint.activate([
            blurView.topAnchor.constraint(equalTo: view.topAnchor),
            blurView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            dimmingView.topAnchor.constraint(equalTo: view.topAnchor),
            dimmingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dimmingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            dimmingView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            cardView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            cardView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            cardView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            cardView.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            headerBar.topAnchor.constraint(equalTo: cardView.topAnchor),
            headerBar.leadingAnchor.constraint(equalTo: cardView.leadingAnchor),
            headerBar.trailingAnchor.constraint(equalTo: cardView.trailingAnchor),
            headerBar.heightAnchor.constraint(equalToConstant: 44),

            headerIconView.leadingAnchor.constraint(equalTo: headerBar.leadingAnchor, constant: 16),
            headerIconView.centerYAnchor.constraint(equalTo: headerBar.centerYAnchor),
            headerIconView.widthAnchor.constraint(equalToConstant: 14),
            headerIconView.heightAnchor.constraint(equalToConstant: 14),

            headerLabel.leadingAnchor.constraint(equalTo: headerIconView.trailingAnchor, constant: 8),
            headerLabel.centerYAnchor.constraint(equalTo: headerBar.centerYAnchor),
            headerLabel.trailingAnchor.constraint(lessThanOrEqualTo: headerCountLabel.leadingAnchor, constant: -12),

            headerCountLabel.trailingAnchor.constraint(equalTo: headerBar.trailingAnchor, constant: -16),
            headerCountLabel.centerYAnchor.constraint(equalTo: headerBar.centerYAnchor),
            headerCountLabel.heightAnchor.constraint(equalToConstant: 22),
            headerCountLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 56),

            headerDivider.topAnchor.constraint(equalTo: headerBar.bottomAnchor),
            headerDivider.leadingAnchor.constraint(equalTo: cardView.leadingAnchor),
            headerDivider.trailingAnchor.constraint(equalTo: cardView.trailingAnchor),
            headerDivider.heightAnchor.constraint(equalToConstant: 1),

            statusLabel.topAnchor.constraint(equalTo: headerDivider.bottomAnchor, constant: 34),
            statusLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 28),
            statusLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -28),

            detailLabel.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 12),
            detailLabel.leadingAnchor.constraint(equalTo: statusLabel.leadingAnchor),
            detailLabel.trailingAnchor.constraint(equalTo: statusLabel.trailingAnchor),

            progressView.topAnchor.constraint(equalTo: detailLabel.bottomAnchor, constant: 28),
            progressView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 28),
            progressView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -28),

            actionButton.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 40),
            actionButton.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 28),
            actionButton.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -28),
            actionButton.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -24),
            actionButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
        ])

        stackedLayer = Theme.Shadows.applyStackedLayer(to: cardView, in: view, color: Theme.Colors.tagBackground)

        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (
            self: BatchProgressViewController,
            _: UITraitCollection
        ) in
            self.updateThemeColors()
        }

        updateProgress(completed: 0, total: totalCount)
    }

    private func updateThemeColors() {
        Theme.Shadows.updateLayerColors(for: cardView.layer)
        if let stackedLayer {
            Theme.Shadows.updateLayerColors(for: stackedLayer.layer)
        }
        headerIconView.tintColor = headerForegroundColor
        headerLabel.textColor = headerForegroundColor
        headerCountLabel.textColor = headerForegroundColor
        headerCountLabel.layer.borderColor = headerForegroundColor.cgColor
        headerDivider.backgroundColor = Theme.Colors.border
    }

    private func setupBindings() {
        observe(viewModel: viewModel, property: { $0.state }) { [weak self] state in
            guard let self else { return }
            switch state {
            case .idle:
                break
            case let .processing(completed, total):
                updateProgress(completed: completed, total: total)
            case let .finished(result):
                updateFinishedState(result)
            }
        }
    }

    private func updateProgress(completed: Int, total: Int) {
        actionMode = .cancel
        headerIconView.image = UIImage(systemName: "square.stack.3d.forward.dottedline")
        headerLabel.text = String(localized: .viewProcessing).uppercased()
        headerCountLabel.text = "\(completed) / \(total)"
        statusLabel.text = String(localized: .batchProgressRunningHint)
        detailLabel.text = nil
        detailLabel.isHidden = true
        progressView.isHidden = false
        progressView.setProgress(total > 0 ? Float(completed) / Float(total) : 0, animated: true)
        configureActionButton(
            title: String(localized: .batchStop),
            isEnabled: !isCancellationPending
        )
        isModalInPresentation = true
    }

    private func updateFinishedState(_ result: BatchEditViewModel.BatchResult) {
        isCancellationPending = false
        let processedCount = result.succeeded + result.failed
        headerIconView.image = finishedIcon(for: result)
        headerLabel.text = finishedTitle(for: result).uppercased()
        headerCountLabel.text = "\(processedCount) / \(totalCount)"
        let message = finishedMessage(for: result)
        statusLabel.text = message.primary
        detailLabel.text = message.secondary
        detailLabel.isHidden = message.secondary == nil

        let progress: Float
        if totalCount == 0 {
            progress = 1
        } else {
            progress = result.cancelled ? Float(processedCount) / Float(totalCount) : 1
        }
        progressView.setProgress(progress, animated: true)

        actionMode = .close
        configureActionButton(title: String(localized: .batchClose))
        isModalInPresentation = false
    }

    private func finishedTitle(for result: BatchEditViewModel.BatchResult) -> String {
        if result.cancelled {
            return String(localized: .batchCancelled)
        }
        if result.failed == 0 {
            return String(localized: .batchComplete)
        }
        if result.succeeded == 0 {
            return String(localized: .batchFailed)
        }
        return String(localized: .batchCompleteWithIssues)
    }

    private func finishedIcon(for result: BatchEditViewModel.BatchResult) -> UIImage? {
        if result.cancelled {
            return UIImage(systemName: "pause.circle")
        }
        if result.failed == 0 {
            return UIImage(systemName: "checkmark.circle")
        }
        if result.succeeded == 0 {
            return UIImage(systemName: "xmark.circle")
        }
        return UIImage(systemName: "exclamationmark.circle")
    }

    private func finishedMessage(for result: BatchEditViewModel.BatchResult) -> (primary: String, secondary: String?) {
        let errorHint = result.failed > 0 ? String(localized: .batchErrorDetailsMessage) : nil
        if result.cancelled {
            let processedCount = result.succeeded + result.failed
            return (String(localized: .batchCancelledProgress(processedCount, totalCount)), errorHint)
        }
        if result.failed == 0 {
            return (String(localized: .batchAllSucceeded(totalCount)), nil)
        }
        if result.succeeded == 0 {
            return (String(localized: .batchAllFailed(totalCount)), errorHint)
        }
        return (String(localized: .batchPartialSuccess(result.succeeded, totalCount)), errorHint)
    }

    private func configureActionButton(title: String, isEnabled: Bool = true) {
        var config = actionButton.configuration ?? .gray()
        config.title = title
        config.baseForegroundColor = Theme.Colors.text
        config.background.backgroundColor = Theme.Colors.cardBackground
        config.background.strokeColor = Theme.Colors.border
        config.background.strokeWidth = 1.0
        config.background.cornerRadius = 0
        actionButton.configuration = config
        actionButton.isEnabled = isEnabled
        actionButton.alpha = isEnabled ? 1 : 0.55
    }

    @objc private func actionTapped() {
        switch actionMode {
        case .cancel:
            guard !isCancellationPending else { return }
            isCancellationPending = true
            configureActionButton(title: String(localized: .batchStop), isEnabled: false)
            onCancel?()
        case .close:
            onFinishAcknowledged?()
        }
    }
}
