//
//  UserListViewModelTests.swift
//  stackOverflowTestTask
//
//  Created by Anton Charny on 07.04.2026.
//

import Foundation
import Testing
@testable import stackOverflowTestTask

@MainActor
struct UserListViewModelTests {
    @Test
    func loadEmitsLoadingThenContentWithPersistedFollowState() async {
        let repository = MockUsersRepository()
        repository.result = .success([
            StackUser.fixture(
                id: 1,
                displayName: "John Doe",
                reputation: 1_525_628,
                avatarURL: URL(string: "https://example.com/jon.png")
            ),
            StackUser.fixture(id: 2, displayName: "VonC", reputation: 1_368_324, avatarURL: nil),
        ])
        let followStore = MockFollowStore(followedUserIDs: [2])
        let viewModel = UserListViewModel(usersRepository: repository, followStore: followStore)
        var receivedStates: [UserListViewState] = []
        viewModel.onStateChange = { state in
            receivedStates.append(state)
        }

        await viewModel.load()

        #expect(repository.fetchTopUsersCallCount == 1)
        #expect(repository.fetchUsersCalls == [
            MockUsersRepository.FetchUsersCall(sort: .reputation, order: .descending),
        ])
        #expect(receivedStates == [
            .loading,
            .content([
                UserListItemViewData(
                    id: 1,
                    displayName: "John Doe",
                    reputationText: Self.makeExpectedReputationText(from: 1_525_628),
                    avatarURL: URL(string: "https://example.com/jon.png"),
                    isFollowed: false,
                    followButtonTitle: UserListViewModel.Strings.followButtonTitle
                ),
                UserListItemViewData(
                    id: 2,
                    displayName: "VonC",
                    reputationText: Self.makeExpectedReputationText(from: 1_368_324),
                    avatarURL: nil,
                    isFollowed: true,
                    followButtonTitle: UserListViewModel.Strings.unfollowButtonTitle
                ),
            ]),
        ])
    }

    @Test
    func loadEmitsEmptyStateWhenRepositoryFails() async {
        let repository = MockUsersRepository()
        repository.result = .failure(UsersRepositoryError.transport)
        let followStore = MockFollowStore()
        let viewModel = UserListViewModel(usersRepository: repository, followStore: followStore)
        var receivedStates: [UserListViewState] = []
        viewModel.onStateChange = { state in
            receivedStates.append(state)
        }

        await viewModel.load()

        #expect(receivedStates == [
            .loading,
            .empty(UserListViewModel.Strings.loadErrorMessage),
        ])
    }

    @Test
    func loadEmitsRateLimitStateWhenRepositoryFailsWithRateLimit() async {
        let repository = MockUsersRepository()
        repository.result = .failure(UsersRepositoryError.rateLimited(retryAfterSeconds: 30))
        let followStore = MockFollowStore()
        let viewModel = UserListViewModel(usersRepository: repository, followStore: followStore)
        var receivedStates: [UserListViewState] = []
        viewModel.onStateChange = { state in
            receivedStates.append(state)
        }

        await viewModel.load()

        #expect(receivedStates == [
            .loading,
            .empty(UserListViewModel.Strings.rateLimitCountdownMessage(seconds: 30)),
        ])
    }

    @Test
    func loadUpdatesRateLimitCountdown() async {
        let repository = MockUsersRepository()
        repository.result = .failure(UsersRepositoryError.rateLimited(retryAfterSeconds: 2))
        let followStore = MockFollowStore()
        let viewModel = UserListViewModel(
            usersRepository: repository,
            followStore: followStore,
            rateLimitCountdownInterval: .milliseconds(1)
        )
        var receivedStates: [UserListViewState] = []
        viewModel.onStateChange = { state in
            receivedStates.append(state)
        }

        await viewModel.load()
        try? await Task.sleep(for: .milliseconds(50))

        #expect(receivedStates.contains(.empty(UserListViewModel.Strings.rateLimitCountdownMessage(seconds: 1))))
        #expect(receivedStates.last == .empty(UserListViewModel.Strings.rateLimitReadyMessage))
    }

    @Test
    func loadEmitsEmptyStateWhenRepositoryReturnsNoUsers() async {
        let repository = MockUsersRepository()
        repository.result = .success([])
        let followStore = MockFollowStore()
        let viewModel = UserListViewModel(usersRepository: repository, followStore: followStore)
        var receivedStates: [UserListViewState] = []
        viewModel.onStateChange = { state in
            receivedStates.append(state)
        }

        await viewModel.load()

        #expect(receivedStates == [
            .loading,
            .empty(UserListViewModel.Strings.emptyUsersMessage),
        ])
    }

    @Test
    func staleLoadResponseDoesNotOverwriteNewerLoad() async {
        let repository = DeferredUsersRepository()
        let followStore = MockFollowStore()
        let viewModel = UserListViewModel(usersRepository: repository, followStore: followStore)
        var receivedStates: [UserListViewState] = []
        viewModel.onStateChange = { state in
            receivedStates.append(state)
        }

        let firstLoadTask = Task {
            await viewModel.load()
        }
        await Self.waitForFetchCallCount(1, in: repository)

        let secondLoadTask = Task {
            await viewModel.selectSortOption(.name)
        }
        await Self.waitForFetchCallCount(2, in: repository)

        repository.succeedRequest(
            at: 1,
            users: [StackUser.fixture(id: 2, displayName: "Fresh User", reputation: 2_000, avatarURL: nil)]
        )
        await secondLoadTask.value

        repository.succeedRequest(
            at: 0,
            users: [StackUser.fixture(id: 1, displayName: "Stale User", reputation: 1_000, avatarURL: nil)]
        )
        await firstLoadTask.value

        guard case let .content(items) = receivedStates.last else {
            Issue.record("Expected content state after completing loads.")
            return
        }

        #expect(repository.fetchUsersCalls == [
            MockUsersRepository.FetchUsersCall(sort: .reputation, order: .descending),
            MockUsersRepository.FetchUsersCall(sort: .name, order: .descending),
        ])
        #expect(items.map(\.id) == [2])
    }

    @Test
    func toggleFollowUpdatesContentAndPersistsState() async {
        let repository = MockUsersRepository()
        repository.result = .success([
            StackUser.fixture(id: 1, displayName: "John Doe", reputation: 1_525_628, avatarURL: nil),
            StackUser.fixture(id: 2, displayName: "Anton Charny", reputation: 1_368_324, avatarURL: nil),
        ])
        let followStore = MockFollowStore()
        let viewModel = UserListViewModel(usersRepository: repository, followStore: followStore)
        var receivedStates: [UserListViewState] = []
        viewModel.onStateChange = { state in
            receivedStates.append(state)
        }

        await viewModel.load()
        viewModel.toggleFollow(for: 1)

        #expect(followStore.followedUserIDs() == Set([1]))
        #expect(followStore.recordedSetFollowedCalls == [
            MockFollowStore.SetFollowedCall(isFollowed: true, userID: 1),
        ])
        #expect(receivedStates.last == .content([
            UserListItemViewData(
                id: 1,
                displayName: "John Doe",
                reputationText: Self.makeExpectedReputationText(from: 1_525_628),
                avatarURL: nil,
                isFollowed: true,
                followButtonTitle: UserListViewModel.Strings.unfollowButtonTitle
            ),
            UserListItemViewData(
                id: 2,
                displayName: "Anton Charny",
                reputationText: Self.makeExpectedReputationText(from: 1_368_324),
                avatarURL: nil,
                isFollowed: false,
                followButtonTitle: UserListViewModel.Strings.followButtonTitle
            ),
        ]))
    }

    @Test
    func loadAfterToggleRestoresPersistedFollowState() async {
        let repository = MockUsersRepository()
        repository.result = .success([
            StackUser.fixture(id: 1, displayName: "John Doe", reputation: 1_525_628, avatarURL: nil),
        ])
        let followStore = MockFollowStore()
        let viewModel = UserListViewModel(usersRepository: repository, followStore: followStore)
        var receivedStates: [UserListViewState] = []
        viewModel.onStateChange = { state in
            receivedStates.append(state)
        }

        await viewModel.load()
        viewModel.toggleFollow(for: 1)
        await viewModel.load()

        #expect(Array(receivedStates.suffix(2)) == [
            .loading,
            .content([
                UserListItemViewData(
                    id: 1,
                    displayName: "John Doe",
                    reputationText: Self.makeExpectedReputationText(from: 1_525_628),
                    avatarURL: nil,
                    isFollowed: true,
                    followButtonTitle: UserListViewModel.Strings.unfollowButtonTitle
                ),
            ]),
        ])
    }

    @Test
    func refreshFollowStateUpdatesVisibleItemsFromStoreWithoutReloadingRepository() async {
        let repository = MockUsersRepository()
        repository.result = .success([
            StackUser.fixture(id: 1, displayName: "John Doe", reputation: 1_525_628, avatarURL: nil),
        ])
        let followStore = MockFollowStore()
        let viewModel = UserListViewModel(usersRepository: repository, followStore: followStore)
        var receivedStates: [UserListViewState] = []
        viewModel.onStateChange = { state in
            receivedStates.append(state)
        }

        await viewModel.load()
        followStore.setFollowed(true, for: 1)
        viewModel.refreshFollowState()

        #expect(repository.fetchTopUsersCallCount == 1)
        #expect(receivedStates.last == .content([
            UserListItemViewData(
                id: 1,
                displayName: "John Doe",
                reputationText: Self.makeExpectedReputationText(from: 1_525_628),
                avatarURL: nil,
                isFollowed: true,
                followButtonTitle: UserListViewModel.Strings.unfollowButtonTitle
            ),
        ]))
    }

    @Test
    func toggleFollowDoesNothingOutsideContentState() {
        let repository = MockUsersRepository()
        let followStore = MockFollowStore()
        let viewModel = UserListViewModel(usersRepository: repository, followStore: followStore)

        viewModel.toggleFollow(for: 1)

        #expect(followStore.recordedSetFollowedCalls.isEmpty)
    }

    @Test
    func toggleFollowDoesNothingForUnknownUserIDInContentState() async {
        let repository = MockUsersRepository()
        repository.result = .success([
            StackUser.fixture(id: 1, displayName: "John Doe", reputation: 1_525_628, avatarURL: nil),
        ])
        let followStore = MockFollowStore()
        let viewModel = UserListViewModel(usersRepository: repository, followStore: followStore)
        var receivedStates: [UserListViewState] = []
        viewModel.onStateChange = { state in
            receivedStates.append(state)
        }

        await viewModel.load()
        viewModel.toggleFollow(for: 999)

        #expect(followStore.recordedSetFollowedCalls.isEmpty)
        #expect(receivedStates.last == .content([
            UserListItemViewData(
                id: 1,
                displayName: "John Doe",
                reputationText: Self.makeExpectedReputationText(from: 1_525_628),
                avatarURL: nil,
                isFollowed: false,
                followButtonTitle: UserListViewModel.Strings.followButtonTitle
            ),
        ]))
    }

    @Test
    func toggleFollowTwiceRestoresOriginalState() async {
        let repository = MockUsersRepository()
        repository.result = .success([
            StackUser.fixture(id: 1, displayName: "John Doe", reputation: 1_525_628, avatarURL: nil),
        ])
        let followStore = MockFollowStore()
        let viewModel = UserListViewModel(usersRepository: repository, followStore: followStore)
        var receivedStates: [UserListViewState] = []
        viewModel.onStateChange = { state in
            receivedStates.append(state)
        }

        await viewModel.load()
        viewModel.toggleFollow(for: 1)
        viewModel.toggleFollow(for: 1)

        #expect(followStore.followedUserIDs().isEmpty)
        #expect(followStore.recordedSetFollowedCalls == [
            MockFollowStore.SetFollowedCall(isFollowed: true, userID: 1),
            MockFollowStore.SetFollowedCall(isFollowed: false, userID: 1),
        ])
        #expect(receivedStates.last == .content([
            UserListItemViewData(
                id: 1,
                displayName: "John Doe",
                reputationText: Self.makeExpectedReputationText(from: 1_525_628),
                avatarURL: nil,
                isFollowed: false,
                followButtonTitle: UserListViewModel.Strings.followButtonTitle
            ),
        ]))
    }

    @Test
    func toggleFollowOnMultipleUsersKeepsStateIndependent() async {
        let repository = MockUsersRepository()
        repository.result = .success([
            StackUser.fixture(id: 1, displayName: "John Doe", reputation: 1_525_628, avatarURL: nil),
            StackUser.fixture(id: 2, displayName: "VonC", reputation: 1_368_324, avatarURL: nil),
            StackUser.fixture(id: 3, displayName: "Jane Roe", reputation: 999_999, avatarURL: nil),
        ])
        let followStore = MockFollowStore()
        let viewModel = UserListViewModel(usersRepository: repository, followStore: followStore)

        await viewModel.load()
        viewModel.toggleFollow(for: 1)
        viewModel.toggleFollow(for: 2)
        viewModel.toggleFollow(for: 1)

        #expect(followStore.followedUserIDs() == Set([2]))
        #expect(followStore.recordedSetFollowedCalls == [
            MockFollowStore.SetFollowedCall(isFollowed: true, userID: 1),
            MockFollowStore.SetFollowedCall(isFollowed: true, userID: 2),
            MockFollowStore.SetFollowedCall(isFollowed: false, userID: 1),
        ])
    }

    @Test
    func loadAfterPreviouslyFollowedUserDisappearsKeepsVisibleItemsConsistent() async {
        let repository = MockUsersRepository()
        repository.result = .success([
            StackUser.fixture(id: 1, displayName: "John Doe", reputation: 1_525_628, avatarURL: nil),
            StackUser.fixture(id: 2, displayName: "VonC", reputation: 1_368_324, avatarURL: nil),
        ])
        let followStore = MockFollowStore(followedUserIDs: [1])
        let viewModel = UserListViewModel(usersRepository: repository, followStore: followStore)
        var receivedStates: [UserListViewState] = []
        viewModel.onStateChange = { state in
            receivedStates.append(state)
        }

        await viewModel.load()

        repository.result = .success([
            StackUser.fixture(id: 2, displayName: "VonC", reputation: 1_368_324, avatarURL: nil),
        ])
        await viewModel.load()

        #expect(followStore.followedUserIDs() == Set([1]))
        #expect(Array(receivedStates.suffix(2)) == [
            .loading,
            .content([
                UserListItemViewData(
                    id: 2,
                    displayName: "VonC",
                    reputationText: Self.makeExpectedReputationText(from: 1_368_324),
                    avatarURL: nil,
                    isFollowed: false,
                    followButtonTitle: UserListViewModel.Strings.followButtonTitle
                ),
            ]),
        ])
    }

    @Test
    func retryAfterFailureUsesPersistedFollowState() async {
        let repository = MockUsersRepository()
        let followStore = MockFollowStore(followedUserIDs: [1])
        let viewModel = UserListViewModel(usersRepository: repository, followStore: followStore)
        var receivedStates: [UserListViewState] = []
        viewModel.onStateChange = { state in
            receivedStates.append(state)
        }

        repository.result = .failure(UsersRepositoryError.transport)
        await viewModel.load()

        repository.result = .success([
            StackUser.fixture(id: 1, displayName: "John Doe", reputation: 1_525_628, avatarURL: nil),
        ])
        await viewModel.retry()

        #expect(Array(receivedStates.suffix(2)) == [
            .loading,
            .content([
                UserListItemViewData(
                    id: 1,
                    displayName: "John Doe",
                    reputationText: Self.makeExpectedReputationText(from: 1_525_628),
                    avatarURL: nil,
                    isFollowed: true,
                    followButtonTitle: UserListViewModel.Strings.unfollowButtonTitle
                ),
            ]),
        ])
    }

    @Test
    func loadNextPageAppendsUsersWhenPrefetchThresholdIsReached() async {
        let repository = MockUsersRepository()
        repository.resultsByPage = [
            1: .success(Self.makeUsers(ids: 1...6)),
            2: .success([
                StackUser.fixture(id: 7, displayName: "User 7", reputation: 7_000, avatarURL: nil),
            ]),
        ]
        repository.hasMoreByPage = [1: true, 2: false]
        let followStore = MockFollowStore(followedUserIDs: [7])
        let viewModel = UserListViewModel(usersRepository: repository, followStore: followStore)
        var receivedStates: [UserListViewState] = []
        viewModel.onStateChange = { state in
            receivedStates.append(state)
        }

        await viewModel.load()
        await viewModel.loadNextPageIfNeeded(currentItemID: 2)

        #expect(repository.fetchUsersCalls == [
            MockUsersRepository.FetchUsersCall(sort: .reputation, order: .descending, page: 1, pageSize: 20),
            MockUsersRepository.FetchUsersCall(sort: .reputation, order: .descending, page: 2, pageSize: 20),
        ])
        #expect(receivedStates.last == .content([
            UserListItemViewData(
                id: 1,
                displayName: "User 1",
                reputationText: Self.makeExpectedReputationText(from: 1_000),
                avatarURL: nil,
                isFollowed: false,
                followButtonTitle: UserListViewModel.Strings.followButtonTitle
            ),
            UserListItemViewData(
                id: 2,
                displayName: "User 2",
                reputationText: Self.makeExpectedReputationText(from: 2_000),
                avatarURL: nil,
                isFollowed: false,
                followButtonTitle: UserListViewModel.Strings.followButtonTitle
            ),
            UserListItemViewData(
                id: 3,
                displayName: "User 3",
                reputationText: Self.makeExpectedReputationText(from: 3_000),
                avatarURL: nil,
                isFollowed: false,
                followButtonTitle: UserListViewModel.Strings.followButtonTitle
            ),
            UserListItemViewData(
                id: 4,
                displayName: "User 4",
                reputationText: Self.makeExpectedReputationText(from: 4_000),
                avatarURL: nil,
                isFollowed: false,
                followButtonTitle: UserListViewModel.Strings.followButtonTitle
            ),
            UserListItemViewData(
                id: 5,
                displayName: "User 5",
                reputationText: Self.makeExpectedReputationText(from: 5_000),
                avatarURL: nil,
                isFollowed: false,
                followButtonTitle: UserListViewModel.Strings.followButtonTitle
            ),
            UserListItemViewData(
                id: 6,
                displayName: "User 6",
                reputationText: Self.makeExpectedReputationText(from: 6_000),
                avatarURL: nil,
                isFollowed: false,
                followButtonTitle: UserListViewModel.Strings.followButtonTitle
            ),
            UserListItemViewData(
                id: 7,
                displayName: "User 7",
                reputationText: Self.makeExpectedReputationText(from: 7_000),
                avatarURL: nil,
                isFollowed: true,
                followButtonTitle: UserListViewModel.Strings.unfollowButtonTitle
            ),
        ]))
    }

    @Test
    func loadNextPageDoesNothingBeforePrefetchThreshold() async {
        let repository = MockUsersRepository()
        repository.result = .success(Self.makeUsers(ids: 1...10))
        repository.hasMore = true
        let followStore = MockFollowStore()
        let viewModel = UserListViewModel(usersRepository: repository, followStore: followStore)

        await viewModel.load()
        await viewModel.loadNextPageIfNeeded(currentItemID: 5)

        #expect(repository.fetchUsersCalls == [
            MockUsersRepository.FetchUsersCall(sort: .reputation, order: .descending, page: 1, pageSize: 20),
        ])
    }

    @Test
    func loadNextPageDoesNothingWhenRepositoryReportsNoMorePages() async {
        let repository = MockUsersRepository()
        repository.result = .success([
            StackUser.fixture(id: 1, displayName: "John Doe", reputation: 1_525_628, avatarURL: nil),
        ])
        repository.hasMore = false
        let followStore = MockFollowStore()
        let viewModel = UserListViewModel(usersRepository: repository, followStore: followStore)

        await viewModel.load()
        await viewModel.loadNextPageIfNeeded(currentItemID: 1)

        #expect(repository.fetchUsersCalls == [
            MockUsersRepository.FetchUsersCall(sort: .reputation, order: .descending, page: 1, pageSize: 20),
        ])
    }

    @Test
    func loadNextPageStopsFurtherPaginationAfterRateLimit() async {
        let repository = MockUsersRepository()
        repository.resultsByPage = [
            1: .success(Self.makeUsers(ids: 1...6)),
            2: .failure(UsersRepositoryError.rateLimited(retryAfterSeconds: 30)),
        ]
        repository.hasMoreByPage = [1: true]
        let followStore = MockFollowStore()
        let viewModel = UserListViewModel(usersRepository: repository, followStore: followStore)

        await viewModel.load()
        await viewModel.loadNextPageIfNeeded(currentItemID: 2)
        await viewModel.loadNextPageIfNeeded(currentItemID: 2)

        #expect(repository.fetchUsersCalls == [
            MockUsersRepository.FetchUsersCall(sort: .reputation, order: .descending, page: 1, pageSize: 20),
            MockUsersRepository.FetchUsersCall(sort: .reputation, order: .descending, page: 2, pageSize: 20),
        ])
    }

    @Test
    func loadNextPageShowsFooterMessageWhenRepositoryFails() async {
        let repository = MockUsersRepository()
        repository.resultsByPage = [
            1: .success(Self.makeUsers(ids: 1...6)),
            2: .failure(UsersRepositoryError.transport),
        ]
        repository.hasMoreByPage = [1: true]
        let followStore = MockFollowStore()
        let viewModel = UserListViewModel(usersRepository: repository, followStore: followStore)
        var footerStates: [UserListPaginationFooterState] = []
        viewModel.onPaginationFooterStateChange = { state in
            footerStates.append(state)
        }

        await viewModel.load()
        await viewModel.loadNextPageIfNeeded(currentItemID: 2)

        #expect(footerStates.last == .message(UserListViewModel.Strings.paginationLoadErrorMessage))
    }

    @Test
    func loadNextPageShowsRateLimitFooterCountdown() async {
        let repository = MockUsersRepository()
        repository.resultsByPage = [
            1: .success(Self.makeUsers(ids: 1...6)),
            2: .failure(UsersRepositoryError.rateLimited(retryAfterSeconds: 2)),
        ]
        repository.hasMoreByPage = [1: true]
        let followStore = MockFollowStore()
        let viewModel = UserListViewModel(
            usersRepository: repository,
            followStore: followStore,
            rateLimitCountdownInterval: .milliseconds(1)
        )
        var footerStates: [UserListPaginationFooterState] = []
        viewModel.onPaginationFooterStateChange = { state in
            footerStates.append(state)
        }

        await viewModel.load()
        await viewModel.loadNextPageIfNeeded(currentItemID: 2)
        try? await Task.sleep(for: .milliseconds(50))

        #expect(footerStates.contains(.message(UserListViewModel.Strings.paginationRateLimitCountdownMessage(seconds: 2))))
        #expect(footerStates.contains(.message(UserListViewModel.Strings.paginationRateLimitCountdownMessage(seconds: 1))))
        #expect(footerStates.last == .message(UserListViewModel.Strings.paginationRateLimitReadyMessage))
    }

    @Test
    func staleNextPageResponseDoesNotAppendAfterNewerLoad() async {
        let repository = DeferredUsersRepository()
        let followStore = MockFollowStore()
        let viewModel = UserListViewModel(usersRepository: repository, followStore: followStore)
        var receivedStates: [UserListViewState] = []
        viewModel.onStateChange = { state in
            receivedStates.append(state)
        }

        let initialLoadTask = Task {
            await viewModel.load()
        }
        await Self.waitForFetchCallCount(1, in: repository)
        repository.succeedRequest(at: 0, users: Self.makeUsers(ids: 1...6), hasMore: true)
        await initialLoadTask.value

        let nextPageTask = Task {
            await viewModel.loadNextPageIfNeeded(currentItemID: 2)
        }
        await Self.waitForFetchCallCount(2, in: repository)

        let reloadTask = Task {
            await viewModel.selectSortOption(.name)
        }
        await Self.waitForFetchCallCount(3, in: repository)
        repository.succeedRequest(
            at: 2,
            users: [StackUser.fixture(id: 100, displayName: "Fresh User", reputation: 100_000, avatarURL: nil)]
        )
        await reloadTask.value

        repository.succeedRequest(
            at: 1,
            users: [StackUser.fixture(id: 7, displayName: "Stale Page User", reputation: 7_000, avatarURL: nil)]
        )
        await nextPageTask.value

        guard case let .content(items) = receivedStates.last else {
            Issue.record("Expected content state after completing pagination and reload.")
            return
        }

        #expect(repository.fetchUsersCalls == [
            MockUsersRepository.FetchUsersCall(sort: .reputation, order: .descending, page: 1, pageSize: 20),
            MockUsersRepository.FetchUsersCall(sort: .reputation, order: .descending, page: 2, pageSize: 20),
            MockUsersRepository.FetchUsersCall(sort: .name, order: .descending, page: 1, pageSize: 20),
        ])
        #expect(items.map(\.id) == [100])
    }

    @Test
    func selectingSortOptionReloadsUsersWithSelectedSortAndCurrentOrder() async {
        let repository = MockUsersRepository()
        repository.result = .success([
            StackUser.fixture(id: 1, displayName: "John Doe", reputation: 1_525_628, avatarURL: nil),
        ])
        let followStore = MockFollowStore()
        let viewModel = UserListViewModel(usersRepository: repository, followStore: followStore)

        await viewModel.load()
        await viewModel.selectSortOption(.name)

        #expect(viewModel.selectedSortOption == .name)
        #expect(viewModel.selectedSortOrder == .descending)
        #expect(repository.fetchUsersCalls == [
            MockUsersRepository.FetchUsersCall(sort: .reputation, order: .descending),
            MockUsersRepository.FetchUsersCall(sort: .name, order: .descending),
        ])
    }

    @Test
    func selectingSortOrderReloadsUsersWithCurrentSortAndSelectedOrder() async {
        let repository = MockUsersRepository()
        repository.result = .success([
            StackUser.fixture(id: 1, displayName: "John Doe", reputation: 1_525_628, avatarURL: nil),
        ])
        let followStore = MockFollowStore()
        let viewModel = UserListViewModel(usersRepository: repository, followStore: followStore)

        await viewModel.load()
        await viewModel.selectSortOrder(.ascending)

        #expect(viewModel.selectedSortOption == .reputation)
        #expect(viewModel.selectedSortOrder == .ascending)
        #expect(repository.fetchUsersCalls == [
            MockUsersRepository.FetchUsersCall(sort: .reputation, order: .descending),
            MockUsersRepository.FetchUsersCall(sort: .reputation, order: .ascending),
        ])
    }

    @Test
    func selectingAlreadyActiveSortDoesNotReload() async {
        let repository = MockUsersRepository()
        repository.result = .success([
            StackUser.fixture(id: 1, displayName: "John Doe", reputation: 1_525_628, avatarURL: nil),
        ])
        let followStore = MockFollowStore()
        let viewModel = UserListViewModel(usersRepository: repository, followStore: followStore)

        await viewModel.load()
        await viewModel.selectSortOption(.reputation)
        await viewModel.selectSortOrder(.descending)

        #expect(repository.fetchUsersCalls == [
            MockUsersRepository.FetchUsersCall(sort: .reputation, order: .descending),
        ])
    }

    @Test
    func goToDetailScreenEmitsSelectedUserFromLatestLoadedUsers() async {
        let expectedUser = StackUser.fixture(
            id: 42,
            displayName: "Anton Charny",
            reputation: 10_000,
            avatarURL: nil
        )
        let repository = MockUsersRepository()
        repository.result = .success([expectedUser])
        let followStore = MockFollowStore()
        var selectedUser: StackUser?
        let viewModel = UserListViewModel(
            usersRepository: repository,
            followStore: followStore,
            onUserDetailTap: { user in
                selectedUser = user
            }
        )

        await viewModel.load()
        viewModel.goToDetailScreen(userModel: UserListItemViewData(
            id: 42,
            displayName: "Anton Charny",
            reputationText: Self.makeExpectedReputationText(from: 10_000),
            avatarURL: nil,
            isFollowed: false,
            followButtonTitle: UserListViewModel.Strings.followButtonTitle
        ))

        #expect(selectedUser == expectedUser)
    }

    private static func makeExpectedReputationText(from reputation: Int) -> String {
        let reputationFormatter = NumberFormatter()
        reputationFormatter.numberStyle = .decimal

        let formattedValue = reputationFormatter.string(from: NSNumber(value: reputation)) ?? "\(reputation)"
        return "\(UserListViewModel.Strings.reputationPrefix) \(formattedValue)"
    }

    private static func makeUsers(ids: ClosedRange<Int>) -> [StackUser] {
        ids.map { id in
            StackUser.fixture(
                id: id,
                displayName: "User \(id)",
                reputation: id * 1_000,
                avatarURL: nil
            )
        }
    }

    private static func waitForFetchCallCount(
        _ expectedCount: Int,
        in repository: DeferredUsersRepository,
        sourceLocation: SourceLocation = #_sourceLocation
    ) async {
        for _ in 0..<100 where repository.fetchUsersCalls.count < expectedCount {
            await Task.yield()
        }

        #expect(repository.fetchUsersCalls.count == expectedCount, sourceLocation: sourceLocation)
    }
}

private final class DeferredUsersRepository: UsersRepositoryProtocol {
    internal private(set) var fetchUsersCalls: [MockUsersRepository.FetchUsersCall] = []
    private var completions: [(Result<UsersPage, Error>) -> Void] = []

    internal func fetchUsers(
        sort: UserSortOption,
        order: UserSortOrder,
        page: Int,
        pageSize: Int
    ) async throws -> UsersPage {
        self.fetchUsersCalls.append(MockUsersRepository.FetchUsersCall(
            sort: sort,
            order: order,
            page: page,
            pageSize: pageSize
        ))

        return try await withCheckedThrowingContinuation { continuation in
            self.completions.append { result in
                continuation.resume(with: result)
            }
        }
    }

    internal func succeedRequest(
        at index: Int,
        users: [StackUser],
        hasMore: Bool = false
    ) {
        self.completions[index](.success(UsersPage(users: users, hasMore: hasMore)))
    }
}
