//
//  UsersResponseDTO.swift
//  stackOverflowTestTask
//
//  Created by Anton Charny on 08.04.2026.
//

import Foundation

struct UsersResponseDTO: Decodable {
    internal let items: [UserDTO]
}

struct UserDTO: Decodable {
    internal let userId: Int
    internal let displayName: String
    internal let reputation: Int
    internal let profileImage: URL?

    internal var stackUser: StackUser {
        StackUser(
            id: self.userId,
            displayName: self.displayName,
            reputation: self.reputation,
            avatarURL: self.profileImage
        )
    }
}
