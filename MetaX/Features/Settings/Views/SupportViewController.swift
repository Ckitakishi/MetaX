//
//  SupportViewController.swift
//  MetaX
//
//  Created by Yuhan Chen on 2026/02/25.
//

import UIKit

@MainActor
final class SupportViewController: UIViewController, ViewModelObserving {

    // MARK: - ViewModel

    private let viewModel: SupportViewModel

    // MARK: - UI Components

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        sv.alwaysBounceVertical = true
        sv.showsVerticalScrollIndicator = false
        return sv
    }()

    private let stackView: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.spacing = 40
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = String(localized: .settingsSupportMetaX)
        label.font = Theme.Typography.poster
        label.textColor = Theme.Colors.text
        label.textAlignment = .center
        return label
    }()

    private let descriptionLabel: UILabel = {
        let label = UILabel()
        let text = String(localized: .supportMessage)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 6
        paragraphStyle.alignment = .center

        let attributedString = NSAttributedString(string: text, attributes: [
            .font: Theme.Typography.body,
            .foregroundColor: UIColor.secondaryLabel,
            .paragraphStyle: paragraphStyle,
        ])

        label.attributedText = attributedString
        label.numberOfLines = 0
        return label
    }()

    private let productsStack: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.spacing = 24
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let headerIconView: UIImageView = {
        let config = UIImage.SymbolConfiguration(pointSize: 36, weight: .bold)
        let iv = UIImageView(image: UIImage(systemName: "heart.fill", withConfiguration: config))
        iv.tintColor = Theme.Colors.accent
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    private let juiceCell = SupportProductCell(title: String(localized: .supportProductAppleJuice) + " 🧃")
    private let pieCell = SupportProductCell(title: String(localized: .supportProductApplePie) + " 🥧")

    private let footerStack: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.spacing = 12
        sv.alignment = .center
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let legalDisclaimerLabel: UILabel = {
        let label = UILabel()
        label.text = String(localized: .supportLegalDisclaimer)
        label.font = Theme.Typography.hint
        label.textColor = .tertiaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private let linksStack: UIStackView = {
        let sv = UIStackView()
        sv.axis = .horizontal
        sv.spacing = 8
        sv.alignment = .center
        return sv
    }()

    // MARK: - Initialization

    init(viewModel: SupportViewModel) {
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

    // MARK: - UI Setup

    private func setupUI() {
        view.backgroundColor = Theme.Colors.mainBackground
        setupNavigationBar()

        view.addSubview(scrollView)
        view.addSubview(footerStack)
        scrollView.addSubview(stackView)

        let headerStack = UIStackView(arrangedSubviews: [headerIconView, titleLabel, descriptionLabel])
        headerStack.axis = .vertical
        headerStack.spacing = 12
        headerStack.setCustomSpacing(20, after: titleLabel)
        headerIconView.heightAnchor.constraint(equalToConstant: 44).isActive = true

        stackView.addArrangedSubview(headerStack)
        stackView.addArrangedSubview(productsStack)

        productsStack.addArrangedSubview(juiceCell)
        productsStack.addArrangedSubview(pieCell)

        footerStack.addArrangedSubview(legalDisclaimerLabel)
        footerStack.addArrangedSubview(linksStack)
        setupLinkButtons()

        NSLayoutConstraint.activate([
            footerStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            footerStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            footerStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),

            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: footerStack.topAnchor, constant: -20),

            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 60),
            stackView.leadingAnchor.constraint(
                equalTo: scrollView.frameLayoutGuide.leadingAnchor,
                constant: Theme.Layout.horizontalMargin
            ),
            stackView.trailingAnchor.constraint(
                equalTo: scrollView.frameLayoutGuide.trailingAnchor,
                constant: -Theme.Layout.horizontalMargin
            ),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -20),
        ])
    }

    private func setupNavigationBar() {
        guard navigationController?.viewControllers.count == 1 else { return }
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            primaryAction: UIAction { [weak self] _ in self?.dismiss(animated: true) }
        )
    }

    private func setupLinkButtons() {
        let termsBtn = makeLinkButton(
            title: String(localized: .settingsTermsOfService),
            url: AppConstants.termsOfServiceURL
        )
        let privacyBtn = makeLinkButton(
            title: String(localized: .settingsPrivacyPolicy),
            url: AppConstants.privacyPolicyURL
        )
        let dot = UILabel()
        dot.text = "•"; dot.font = Theme.Typography.footnote; dot.textColor = .tertiaryLabel
        linksStack.addArrangedSubview(termsBtn); linksStack.addArrangedSubview(dot); linksStack
            .addArrangedSubview(privacyBtn)
    }

    private func makeLinkButton(title: String, url: URL) -> UIButton {
        var config = UIButton.Configuration.plain()
        config.attributedTitle = AttributedString(title, attributes: .init([.font: Theme.Typography.footnote]))
        config.baseForegroundColor = .secondaryLabel
        config.contentInsets = .zero
        return UIButton(configuration: config, primaryAction: UIAction { _ in UIApplication.shared.open(url) })
    }

    private func setupBindings() {
        observe(viewModel: viewModel, property: { $0.tipProducts }) { [weak self] tipProducts in
            self?.updateTipProducts(tipProducts)
        }

        observe(viewModel: viewModel, property: { $0.isPurchasing }) { isPurchasing in
            if isPurchasing { HUD.showProcessing(with: String(localized: .viewProcessing)) }
            else { HUD.dismiss() }
        }

        observe(viewModel: viewModel, property: { $0.alertItem }) { [weak self] item in
            guard let self, let item else { return }
            self.showSupportAlert(item)
        }
    }

    private func showSupportAlert(_ item: SupportAlertItem) {
        Task {
            await Alert.show(title: item.title, message: item.message, on: self)
            viewModel.dismissAlert()
        }
    }

    private func updateTipProducts(_ tipProducts: [TipProduct]) {
        // tipProducts is ordered by AppConstants.allTipProductIDs; cells must match that order.
        for (cell, product) in zip([juiceCell, pieCell], tipProducts) {
            cell.update(price: product.price)
            cell.onTap = { [weak self] in self?.viewModel.purchase(id: product.id) }
        }
    }
}

