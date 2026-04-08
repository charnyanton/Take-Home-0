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
}

enum UserListViewState: Equatable {
    case idle
    case loading
    case content([UserListItemViewData])
    case empty(String)
}

@MainActor
final class UserListViewModel {
    internal var onStateChange: ((UserListViewState) -> Void)?

    private var state: UserListViewState = .idle {
        didSet {
            self.onStateChange?(self.state)
        }
    }

    private let usersRepository: UsersRepositoryProtocol
    private lazy var reputationFormatter: NumberFormatter = {
        let reputationFormatter = NumberFormatter()
        reputationFormatter.numberStyle = .decimal
        return reputationFormatter
    }()

    internal init(usersRepository: UsersRepositoryProtocol) {
        self.usersRepository = usersRepository
    }

    internal func load() async {
        self.state = .loading

        do {
            let users = try await self.usersRepository.fetchTopUsers()
            let items = users.map { user in
                UserListItemViewData(
                    id: user.id,
                    displayName: user.displayName,
                    reputationText: self.makeReputationText(from: user.reputation),
                    avatarURL: user.avatarURL
                )
            }
            self.state = items.isEmpty ? .empty("No StackOverflow users found.") : .content(items)
        } catch {
            self.state = .empty("Unable to load StackOverflow users.\nPlease try again.")
        }
    }

    internal func retry() async {
        await self.load()
    }

    private func makeReputationText(from reputation: Int) -> String {
        let formattedValue = self.reputationFormatter.string(from: NSNumber(value: reputation)) ?? "\(reputation)"
        return "Reputation: \(formattedValue)"
    }
}
