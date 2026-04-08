//
//  StackUser.swift
//  stackOverflowTestTask
//
//  Created by Anton Charny on 07.04.2026.
//

import Foundation

struct StackUser: Equatable, Sendable {
    internal let id: Int
    internal let displayName: String
    internal let reputation: Int
    internal let avatarURL: URL?
}

#if DEBUG
extension StackUser {
    internal static func fixture(
        id: Int = 1,
        displayName: String = "John Doe",
        reputation: Int = 1_234_567,
        avatarURL: URL? = URL(string: "https://example.com/avatar.png")
    ) -> StackUser {
        StackUser(
            id: id,
            displayName: displayName,
            reputation: reputation,
            avatarURL: avatarURL
        )
    }
}
#endif
