//
//  UserListViewController.swift
//  stackOverflowTestTask
//
//  Created by Anton Charny on 07.04.2026.
//

import UIKit

@MainActor
final class UserListViewController: UIViewController {
    // MARK: - Dependencies
    private let viewModel: UserListViewModel
    private let imageLoader: ImageLoadingProtocol
    // MARK: - UI
    private lazy var tableView = UITableView(frame: .zero, style: .plain)
    private lazy var messageLabel = UILabel()
    private lazy var activityIndicatorView = UIActivityIndicatorView(style: .large)

    private var items: [UserListItemViewData] = []

    internal init(viewModel: UserListViewModel, imageLoader: ImageLoadingProtocol) {
        self.viewModel = viewModel
        self.imageLoader = imageLoader
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.configureHierarchy()
        self.configureLayout()
        self.configureTableView()
        self.configureAppearance()
        self.bindViewModel()

        Task {
            await self.viewModel.load()
        }
    }

    private func bindViewModel() {
        self.viewModel.onStateChange = { [weak self] state in
            self?.render(state: state)
        }
    }

    private func render(state: UserListViewState) {
        switch state {
        case .idle:
            self.activityIndicatorView.stopAnimating()
            self.tableView.isHidden = true
            self.messageLabel.isHidden = true
        case .loading:
            self.activityIndicatorView.startAnimating()
            self.tableView.isHidden = true
            self.messageLabel.isHidden = true
        case let .content(items):
            self.activityIndicatorView.stopAnimating()
            self.items = items
            self.tableView.isHidden = false
            self.messageLabel.isHidden = true
            self.tableView.reloadData()
        case let .empty(message):
            self.activityIndicatorView.stopAnimating()
            self.items = []
            self.tableView.isHidden = true
            self.messageLabel.isHidden = false
            self.messageLabel.text = message
        }
    }

    private func configureHierarchy() {
        self.view.addSubview(self.tableView)
        self.view.addSubview(self.messageLabel)
        self.view.addSubview(self.activityIndicatorView)
    }

    private func configureLayout() {
        self.tableView.translatesAutoresizingMaskIntoConstraints = false
        self.messageLabel.translatesAutoresizingMaskIntoConstraints = false
        self.activityIndicatorView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            self.tableView.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor),
            self.tableView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            self.tableView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            self.tableView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),

            self.messageLabel.leadingAnchor.constraint(equalTo: self.view.layoutMarginsGuide.leadingAnchor),
            self.messageLabel.trailingAnchor.constraint(equalTo: self.view.layoutMarginsGuide.trailingAnchor),
            self.messageLabel.centerYAnchor.constraint(equalTo: self.view.centerYAnchor),

            self.activityIndicatorView.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            self.activityIndicatorView.centerYAnchor.constraint(equalTo: self.view.centerYAnchor),
        ])
    }

    private func configureTableView() {
        self.tableView.dataSource = self
        self.tableView.rowHeight = UITableView.automaticDimension
        self.tableView.estimatedRowHeight = 80
        self.tableView.separatorInset = UIEdgeInsets(top: 0, left: 84, bottom: 0, right: 16)
        self.tableView.register(UserListTableViewCell.self,
                                forCellReuseIdentifier: UserListTableViewCell.reuseIdentifier)
    }
    
    private func configureAppearance() {
        self.title = "Top StackOverflow Users"
        self.view.backgroundColor = .systemBackground

        self.messageLabel.isHidden = true
        self.messageLabel.numberOfLines = 0
        self.messageLabel.textAlignment = .center
        self.messageLabel.font = .preferredFont(forTextStyle: .body)
        self.messageLabel.textColor = .secondaryLabel
        self.messageLabel.adjustsFontForContentSizeCategory = true
    }
}

extension UserListViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        self.items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: UserListTableViewCell.reuseIdentifier,
            for: indexPath) as? UserListTableViewCell else {
            return UITableViewCell()
        }

        let item = self.items[indexPath.row]
        cell.configure(item: item, imageLoader: self.imageLoader)
        return cell
    }
}
