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
    func loadEmitsLoadingThenContent() async {
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
        let viewModel = UserListViewModel(usersRepository: repository)
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
                    avatarURL: URL(string: "https://example.com/jon.png")
                ),
                UserListItemViewData(
                    id: 2,
                    displayName: "VonC",
                    reputationText: Self.makeExpectedReputationText(from: 1_368_324),
                    avatarURL: nil
                ),
            ]),
        ])
    }

    @Test
    func loadEmitsEmptyStateWhenRepositoryFails() async {
        let repository = MockUsersRepository()
        repository.result = .failure(UsersRepositoryError.transport)
        let viewModel = UserListViewModel(usersRepository: repository)
        var receivedStates: [UserListViewState] = []
        viewModel.onStateChange = { state in
            receivedStates.append(state)
        }

        await viewModel.load()

        #expect(receivedStates == [
            .loading,
            .empty("Unable to load StackOverflow users.\nPlease try again."),
        ])
    }

    private static func makeExpectedReputationText(from reputation: Int) -> String {
        let reputationFormatter = NumberFormatter()
        reputationFormatter.numberStyle = .decimal

        let formattedValue = reputationFormatter.string(from: NSNumber(value: reputation)) ?? "\(reputation)"
        return "Reputation: \(formattedValue)"
    }
}
