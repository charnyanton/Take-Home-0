//
//  AppCoordinator.swift
//  stackOverflowTestTask
//
//  Created by Anton Charny on 07.04.2026.
//

import UIKit

final class AppCoordinator {
    private let navigationController: UINavigationController

    private let followStore: FollowStoreProtocol
    private let imageLoader: ImageLoadingProtocol

    internal init(navigationController: UINavigationController) {
        self.navigationController = navigationController
        self.followStore = UserDefaultsFollowStore()
        self.imageLoader = RemoteImageLoader(session: .shared)
    }

    internal func start() {
        let httpClient = URLSessionHTTPClient(session: .shared)
        let usersRepository = UsersRepository(httpClient: httpClient)
        let viewModel = UserListViewModel(
            usersRepository: usersRepository,
            followStore: self.followStore,
            onUserDetailTap: { [weak self] user in
                self?.showUserDetailScreen(user: user)
            })
        let viewController = UserListViewController(viewModel: viewModel, imageLoader: self.imageLoader)

        self.navigationController.setViewControllers([viewController], animated: false)
    }

    internal func showUserDetailScreen(user: StackUser) {
        let detailsViewModel = UserDetailViewModel(
            userModel: user,
            followStore: self.followStore
        )
        let detailsController = UserDetailViewController(viewModel: detailsViewModel, imageLoader: self.imageLoader)

        self.navigationController.pushViewController(detailsController, animated: true)
    }
}
