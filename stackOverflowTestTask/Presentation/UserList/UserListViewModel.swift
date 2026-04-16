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

enum UserListPaginationFooterState: Equatable {
    case hidden
    case message(String)
}

@MainActor
final class UserListViewModel {

    // MARK: - Navigation
    internal var onUserDetailTap: ((StackUser) -> Void)?


    internal enum Strings {
        internal static let emptyUsersMessage = "No StackOverflow users found."
        internal static let loadErrorMessage = "Unable to load StackOverflow users.\nPlease try again."
        internal static let rateLimitErrorMessage = "Too many requests.\nPlease try again later."
        internal static let rateLimitReadyMessage = "Too many requests.\nYou can try again now."
        internal static let paginationLoadErrorMessage = "Unable to load more users. Please try again later."
        internal static let paginationRateLimitReadyMessage = "You can try loading more users now."
        internal static let reputationPrefix = "Reputation:"
        internal static let followButtonTitle = "Follow"
        internal static let unfollowButtonTitle = "Unfollow"
        internal static let screenTitle = "Top StackOverflow Users"
        internal static let sortButtonTitle = "Sort"
        internal static let sortByMenuTitle = "Sort by"
        internal static let orderMenuTitle = "Order"

        internal static func rateLimitCountdownMessage(seconds: Int) -> String {
            return "Too many requests.\nPlease try again in \(seconds) seconds."
        }

        internal static func paginationRateLimitCountdownMessage(seconds: Int) -> String {
            return "Too many requests. Try loading more users in \(seconds) seconds."
        }
    }

    internal var onStateChange: ((UserListViewState) -> Void)?
    internal var onPaginationFooterStateChange: ((UserListPaginationFooterState) -> Void)?
    internal private(set) var selectedSortOption: UserSortOption = .reputation
    internal private(set) var selectedSortOrder: UserSortOrder = .descending

    private var state: UserListViewState = .idle {
        didSet {
            self.onStateChange?(self.state)
        }
    }

    private var paginationFooterState: UserListPaginationFooterState = .hidden {
        didSet {
            self.onPaginationFooterStateChange?(self.paginationFooterState)
        }
    }

    private var users: [StackUser] = []
    private var currentPage = 1
    private var hasMorePages = false
    private var isLoadingNextPage = false
    private let pageSize = 20
    private let paginationPrefetchThreshold = 5
    private let rateLimitCountdownInterval: Duration
    private var loadTask: Task<Void, Never>?
    private var paginationTask: Task<Void, Never>?
    private var rateLimitCountdownTask: Task<Void, Never>?
    private var paginationFooterCountdownTask: Task<Void, Never>?

    private let usersRepository: UsersRepositoryProtocol
    private let followStore: FollowStoreProtocol

    private lazy var reputationFormatter: NumberFormatter = {
        let reputationFormatter = NumberFormatter()
        reputationFormatter.numberStyle = .decimal
        return reputationFormatter
    }()

    internal init(
        usersRepository: UsersRepositoryProtocol,
        followStore: FollowStoreProtocol,
        onUserDetailTap: @escaping (StackUser) -> Void = { _ in },
        rateLimitCountdownInterval: Duration = .seconds(1)
    ) {
        self.usersRepository = usersRepository
        self.followStore = followStore
        self.onUserDetailTap = onUserDetailTap
        self.rateLimitCountdownInterval = rateLimitCountdownInterval
    }

    deinit {
        self.loadTask?.cancel()
        self.paginationTask?.cancel()
        self.rateLimitCountdownTask?.cancel()
        self.paginationFooterCountdownTask?.cancel()
    }

    internal func load() async {
        self.loadTask?.cancel()
        self.paginationTask?.cancel()
        self.loadTask = nil
        self.paginationTask = nil
        self.cancelRateLimitCountdown()
        self.hidePaginationFooter()
        self.state = .loading
        self.currentPage = 1
        self.hasMorePages = false
        self.isLoadingNextPage = false

        let sortOption = self.selectedSortOption
        let sortOrder = self.selectedSortOrder
        let pageSize = self.pageSize

        let task = Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            defer {
                if !Task.isCancelled {
                    self.loadTask = nil
                }
            }

            do {
                let page = try await self.usersRepository.fetchUsers(
                    sort: sortOption,
                    order: sortOrder,
                    page: 1,
                    pageSize: pageSize
                )
                try Task.checkCancellation()

                self.users = page.users
                self.hasMorePages = page.hasMore

                let followedUserIDs = self.followStore.followedUserIDs()
                let items = self.makeItems(from: self.users, followedUserIDs: followedUserIDs)
                self.state = items.isEmpty ? .empty(Strings.emptyUsersMessage) : .content(items)
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else {
                    return
                }

                self.handleLoadError(error)
            }
        }

