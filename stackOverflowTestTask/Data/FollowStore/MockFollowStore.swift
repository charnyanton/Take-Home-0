//
//  MockFollowStore.swift
//  stackOverflowTestTask
//
//  Created by Anton Charny on 08.04.2026.
//
import Foundation

final class MockFollowStore: FollowStoreProtocol {
    struct SetFollowedCall: Equatable {
        internal let isFollowed: Bool
        internal let userID: Int
    }

    private var storedFollowedUserIDs: Set<Int>

    internal private(set) var recordedSetFollowedCalls: [SetFollowedCall] = []

    internal init(followedUserIDs: Set<Int> = []) {
        self.storedFollowedUserIDs = followedUserIDs
    }

    func followedUserIDs() -> Set<Int> {
        return self.storedFollowedUserIDs
    }

    func setFollowed(_ isFollowed: Bool, for userID: Int) {
        self.recordedSetFollowedCalls.append(SetFollowedCall(isFollowed: isFollowed, userID: userID))

        if isFollowed {
            self.storedFollowedUserIDs.insert(userID)
        } else {
            self.storedFollowedUserIDs.remove(userID)
        }
    }
}
