//
//  UserDetailViewController.swift
//  stackOverflowTestTask
//
//  Created by Anton Charny on 15.04.2026.
//

import UIKit

final class UserDetailViewController: UIViewController {
    private enum Strings {
        static let placeholderImageName = "person.crop.circle.fill"
    }

    private lazy var scrollView = UIScrollView()
    private lazy var contentView = UIView()
    private lazy var avatarImageView = UIImageView()
    private lazy var labelsStackView = UIStackView()
    private lazy var nameLabel = UILabel()
    private lazy var reputationLabel = UILabel()
    private lazy var followStatusLabel = UILabel()
    private lazy var locationLabel = UILabel()
    private lazy var websiteURLLabel = UILabel()
    private lazy var followButton = UIButton(type: .system)

    private let viewModel: UserDetailViewModel

    private let imageLoader: ImageLoadingProtocol

    private var imageTask: Task<Void, Never>?

    init(viewModel: UserDetailViewModel,
         imageLoader: ImageLoadingProtocol) {
        self.viewModel = viewModel
        self.imageLoader = imageLoader
        super.init(nibName: nil, bundle: nil)
    }

    deinit {
        self.imageTask?.cancel()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.configureHierarchy()
        self.configureLayout()
        self.configureAppearance()
        self.bindViewModel()
        self.viewModel.load()
    }

    private func bindViewModel() {
        self.viewModel.onStateChange = { [weak self] state in
            self?.render(state: state)
        }
    }

    private func render(state: UserDetailViewState) {
        switch state {
        case let .content(viewData):
            self.title = viewData.displayName
            self.nameLabel.text = viewData.displayName
            self.reputationLabel.text = viewData.reputationText
            self.followStatusLabel.text = viewData.followStatusText
            self.locationLabel.text = viewData.locationText
            self.websiteURLLabel.text = viewData.websiteText
            self.websiteURLLabel.isHidden = viewData.websiteText == nil
            self.applyFollowButtonStyle(title: viewData.followButtonTitle, isFollowed: viewData.isFollowed)
            self.loadImage(from: viewData.avatarURL)
        }
    }

    private func configureHierarchy() {
        self.view.addSubview(self.scrollView)
        self.scrollView.addSubview(self.contentView)
        self.contentView.addSubview(self.avatarImageView)
        self.contentView.addSubview(self.labelsStackView)
        self.contentView.addSubview(self.followButton)

        self.labelsStackView.addArrangedSubview(self.nameLabel)
        self.labelsStackView.addArrangedSubview(self.reputationLabel)
        self.labelsStackView.addArrangedSubview(self.followStatusLabel)
        self.labelsStackView.addArrangedSubview(self.locationLabel)
        self.labelsStackView.addArrangedSubview(self.websiteURLLabel)
    }

    private func configureLayout() {
        self.scrollView.translatesAutoresizingMaskIntoConstraints = false
        self.contentView.translatesAutoresizingMaskIntoConstraints = false
        self.avatarImageView.translatesAutoresizingMaskIntoConstraints = false
        self.labelsStackView.translatesAutoresizingMaskIntoConstraints = false
        self.followButton.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            self.scrollView.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor),
            self.scrollView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            self.scrollView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            self.scrollView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),

            self.contentView.topAnchor.constraint(equalTo: self.scrollView.contentLayoutGuide.topAnchor),
            self.contentView.leadingAnchor.constraint(equalTo: self.scrollView.contentLayoutGuide.leadingAnchor),
            self.contentView.trailingAnchor.constraint(equalTo: self.scrollView.contentLayoutGuide.trailingAnchor),
            self.contentView.bottomAnchor.constraint(equalTo: self.scrollView.contentLayoutGuide.bottomAnchor),
            self.contentView.widthAnchor.constraint(equalTo: self.scrollView.frameLayoutGuide.widthAnchor),

            self.avatarImageView.topAnchor.constraint(equalTo: self.contentView.topAnchor, constant: 32),
            self.avatarImageView.centerXAnchor.constraint(equalTo: self.contentView.centerXAnchor),
            self.avatarImageView.widthAnchor.constraint(equalToConstant: 128),
            self.avatarImageView.heightAnchor.constraint(equalToConstant: 128),

            self.labelsStackView.topAnchor.constraint(equalTo: self.avatarImageView.bottomAnchor, constant: 24),
            self.labelsStackView.leadingAnchor.constraint(equalTo: self.contentView.layoutMarginsGuide.leadingAnchor),
            self.labelsStackView.trailingAnchor.constraint(equalTo: self.contentView.layoutMarginsGuide.trailingAnchor),

            self.followButton.topAnchor.constraint(equalTo: self.labelsStackView.bottomAnchor, constant: 24),
            self.followButton.centerXAnchor.constraint(equalTo: self.contentView.centerXAnchor),
            self.followButton.bottomAnchor.constraint(lessThanOrEqualTo: self.contentView.bottomAnchor, constant: -32),
        ])
    }

    private func configureAppearance() {
        self.view.backgroundColor = .systemBackground
        self.contentView.layoutMargins = UIEdgeInsets(top: 0, left: 24, bottom: 0, right: 24)

        self.avatarImageView.contentMode = .scaleAspectFill
        self.avatarImageView.layer.cornerRadius = 64
        self.avatarImageView.clipsToBounds = true
        self.avatarImageView.tintColor = .systemGray
        self.avatarImageView.backgroundColor = .secondarySystemBackground
        self.avatarImageView.image = UIImage(systemName: Strings.placeholderImageName)

        self.labelsStackView.axis = .vertical
        self.labelsStackView.alignment = .center
        self.labelsStackView.spacing = 12

        self.configureLabel(self.nameLabel, font: .preferredFont(forTextStyle: .title2), textColor: .label)
        self.nameLabel.textAlignment = .center
        self.nameLabel.font = .preferredFont(forTextStyle: .title2)

        self.configureLabel(self.reputationLabel, font: .preferredFont(forTextStyle: .body), textColor: .secondaryLabel)
        self.configureLabel(self.followStatusLabel, font: .preferredFont(forTextStyle: .body), textColor: .secondaryLabel)
        self.configureLabel(self.locationLabel, font: .preferredFont(forTextStyle: .body), textColor: .secondaryLabel)
        self.configureLabel(self.websiteURLLabel, font: .preferredFont(forTextStyle: .body), textColor: .link)

        self.followButton.addTarget(self, action: #selector(self.didTapFollowButton), for: .touchUpInside)
    }

    private func configureLabel(_ label: UILabel, font: UIFont, textColor: UIColor) {
        label.font = font
        label.textColor = textColor
        label.numberOfLines = 0
        label.textAlignment = .center
        label.adjustsFontForContentSizeCategory = true
    }

    private func applyFollowButtonStyle(title: String, isFollowed: Bool) {
        var configuration = UIButton.Configuration.tinted()
        configuration.buttonSize = .medium
        configuration.cornerStyle = .capsule
        configuration.title = title
        configuration.baseForegroundColor = isFollowed ? .systemRed : .systemBlue
        self.followButton.configuration = configuration
    }

    private func loadImage(from url: URL?) {
        self.imageTask?.cancel()
        self.imageTask = Task { [weak self] in
            guard let self else {
                return
            }
            let image = await self.imageLoader.loadImage(from: url)

            guard !Task.isCancelled else {
                return
            }

            self.avatarImageView.image = image ?? UIImage(systemName: Strings.placeholderImageName)
        }
    }

    @objc
    private func didTapFollowButton() {
        self.viewModel.toggleFollow()
    }
}