        self.loadTask = task
        await task.value
    }

    internal func retry() async {
        await self.load()
    }

    internal func refreshFollowState() {
        guard case .content = self.state else {
            return
        }

        let followedUserIDs = self.followStore.followedUserIDs()
        let items = self.makeItems(from: self.users, followedUserIDs: followedUserIDs)
        self.state = items.isEmpty ? .empty(Strings.emptyUsersMessage) : .content(items)
    }

    internal func selectSortOption(_ sortOption: UserSortOption) async {
        guard self.selectedSortOption != sortOption else {
            return
        }

        self.selectedSortOption = sortOption
        await self.load()
    }

    internal func selectSortOrder(_ sortOrder: UserSortOrder) async {
        guard self.selectedSortOrder != sortOrder else {
            return
        }

        self.selectedSortOrder = sortOrder
        await self.load()
    }

    internal func loadNextPageIfNeeded(currentItemID: Int) async {
        guard case .content = self.state,
              self.hasMorePages,
              !self.isLoadingNextPage,
              let currentIndex = self.users.firstIndex(where: { $0.id == currentItemID }) else {
            return
        }

        let prefetchStartIndex = max(self.users.count - self.paginationPrefetchThreshold, 0)
        guard currentIndex >= prefetchStartIndex else {
            return
        }

        self.isLoadingNextPage = true
        let nextPage = self.currentPage + 1
        let sortOption = self.selectedSortOption
        let sortOrder = self.selectedSortOrder
        let pageSize = self.pageSize

        let task = Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            defer {
                if !Task.isCancelled {
                    self.isLoadingNextPage = false
                    self.paginationTask = nil
                }
            }

            do {
                let page = try await self.usersRepository.fetchUsers(
                    sort: sortOption,
                    order: sortOrder,
                    page: nextPage,
                    pageSize: pageSize
                )
                try Task.checkCancellation()

                self.currentPage = nextPage
                self.hasMorePages = page.hasMore
                self.users.append(contentsOf: page.users)
                self.hidePaginationFooter()

                let followedUserIDs = self.followStore.followedUserIDs()
                self.state = .content(self.makeItems(from: self.users, followedUserIDs: followedUserIDs))
            } catch is CancellationError {
                return
            } catch let error as UsersRepositoryError {
                guard !Task.isCancelled else {
                    return
                }

                if case .rateLimited = error {
                    self.hasMorePages = false
                    self.startPaginationRateLimitCountdown(from: error)
                } else {
                    self.hasMorePages = true
                    self.showPaginationFooter(message: Strings.paginationLoadErrorMessage)
                }
            } catch {
                guard !Task.isCancelled else {
                    return
                }

                self.hasMorePages = true
                self.showPaginationFooter(message: Strings.paginationLoadErrorMessage)
            }
        }

        self.paginationTask = task
        await task.value
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

    internal func goToDetailScreen(userModel: UserListItemViewData) {
        guard let stackUser = self.users.first(where: { $0.id == userModel.id }) else {
            return
        }

        self.onUserDetailTap?(stackUser)
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

    private func handleLoadError(_ error: Error) {
        if case let .rateLimited(retryAfterSeconds) = error as? UsersRepositoryError {
            self.startRateLimitCountdown(seconds: retryAfterSeconds)
            return
        }

        self.state = .empty(Strings.loadErrorMessage)
    }

    private func startRateLimitCountdown(seconds: Int?) {
        guard let seconds, seconds > 0 else {
            self.state = .empty(Strings.rateLimitErrorMessage)
            return
        }

        self.state = .empty(Strings.rateLimitCountdownMessage(seconds: seconds))

        let interval = self.rateLimitCountdownInterval
        self.rateLimitCountdownTask = Task { @MainActor [weak self] in
            var remainingSeconds = seconds

            while remainingSeconds > 0 {
                do {
                    try await Task.sleep(for: interval)
                } catch {
                    return
                }

                guard !Task.isCancelled else {
                    return
                }

                remainingSeconds -= 1
                if remainingSeconds > 0 {
                    self?.state = .empty(Strings.rateLimitCountdownMessage(seconds: remainingSeconds))
                } else {
                    self?.state = .empty(Strings.rateLimitReadyMessage)
                }
            }

            self?.rateLimitCountdownTask = nil
        }
    }

    private func cancelRateLimitCountdown() {
        self.rateLimitCountdownTask?.cancel()
        self.rateLimitCountdownTask = nil
    }

    private func startPaginationRateLimitCountdown(from error: UsersRepositoryError) {
        guard case let .rateLimited(retryAfterSeconds) = error,
              let retryAfterSeconds,
              retryAfterSeconds > 0 else {
            self.showPaginationFooter(message: Strings.paginationLoadErrorMessage)
            return
        }

        self.showPaginationFooter(message: Strings.paginationRateLimitCountdownMessage(seconds: retryAfterSeconds))

        let interval = self.rateLimitCountdownInterval
        self.paginationFooterCountdownTask = Task { @MainActor [weak self] in
            var remainingSeconds = retryAfterSeconds

            while remainingSeconds > 0 {
                do {
                    try await Task.sleep(for: interval)
                } catch {
                    return
                }

                guard !Task.isCancelled else {
                    return
                }

                remainingSeconds -= 1
                if remainingSeconds > 0 {
                    self?.showPaginationFooter(message: Strings.paginationRateLimitCountdownMessage(seconds: remainingSeconds))
                } else {
                    self?.showPaginationFooter(message: Strings.paginationRateLimitReadyMessage)
                }
            }

            self?.paginationFooterCountdownTask = nil
        }
    }

    private func showPaginationFooter(message: String) {
        self.paginationFooterState = .message(message)
    }

    private func hidePaginationFooter() {
        self.paginationFooterCountdownTask?.cancel()
        self.paginationFooterCountdownTask = nil
        self.paginationFooterState = .hidden
    }
}
