//
//  UserDetailViewModelTests.swift
//  stackOverflowTestTaskTests
//
//  Created by Anton Charny on 15.04.2026.
//

import Foundation
@testable import stackOverflowTestTask
import Testing

@MainActor
struct UserDetailViewModelTests {

    @Test
    func loadEmitsContentWithPersistedFollowState() {
        let followStore = MockFollowStore(followedUserIDs: [1])
        let user = StackUser.fixture(
            id: 1,
            displayName: "Anton Charny",
            reputation: 12_345,
            avatarURL: URL(string: "https://example.com/avatar.png"),
            location: "Warsaw, Poland",
            websiteURL: URL(string: "https://example.com")
        )
        let viewModel = UserDetailViewModel(userModel: user, followStore: followStore)
        var receivedStates: [UserDetailViewState] = []
        viewModel.onStateChange = { state in
            receivedStates.append(state)
        }

        viewModel.load()

        #expect(receivedStates == [
            .content(UserDetailViewData(
                id: 1,
                displayName: "Anton Charny",
                reputationText: Self.makeExpectedReputationText(from: 12_345),
                avatarURL: URL(string: "https://example.com/avatar.png"),
                isFollowed: true,
                followStatusText: UserDetailViewModel.Strings.followedStatusText,
                followButtonTitle: UserDetailViewModel.Strings.unfollowButtonTitle,
                locationText: "Location: Warsaw, Poland",
                websiteURL: URL(string: "https://example.com"),
                websiteText: "Website: https://example.com"
            )),
        ])
    }

    @Test
    func toggleFollowPersistsAndEmitsUpdatedContent() {
        let followStore = MockFollowStore()
        let user = StackUser.fixture(id: 1, displayName: "Anton Charny", reputation: 12_345)
        let viewModel = UserDetailViewModel(userModel: user, followStore: followStore)
        var receivedStates: [UserDetailViewState] = []
        viewModel.onStateChange = { state in
            receivedStates.append(state)
        }

        viewModel.load()
        viewModel.toggleFollow()

        #expect(followStore.followedUserIDs() == Set([1]))
        #expect(followStore.recordedSetFollowedCalls == [
            MockFollowStore.SetFollowedCall(isFollowed: true, userID: 1),
        ])

        guard case let .content(viewData) = receivedStates.last else {
            Issue.record("Expected content state after toggling follow.")
            return
        }

        #expect(viewData.isFollowed)
        #expect(viewData.followStatusText == UserDetailViewModel.Strings.followedStatusText)
        #expect(viewData.followButtonTitle == UserDetailViewModel.Strings.unfollowButtonTitle)
    }

    @Test
    func loadOmitsWebsiteTextWhenWebsiteIsUnavailable() {
        let followStore = MockFollowStore()
        let user = StackUser.fixture(
            id: 1,
            displayName: "Anton Charny",
            reputation: 12_345,
            location: nil,
            websiteURL: nil
        )
        let viewModel = UserDetailViewModel(userModel: user, followStore: followStore)
        var receivedStates: [UserDetailViewState] = []
        viewModel.onStateChange = { state in
            receivedStates.append(state)
        }

        viewModel.load()

        guard case let .content(viewData) = receivedStates.last else {
            Issue.record("Expected content state after loading user detail.")
            return
        }

        #expect(viewData.locationText == "Location: Not provided")
        #expect(viewData.websiteURL == nil)
        #expect(viewData.websiteText == nil)
    }

    private static func makeExpectedReputationText(from reputation: Int) -> String {
        let reputationFormatter = NumberFormatter()
        reputationFormatter.numberStyle = .decimal

        let formattedValue = reputationFormatter.string(from: NSNumber(value: reputation)) ?? "\(reputation)"
        return "\(UserDetailViewModel.Strings.reputationPrefix) \(formattedValue)"
    }
}
