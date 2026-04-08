//
//  FollowStoreProtocol.swift
//  stackOverflowTestTask
//
//  Created by Anton Charny on 08.04.2026.
//

import Foundation

protocol FollowStoreProtocol {
    func followedUserIDs() -> Set<Int>
    func setFollowed(_ isFollowed: Bool, for userID: Int)
}