// MARK: - SupportProductCell

final class SupportProductCell: UIView, NeoBrutalistPressable {
    var onTap: (() -> Void)?
    var targetView: UIView { cardView }

    private let cardView: UIView = {
        let v = UIView()
        v.isUserInteractionEnabled = false
        v.backgroundColor = Theme.Colors.cardBackground
        Theme.Shadows.applyCardBorder(to: v.layer)
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let nameLabel: UILabel = {
        let l = UILabel()
        l.font = Theme.Typography.bodyMedium
        l.textColor = Theme.Colors.text
        return l
    }()

    private let priceLabel: UILabel = {
        let l = UILabel()
        l.font = Theme.Typography.indexMono.withSize(18)
        l.textColor = Theme.Colors.accent
        l.textAlignment = .right
        l.isHidden = true
        return l
    }()

    private let priceLoadingIndicator: UIActivityIndicatorView = {
        let v = UIActivityIndicatorView(style: .medium)
        v.hidesWhenStopped = true
        return v
    }()

    private var isProductLoaded = false
    private var stackedLayer: UIView?

    init(title: String) {
        super.init(frame: .zero)
        nameLabel.text = title
        setupUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func update(price: String) {
        isProductLoaded = true
        priceLoadingIndicator.stopAnimating()
        priceLabel.text = price
        UIView.transition(with: priceLabel, duration: 0.2, options: .transitionCrossDissolve) {
            self.priceLabel.isHidden = false
        }
    }

    private func setupUI() {
        addSubview(cardView)
        stackedLayer = Theme.Shadows.applyStackedLayer(to: cardView, in: self)

        let content = UIStackView(arrangedSubviews: [nameLabel, priceLoadingIndicator, priceLabel])
        content.axis = .horizontal; content.spacing = 16; content.alignment = .center
        priceLoadingIndicator.startAnimating()
        content.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(content)

        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: topAnchor),
            cardView.leadingAnchor.constraint(equalTo: leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Theme.Shadows.layerOffset),
            cardView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Theme.Shadows.layerOffset),

            content.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 20),
            content.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
            content.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20),
            content.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -20),
        ])

        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: SupportProductCell, _) in
            Theme.Shadows.updateLayerColors(for: view.cardView.layer)
            if let shadow = view.stackedLayer { Theme.Shadows.updateLayerColors(for: shadow.layer) }
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        if isProductLoaded { handleTouchesBegan() }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        if isProductLoaded {
            handleTouchesEnded { [weak self] in self?.onTap?() }
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        handleTouchesCancelled()
    }
}
