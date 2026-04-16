//
//  UsersRepositoryProtocol.swift
//  stackOverflowTestTask
//
//  Created by Anton Charny on 07.04.2026.
//

import Foundation

enum UserSortOption: String, CaseIterable, Equatable {
    case reputation
    case creation
    case name
    case modified

    internal var title: String {
        switch self {
        case .reputation:
            return "Reputation"
        case .creation:
            return "Creation date"
        case .name:
            return "Name"
        case .modified:
            return "Last modified"
        }
    }
}

enum UserSortOrder: String, CaseIterable, Equatable {
    case ascending = "asc"
    case descending = "desc"

    internal var title: String {
        switch self {
        case .ascending:
            return "Ascending"
        case .descending:
            return "Descending"
        }
    }
}

struct UsersPage: Equatable {
    internal let users: [StackUser]
    internal let hasMore: Bool
}

protocol UsersRepositoryProtocol {
    func fetchUsers(
        sort: UserSortOption,
        order: UserSortOrder,
        page: Int,
        pageSize: Int
    ) async throws -> UsersPage
}

extension UsersRepositoryProtocol {
    internal func fetchTopUsers() async throws -> [StackUser] {
        (try await self.fetchUsers(sort: .reputation, order: .descending)).users
    }

    internal func fetchUsers(sort: UserSortOption, order: UserSortOrder) async throws -> UsersPage {
        try await self.fetchUsers(sort: sort, order: order, page: 1, pageSize: 20)
    }
}

#if DEBUG
final class MockUsersRepository: UsersRepositoryProtocol {
    struct FetchUsersCall: Equatable {
        internal let sort: UserSortOption
        internal let order: UserSortOrder
        internal let page: Int
        internal let pageSize: Int

        internal init(
            sort: UserSortOption,
            order: UserSortOrder,
            page: Int = 1,
            pageSize: Int = 20
        ) {
            self.sort = sort
            self.order = order
            self.page = page
            self.pageSize = pageSize
        }
    }

    internal private(set) var fetchUsersCalls: [FetchUsersCall] = []
    internal var result: Result<[StackUser], Error> = .success([])
    internal var hasMore = false
    internal var resultsByPage: [Int: Result<[StackUser], Error>] = [:]
    internal var hasMoreByPage: [Int: Bool] = [:]

    internal var fetchTopUsersCallCount: Int {
        self.fetchUsersCalls.count
    }

    func fetchUsers(
        sort: UserSortOption,
        order: UserSortOrder,
        page: Int,
        pageSize: Int
    ) async throws -> UsersPage {
        self.fetchUsersCalls.append(FetchUsersCall(
            sort: sort,
            order: order,
            page: page,
            pageSize: pageSize
        ))

        let result = self.resultsByPage[page] ?? self.result

        switch result {
        case let .success(users):
            return UsersPage(users: users, hasMore: self.hasMoreByPage[page] ?? self.hasMore)
        case let .failure(error):
            throw error
        }
    }
}
#endif
