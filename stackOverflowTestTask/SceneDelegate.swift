//
//  SceneDelegate.swift
//  stackOverflowTestTask
//
//  Created by Anton Charny on 07.04.2026.
//

import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    internal var window: UIWindow?
    private var appCoordinator: AppCoordinator?

    internal func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else {
            return
        }

        let navigationController = UINavigationController()
        navigationController.navigationBar.prefersLargeTitles = true

        let coordinator = AppCoordinator(navigationController: navigationController)
        coordinator.start()

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = navigationController
        window.makeKeyAndVisible()

        self.window = window
        self.appCoordinator = coordinator
    }
}
