//
//  UsersRepositoryProtocol.swift
//  stackOverflowTestTask
//
//  Created by Anton Charny on 07.04.2026.
//

import Foundation

protocol UsersRepositoryProtocol {
    func fetchTopUsers() async throws -> [StackUser]
}

#if DEBUG
final class MockUsersRepository: UsersRepositoryProtocol {
    internal private(set) var fetchTopUsersCallCount = 0
    internal var result: Result<[StackUser], Error> = .success([])

    func fetchTopUsers() async throws -> [StackUser] {
        self.fetchTopUsersCallCount += 1

        switch self.result {
        case let .success(users):
            return users
        case let .failure(error):
            throw error
        }
    }
}
#endif
