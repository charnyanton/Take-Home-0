//
//  UsersResponseDTO.swift
//  stackOverflowTestTask
//
//  Created by Anton Charny on 08.04.2026.
//

import Foundation

struct UsersResponseDTO: Decodable {
    internal let items: [UserDTO]
    internal let hasMore: Bool?
}

struct UserDTO: Decodable {
    internal let userId: Int
    internal let displayName: String
    internal let reputation: Int
    internal let profileImage: URL?
    internal let location: String?
    internal let websiteUrl: String?
    internal let creationDate: TimeInterval?
    internal let lastModifiedDate: TimeInterval?

    internal var stackUser: StackUser {
        StackUser(
            id: self.userId,
            displayName: self.displayName,
            reputation: self.reputation,
            avatarURL: self.profileImage,
            location: self.location,
            websiteURL: URL(string: self.websiteUrl ?? ""),
            creationDate: self.creationDate.map(Date.init(timeIntervalSince1970:)),
            lastModifiedDate: self.lastModifiedDate.map(Date.init(timeIntervalSince1970:))
        )
    }
}
