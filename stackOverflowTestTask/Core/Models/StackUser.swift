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
    internal let location: String?
    internal let websiteURL: URL?
    internal let creationDate: Date?
    internal let lastModifiedDate: Date?

    internal init(
        id: Int,
        displayName: String,
        reputation: Int,
        avatarURL: URL?,
        location: String? = nil,
        websiteURL: URL? = nil,
        creationDate: Date? = nil,
        lastModifiedDate: Date? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.reputation = reputation
        self.avatarURL = avatarURL
        self.location = location
        self.websiteURL = websiteURL
        self.creationDate = creationDate
        self.lastModifiedDate = lastModifiedDate
    }
}

#if DEBUG
extension StackUser {
    internal static func fixture(
        id: Int = 1,
        displayName: String = "John Doe",
        reputation: Int = 1_234_567,
        avatarURL: URL? = URL(string: "https://example.com/avatar.png"),
        location: String? = "New York, United States",
        websiteURL: URL? = URL(string: "https://example.com"),
        creationDate: Date? = Date(timeIntervalSince1970: 1_234_567_890),
        lastModifiedDate: Date? = Date(timeIntervalSince1970: 1_345_678_901)
    ) -> StackUser {
        StackUser(
            id: id,
            displayName: displayName,
            reputation: reputation,
            avatarURL: avatarURL,
            location: location,
            websiteURL: websiteURL,
            creationDate: creationDate,
            lastModifiedDate: lastModifiedDate
        )
    }
}
#endif
