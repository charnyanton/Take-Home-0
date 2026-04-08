//
//  UserDefaultsFollowStoreTests.swift
//  stackOverflowTestTask
//
//  Created by Anton Charny on 08.04.2026.
//

import Foundation
import Testing
@testable import stackOverflowTestTask

struct UserDefaultsFollowStoreTests {
    @Test
    func setFollowedStoresUserID() {
        let suiteName = "UserDefaultsFollowStoreTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        let store = UserDefaultsFollowStore(userDefaults: userDefaults)

        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        store.setFollowed(true, for: 42)

        #expect(store.followedUserIDs() == Set([42]))
    }

    @Test
    func setFollowedRemovesUserIDWhenUnfollowed() {
        let suiteName = "UserDefaultsFollowStoreTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        let store = UserDefaultsFollowStore(userDefaults: userDefaults)

        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        store.setFollowed(true, for: 42)
        store.setFollowed(false, for: 42)

        #expect(store.followedUserIDs().isEmpty)
    }

    @Test
    func setFollowedFalseForMissingUserIDKeepsStoreEmpty() {
        let suiteName = "UserDefaultsFollowStoreTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        let store = UserDefaultsFollowStore(userDefaults: userDefaults)

        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        store.setFollowed(false, for: 42)

        #expect(store.followedUserIDs().isEmpty)
    }

    @Test
    func followedStatePersistsAcrossStoreInstances() {
        let suiteName = "UserDefaultsFollowStoreTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        let firstStore = UserDefaultsFollowStore(userDefaults: userDefaults)

        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        firstStore.setFollowed(true, for: 42)

        let secondStore = UserDefaultsFollowStore(userDefaults: userDefaults)

        #expect(secondStore.followedUserIDs() == Set([42]))
    }

    @Test
    func repeatedFollowDoesNotDuplicateStoredIDs() {
        let suiteName = "UserDefaultsFollowStoreTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        let store = UserDefaultsFollowStore(userDefaults: userDefaults)

        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        store.setFollowed(true, for: 42)
        store.setFollowed(true, for: 42)

        let storedIDs = userDefaults.array(forKey: "followed_user_ids") as? [Int]

        #expect(storedIDs == [42])
    }

    @Test
    func followedUserIDsReturnsEmptySetForUnexpectedStoredValueType() {
        let suiteName = "UserDefaultsFollowStoreTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        let store = UserDefaultsFollowStore(userDefaults: userDefaults)

        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        userDefaults.set("not-an-array", forKey: "followed_user_ids")

        #expect(store.followedUserIDs().isEmpty)
    }

    @Test
    func followedUserIDsCollapsesDuplicatedStoredIDsIntoSet() {
        let suiteName = "UserDefaultsFollowStoreTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        let store = UserDefaultsFollowStore(userDefaults: userDefaults)

        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        userDefaults.set([42, 42, 7], forKey: "followed_user_ids")

        #expect(store.followedUserIDs() == Set([7, 42]))
    }
}
