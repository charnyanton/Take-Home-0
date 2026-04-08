//
//  UserListTableViewCell.swift
//  stackOverflowTestTask
//
//  Created by Anton Charny on 07.04.2026.
//

import UIKit

final class UserListTableViewCell: UITableViewCell {
    static let reuseIdentifier = "UserListTableViewCell"

    private lazy var avatarImageView = UIImageView()
    private lazy var nameLabel = UILabel()
    private lazy var reputationLabel = UILabel()
    private lazy var textStackView = UIStackView()

    private var imageTask: Task<Void, Never>?

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
        self.avatarImageView.image = UIImage(systemName: "person.crop.circle.fill")
        self.nameLabel.text = nil
        self.reputationLabel.text = nil
    }

    internal func configure(item: UserListItemViewData,
                            imageLoader: ImageLoadingProtocol) {
        self.nameLabel.text = item.displayName
        self.reputationLabel.text = item.reputationText

        self.imageTask?.cancel()
        self.imageTask = Task { [weak self] in
            let image = await imageLoader.loadImage(from: item.avatarURL)

            guard !Task.isCancelled else {
                return
            }

            self?.avatarImageView.image = image ?? UIImage(systemName: "person.crop.circle.fill")
        }
    }

    private func configureViewHierarchy() {
        self.contentView.addSubview(self.avatarImageView)
        self.contentView.addSubview(self.textStackView)
        self.textStackView.addArrangedSubview(self.nameLabel)
        self.textStackView.addArrangedSubview(self.reputationLabel)
    }

    private func configureLayout() {
        self.avatarImageView.translatesAutoresizingMaskIntoConstraints = false
        self.textStackView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            self.avatarImageView.leadingAnchor.constraint(equalTo: self.contentView.leadingAnchor, constant: 16),
            self.avatarImageView.topAnchor.constraint(equalTo: self.contentView.topAnchor, constant: 12),
            self.avatarImageView.bottomAnchor.constraint(equalTo: self.contentView.bottomAnchor, constant: -12),
            self.avatarImageView.widthAnchor.constraint(equalToConstant: 56),
            self.avatarImageView.heightAnchor.constraint(equalToConstant: 56),

            self.textStackView.leadingAnchor.constraint(equalTo: self.avatarImageView.trailingAnchor, constant: 12),
            self.textStackView.trailingAnchor.constraint(equalTo: self.contentView.trailingAnchor, constant: -16),
            self.textStackView.centerYAnchor.constraint(equalTo: self.contentView.centerYAnchor),
        ])
    }

    private func configureAppearance() {
        self.accessoryType = .disclosureIndicator
        self.selectionStyle = .none

        self.avatarImageView.contentMode = .scaleAspectFill
        self.avatarImageView.layer.cornerRadius = 28
        self.avatarImageView.clipsToBounds = true
        self.avatarImageView.tintColor = .systemGray
        self.avatarImageView.backgroundColor = .secondarySystemBackground
        self.avatarImageView.image = UIImage(systemName: "person.crop.circle.fill")

        self.textStackView.axis = .vertical
        self.textStackView.spacing = 4

        self.nameLabel.font = .preferredFont(forTextStyle: .headline)
        self.nameLabel.adjustsFontForContentSizeCategory = true
        self.nameLabel.numberOfLines = 2

        self.reputationLabel.font = .preferredFont(forTextStyle: .subheadline)
        self.reputationLabel.textColor = .secondaryLabel
        self.reputationLabel.adjustsFontForContentSizeCategory = true
    }
}
