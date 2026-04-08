//
//  UserListViewModel.swift
//  stackOverflowTestTask
//
//  Created by Anton Charny on 07.04.2026.
//

import Foundation

struct UserListItemViewData: Equatable {
    internal let id: Int
    internal let displayName: String
    internal let reputationText: String
    internal let avatarURL: URL?
    internal let isFollowed: Bool
    internal let followButtonTitle: String
}

enum UserListViewState: Equatable {
    case idle
    case loading
    case content([UserListItemViewData])
    case empty(String)
}

@MainActor
final class UserListViewModel {
    internal enum Strings {
        internal static let emptyUsersMessage = "No StackOverflow users found."
        internal static let loadErrorMessage = "Unable to load StackOverflow users.\nPlease try again."
        internal static let reputationPrefix = "Reputation:"
        internal static let followButtonTitle = "Follow"
        internal static let unfollowButtonTitle = "Unfollow"
        internal static let screenTitle = "Top StackOverflow Users"
    }

    internal var onStateChange: ((UserListViewState) -> Void)?

    private var state: UserListViewState = .idle {
        didSet {
            self.onStateChange?(self.state)
        }
    }

    private let usersRepository: UsersRepositoryProtocol
    private let followStore: FollowStoreProtocol

    private lazy var reputationFormatter: NumberFormatter = {
        let reputationFormatter = NumberFormatter()
        reputationFormatter.numberStyle = .decimal
        return reputationFormatter
    }()

    internal init(usersRepository: UsersRepositoryProtocol, followStore: FollowStoreProtocol) {
        self.usersRepository = usersRepository
        self.followStore = followStore
    }

    internal func load() async {
        self.state = .loading

        do {
            let users = try await self.usersRepository.fetchTopUsers()
            let followedUserIDs = self.followStore.followedUserIDs()
            let items = self.makeItems(from: users, followedUserIDs: followedUserIDs)
            self.state = items.isEmpty ? .empty(Strings.emptyUsersMessage) : .content(items)
        } catch {
            self.state = .empty(Strings.loadErrorMessage)
        }
    }

    internal func retry() async {
        await self.load()
    }

    internal func toggleFollow(for userID: Int) {
        guard case let .content(items) = self.state,
              let itemIndex = items.firstIndex(where: { $0.id == userID }) else {
            return
        }

        let currentItem = items[itemIndex]
        let updatedIsFollowed = !currentItem.isFollowed

        self.followStore.setFollowed(updatedIsFollowed, for: userID)

        var updatedItems = items
        updatedItems[itemIndex] = UserListItemViewData(
            id: currentItem.id,
            displayName: currentItem.displayName,
            reputationText: currentItem.reputationText,
            avatarURL: currentItem.avatarURL,
            isFollowed: updatedIsFollowed,
            followButtonTitle: self.makeFollowButtonTitle(isFollowed: updatedIsFollowed)
        )
        self.state = .content(updatedItems)
    }

    private func makeReputationText(from reputation: Int) -> String {
        let formattedValue = self.reputationFormatter.string(from: NSNumber(value: reputation)) ?? "\(reputation)"
        return "\(Strings.reputationPrefix) \(formattedValue)"
    }

    private func makeItems(from users: [StackUser], followedUserIDs: Set<Int>) -> [UserListItemViewData] {
        return users.map { user in
            let isFollowed = followedUserIDs.contains(user.id)

            return UserListItemViewData(
                id: user.id,
                displayName: user.displayName,
                reputationText: self.makeReputationText(from: user.reputation),
                avatarURL: user.avatarURL,
                isFollowed: isFollowed,
                followButtonTitle: self.makeFollowButtonTitle(isFollowed: isFollowed)
            )
        }
    }

    private func makeFollowButtonTitle(isFollowed: Bool) -> String {
        return isFollowed ? Strings.unfollowButtonTitle : Strings.followButtonTitle
    }
}
