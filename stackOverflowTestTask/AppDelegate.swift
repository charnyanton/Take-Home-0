//
//  AppDelegate.swift
//  stackOverflowTestTask
//
//  Created by Anton Charny on 07.04.2026.
//

import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    internal func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        return true
    }

    internal func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(
            name: "Default",
            sessionRole: connectingSceneSession.role
        )
        configuration.delegateClass = SceneDelegate.self
        configuration.storyboard = nil
        return configuration
    }

    internal func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {}
}
