//
//  UserDetailViewModel.swift
//  stackOverflowTestTask
//
//  Created by Anton Charny on 15.04.2026.
//

import Foundation

struct UserDetailViewData: Equatable {
    internal let id: Int
    internal let displayName: String
    internal let reputationText: String
    internal let avatarURL: URL?
    internal let isFollowed: Bool
    internal let followStatusText: String
    internal let followButtonTitle: String
    internal let locationText: String
    internal let websiteURL: URL?
    internal let websiteText: String?
}

enum UserDetailViewState: Equatable {
    case content(UserDetailViewData)
}

@MainActor
final class UserDetailViewModel {

    internal enum Strings {
        internal static let reputationPrefix = "Reputation:"
        internal static let locationPrefix = "Location:"
        internal static let websitePrefix = "Website:"
        internal static let missingLocationText = "Not provided"
        internal static let followedStatusText = "Following"
        internal static let notFollowedStatusText = "Not following"
        internal static let followButtonTitle = "Follow"
        internal static let unfollowButtonTitle = "Unfollow"
    }

    internal var onStateChange: ((UserDetailViewState) -> Void)?

    internal let userModel: StackUser

    // MARK: - DI
    private let followStore: FollowStoreProtocol

    private lazy var reputationFormatter: NumberFormatter = {
        let reputationFormatter = NumberFormatter()
        reputationFormatter.numberStyle = .decimal
        return reputationFormatter
    }()

    internal init(
        userModel: StackUser,
        followStore: FollowStoreProtocol
    ) {
        self.userModel = userModel
        self.followStore = followStore
    }

    internal func load() {
        self.emitContent()
    }

    internal func toggleFollow() {
        let isCurrentlyFollowed = self.followStore.followedUserIDs().contains(self.userModel.id)
        self.followStore.setFollowed(!isCurrentlyFollowed, for: self.userModel.id)
        self.emitContent()
    }

    private func emitContent() {
        self.onStateChange?(.content(self.makeViewData()))
    }

    private func makeViewData() -> UserDetailViewData {
        let isFollowed = self.followStore.followedUserIDs().contains(self.userModel.id)

        return UserDetailViewData(
            id: self.userModel.id,
            displayName: self.userModel.displayName,
            reputationText: self.makeReputationText(from: self.userModel.reputation),
            avatarURL: self.userModel.avatarURL,
            isFollowed: isFollowed,
            followStatusText: isFollowed ? Strings.followedStatusText : Strings.notFollowedStatusText,
            followButtonTitle: isFollowed ? Strings.unfollowButtonTitle : Strings.followButtonTitle,
            locationText: "\(Strings.locationPrefix) \(self.userModel.location ?? Strings.missingLocationText)",
            websiteURL: self.userModel.websiteURL,
            websiteText: self.userModel.websiteURL.map { "\(Strings.websitePrefix) \($0.absoluteString)" }
        )
    }

    private func makeReputationText(from reputation: Int) -> String {
        let formattedValue = self.reputationFormatter.string(from: NSNumber(value: reputation)) ?? "\(reputation)"
        return "\(Strings.reputationPrefix) \(formattedValue)"
    }
}
