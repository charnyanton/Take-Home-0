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

    private static func makeExpectedReputationText(from reputation: Int) -> String {
        let reputationFormatter = NumberFormatter()
        reputationFormatter.numberStyle = .decimal

        let formattedValue = reputationFormatter.string(from: NSNumber(value: reputation)) ?? "\(reputation)"
        return "\(UserListViewModel.Strings.reputationPrefix) \(formattedValue)"
    }
}
