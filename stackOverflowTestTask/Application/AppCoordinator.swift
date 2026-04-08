//
//  AppCoordinator.swift
//  stackOverflowTestTask
//
//  Created by Anton Charny on 07.04.2026.
//

import UIKit

final class AppCoordinator {
    private let navigationController: UINavigationController

    internal init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }

    internal func start() {
        let httpClient = URLSessionHTTPClient(session: .shared)
        let usersRepository = UsersRepository(httpClient: httpClient)
        let imageLoader = RemoteImageLoader(session: .shared)
        let viewModel = UserListViewModel(usersRepository: usersRepository)
        let viewController = UserListViewController(viewModel: viewModel, imageLoader: imageLoader)

        self.navigationController.setViewControllers([viewController], animated: false)
    }
}
