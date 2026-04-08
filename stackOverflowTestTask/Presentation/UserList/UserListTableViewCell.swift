//
//  UserListTableViewCell.swift
//  stackOverflowTestTask
//
//  Created by Anton Charny on 07.04.2026.
//

import UIKit

final class UserListTableViewCell: UITableViewCell {
    private enum Strings {
        static let followBadgeTitle = "Following"
        static let placeholderImageName = "person.crop.circle.fill"
        static let followBadgeImageName = "checkmark.circle.fill"
    }

    internal static let reuseIdentifier = "UserListTableViewCell"

    private lazy var avatarImageView = UIImageView()
    private lazy var nameLabel = UILabel()
    private lazy var nameRowStackView = UIStackView()
    private lazy var reputationLabel = UILabel()
    private lazy var followBadgeImageView = UIImageView()
    private lazy var followBadgeLabel = UILabel()
    private lazy var textStackView = UIStackView()
    private lazy var followButton = UIButton(type: .system)

    private var imageTask: Task<Void, Never>?
    private var onFollowTap: (() -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.configureViewHierarchy()
        self.configureLayout()
        self.configureAppearance()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        self.imageTask?.cancel()
        self.imageTask = nil
        self.onFollowTap = nil
        self.avatarImageView.image = UIImage(systemName: Strings.placeholderImageName)
        self.nameLabel.text = nil
        self.reputationLabel.text = nil
        self.followBadgeImageView.isHidden = true
        self.followBadgeLabel.isHidden = true
        self.followButton.configuration = nil
    }

    internal func configure(
        item: UserListItemViewData,
        imageLoader: ImageLoadingProtocol,
        onFollowTap: @escaping () -> Void
    ) {
        self.onFollowTap = onFollowTap
        self.nameLabel.text = item.displayName
        self.reputationLabel.text = item.reputationText
        self.followBadgeImageView.isHidden = !item.isFollowed
        self.followBadgeLabel.isHidden = !item.isFollowed
        self.applyFollowButtonStyle(title: item.followButtonTitle, isFollowed: item.isFollowed)

        self.imageTask?.cancel()
        self.imageTask = Task { [weak self] in
            let image = await imageLoader.loadImage(from: item.avatarURL)

            guard !Task.isCancelled else {
                return
            }

            self?.avatarImageView.image = image ?? UIImage(systemName: Strings.placeholderImageName)
        }
    }

    private func configureViewHierarchy() {
        self.contentView.addSubview(self.avatarImageView)
        self.contentView.addSubview(self.textStackView)
        self.contentView.addSubview(self.followButton)
        self.textStackView.addArrangedSubview(self.nameRowStackView)
        self.textStackView.addArrangedSubview(self.reputationLabel)
        self.nameRowStackView.addArrangedSubview(self.nameLabel)
        self.nameRowStackView.addArrangedSubview(self.followBadgeLabel)
        self.nameRowStackView.addArrangedSubview(self.followBadgeImageView)
    }

    private func configureLayout() {
        self.avatarImageView.translatesAutoresizingMaskIntoConstraints = false
        self.textStackView.translatesAutoresizingMaskIntoConstraints = false
        self.followButton.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            self.avatarImageView.leadingAnchor.constraint(equalTo: self.contentView.leadingAnchor, constant: 16),
            self.avatarImageView.topAnchor.constraint(greaterThanOrEqualTo: self.contentView.topAnchor, constant: 12),
            self.avatarImageView.bottomAnchor.constraint(lessThanOrEqualTo: self.contentView.bottomAnchor, constant: -12),
            self.avatarImageView.centerYAnchor.constraint(equalTo: self.contentView.centerYAnchor),
            self.avatarImageView.widthAnchor.constraint(equalToConstant: 56),
            self.avatarImageView.heightAnchor.constraint(equalToConstant: 56),

            self.textStackView.leadingAnchor.constraint(equalTo: self.avatarImageView.trailingAnchor, constant: 12),
            self.textStackView.trailingAnchor.constraint(lessThanOrEqualTo: self.followButton.leadingAnchor, constant: -12),
            self.textStackView.centerYAnchor.constraint(equalTo: self.contentView.centerYAnchor),

            self.followButton.trailingAnchor.constraint(equalTo: self.contentView.trailingAnchor, constant: -16),
            self.followButton.centerYAnchor.constraint(equalTo: self.contentView.centerYAnchor),
        ])
    }

    private func configureAppearance() {
        self.selectionStyle = .none

        self.avatarImageView.contentMode = .scaleAspectFill
        self.avatarImageView.layer.cornerRadius = 28
        self.avatarImageView.clipsToBounds = true
        self.avatarImageView.tintColor = .systemGray
        self.avatarImageView.backgroundColor = .secondarySystemBackground
        self.avatarImageView.image = UIImage(systemName: Strings.placeholderImageName)

        self.textStackView.axis = .vertical
        self.textStackView.spacing = 4
        self.textStackView.alignment = .leading

        self.nameRowStackView.axis = .horizontal
        self.nameRowStackView.alignment = .center
        self.nameRowStackView.spacing = 6

        self.nameLabel.font = .preferredFont(forTextStyle: .headline)
        self.nameLabel.adjustsFontForContentSizeCategory = true
        self.nameLabel.numberOfLines = 1
        self.nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        self.reputationLabel.font = .preferredFont(forTextStyle: .subheadline)
        self.reputationLabel.textColor = .secondaryLabel
        self.reputationLabel.adjustsFontForContentSizeCategory = true

        self.followBadgeImageView.image = UIImage(systemName: Strings.followBadgeImageName)
        self.followBadgeImageView.tintColor = .systemGreen
        self.followBadgeImageView.isHidden = true
        self.followBadgeImageView.setContentHuggingPriority(.required, for: .horizontal)

        self.followBadgeLabel.text = Strings.followBadgeTitle
        self.followBadgeLabel.font = .preferredFont(forTextStyle: .caption1)
        self.followBadgeLabel.textColor = .systemGreen
        self.followBadgeLabel.adjustsFontForContentSizeCategory = true
        self.followBadgeLabel.isHidden = true
        self.followBadgeLabel.setContentHuggingPriority(.required, for: .horizontal)

        self.followButton.setContentHuggingPriority(.required, for: .horizontal)
        self.followButton.addTarget(self, action: #selector(self.didTapFollowButton), for: .touchUpInside)
    }

    private func applyFollowButtonStyle(title: String, isFollowed: Bool) {
        var configuration = UIButton.Configuration.tinted()
        configuration.buttonSize = .small
        configuration.cornerStyle = .capsule
        configuration.title = title
        configuration.baseForegroundColor = isFollowed ? .systemRed : .systemBlue
        self.followButton.configuration = configuration
    }

    @objc
    private func didTapFollowButton() {
        self.onFollowTap?()
    }
}
