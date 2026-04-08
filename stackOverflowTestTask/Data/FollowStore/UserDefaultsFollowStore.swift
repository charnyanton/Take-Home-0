//
//  UserDefaultsFollowStore.swift
//  stackOverflowTestTask
//
//  Created by Anton Charny on 08.04.2026.
//

import Foundation

final class UserDefaultsFollowStore: FollowStoreProtocol {
    private let userDefaults: UserDefaults
    private let key: String

    internal init(
        userDefaults: UserDefaults = .standard,
        key: String = "followed_user_ids"
    ) {
        self.userDefaults = userDefaults
        self.key = key
    }

    func followedUserIDs() -> Set<Int> {
        let storedUserIDs = self.userDefaults.array(forKey: self.key) as? [Int] ?? []
        return Set(storedUserIDs)
    }

    func setFollowed(_ isFollowed: Bool, for userID: Int) {
        var followedUserIDs = self.followedUserIDs()

        if isFollowed {
            followedUserIDs.insert(userID)
        } else {
            followedUserIDs.remove(userID)
        }

        self.userDefaults.set(Array(followedUserIDs).sorted(), forKey: self.key)
    }
}
