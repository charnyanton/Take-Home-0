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
    private lazy var paginationFooterView = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 72))
    private lazy var paginationFooterLabel = UILabel()
    private lazy var sortBarButtonItem = UIBarButtonItem(
        title: UserListViewModel.Strings.sortButtonTitle,
        image: nil,
        primaryAction: nil,
        menu: nil
    )

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

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        self.viewModel.refreshFollowState()
    }

    private func bindViewModel() {
        self.viewModel.onStateChange = { [weak self] state in
            self?.render(state: state)
        }

        self.viewModel.onPaginationFooterStateChange = { [weak self] state in
            self?.render(paginationFooterState: state)
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

        self.updateSortMenu()
    }

    private func render(paginationFooterState: UserListPaginationFooterState) {
        switch paginationFooterState {
        case .hidden:
            self.tableView.tableFooterView = nil
        case let .message(message):
            self.paginationFooterLabel.text = message
            self.paginationFooterView.frame = CGRect(
                x: 0,
                y: 0,
                width: self.tableView.bounds.width,
                height: 72
            )
            self.tableView.tableFooterView = self.paginationFooterView
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
        self.tableView.delegate = self
        self.tableView.rowHeight = UITableView.automaticDimension
        self.tableView.estimatedRowHeight = 80
        self.tableView.separatorInset = UIEdgeInsets(top: 0, left: 84, bottom: 0, right: 120)
        self.tableView.register(UserListTableViewCell.self,
                                forCellReuseIdentifier: UserListTableViewCell.reuseIdentifier)

        self.paginationFooterView.addSubview(self.paginationFooterLabel)
        self.paginationFooterLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            self.paginationFooterLabel.topAnchor.constraint(equalTo: self.paginationFooterView.topAnchor, constant: 12),
            self.paginationFooterLabel.leadingAnchor.constraint(equalTo: self.paginationFooterView.layoutMarginsGuide.leadingAnchor),
            self.paginationFooterLabel.trailingAnchor.constraint(equalTo: self.paginationFooterView.layoutMarginsGuide.trailingAnchor),
            self.paginationFooterLabel.bottomAnchor.constraint(equalTo: self.paginationFooterView.bottomAnchor, constant: -12),
        ])
    }

    private func configureAppearance() {
        self.title = UserListViewModel.Strings.screenTitle
        self.navigationItem.rightBarButtonItem = self.sortBarButtonItem
        self.updateSortMenu()
        self.view.backgroundColor = .systemBackground

        self.messageLabel.isHidden = true
        self.messageLabel.numberOfLines = 0
        self.messageLabel.textAlignment = .center
        self.messageLabel.font = .preferredFont(forTextStyle: .body)
        self.messageLabel.textColor = .secondaryLabel
        self.messageLabel.adjustsFontForContentSizeCategory = true

        self.paginationFooterView.layoutMargins = UIEdgeInsets(top: 0, left: 24, bottom: 0, right: 24)
        self.paginationFooterLabel.numberOfLines = 0
        self.paginationFooterLabel.textAlignment = .center
        self.paginationFooterLabel.font = .preferredFont(forTextStyle: .footnote)
        self.paginationFooterLabel.textColor = .secondaryLabel
        self.paginationFooterLabel.adjustsFontForContentSizeCategory = true
    }

    private func updateSortMenu() {
        let sortActions = UserSortOption.allCases.map { option in
            UIAction(
                title: option.title,
                state: option == self.viewModel.selectedSortOption ? .on : .off
            ) { [weak self] _ in
                Task { @MainActor in
                    await self?.viewModel.selectSortOption(option)
                }
            }
        }

        let orderActions = UserSortOrder.allCases.map { order in
            UIAction(
                title: order.title,
                state: order == self.viewModel.selectedSortOrder ? .on : .off
            ) { [weak self] _ in
                Task { @MainActor in
                    await self?.viewModel.selectSortOrder(order)
                }
            }
        }

        self.sortBarButtonItem.menu = UIMenu(children: [
            UIMenu(
                title: UserListViewModel.Strings.sortByMenuTitle,
                options: .displayInline,
                children: sortActions
            ),
            UIMenu(
                title: UserListViewModel.Strings.orderMenuTitle,
                options: .displayInline,
                children: orderActions
            ),
        ])
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

        cell.configure(
            item: item,
            imageLoader: self.imageLoader,
            onFollowTap: { [weak self] in
                self?.viewModel.toggleFollow(for: item.id)
            }
        )
        return cell
    }
}

extension UserListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard self.items.indices.contains(indexPath.row) else {
            return
        }

        self.viewModel.goToDetailScreen(userModel: self.items[indexPath.row])
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard self.items.indices.contains(indexPath.row) else {
            return
        }

        let item = self.items[indexPath.row]
        Task { [weak self] in
            await self?.viewModel.loadNextPageIfNeeded(currentItemID: item.id)
        }
    }
}
