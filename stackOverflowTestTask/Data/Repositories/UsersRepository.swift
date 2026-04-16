//
//  StackExchangeUsersRepository.swift
//  stackOverflowTestTask
//
//  Created by Anton Charny on 07.04.2026.
//

import Foundation

enum UsersRepositoryError: Error, Equatable {
    case invalidResponse
    case serverStatus(Int)
    case rateLimited(retryAfterSeconds: Int?)
    case transport
    case decoding
}

struct UsersRepository: UsersRepositoryProtocol {
    private let httpClient: HTTPClientProtocol
    private let decoder: JSONDecoder
    private let baseURL: URL

    internal init(
        httpClient: HTTPClientProtocol,
        decoder: JSONDecoder = JSONDecoder(),
        baseURL: URL = URL(string: "https://api.stackexchange.com")!
    ) {
        self.httpClient = httpClient
        self.decoder = decoder
        self.baseURL = baseURL
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
    }

    func fetchUsers(
        sort: UserSortOption,
        order: UserSortOrder,
        page: Int,
        pageSize: Int
    ) async throws -> UsersPage {
        let request = try self.makeRequest(sort: sort, order: order, page: page, pageSize: pageSize)
        self.log("Request: \(request.url?.absoluteString ?? "missing URL")")

        do {
            let (data, response) = try await self.httpClient.send(request)
            self.log("Response status: \(response.statusCode)")

            try self.validate(response)
            return try self.decodeUsersPage(from: data)
        } catch let error as UsersRepositoryError {
            self.log("Repository error: \(error)")
            throw error
        } catch let error as HTTPClientError {
            switch error {
            case .invalidResponse:
                self.log("Invalid HTTP response")
                throw UsersRepositoryError.invalidResponse
            }
        } catch {
            self.log("Transport error: \(error)")
            throw UsersRepositoryError.transport
        }
    }

    private func validate(_ response: HTTPURLResponse) throws {
        switch response.statusCode {
        case 429:
            let retryAfterSeconds = self.retryAfterSeconds(from: response)
            self.log("Rate limited. Retry after seconds: \(retryAfterSeconds.map(String.init) ?? "unknown")")
            throw UsersRepositoryError.rateLimited(retryAfterSeconds: retryAfterSeconds)
        case 200...299:
            return
        default:
            self.log("Server status error: \(response.statusCode)")
            throw UsersRepositoryError.serverStatus(response.statusCode)
        }
    }

    private func decodeUsersPage(from data: Data) throws -> UsersPage {
        do {
            let payload = try self.decoder.decode(UsersResponseDTO.self, from: data)
            let users = payload.items.map(\.stackUser)
            let hasMore = payload.hasMore ?? false
            self.log("Decoded users count: \(users.count), hasMore: \(hasMore)")
            return UsersPage(
                users: users,
                hasMore: hasMore
            )
        } catch {
            self.log("Decoding error: \(error)")
            throw UsersRepositoryError.decoding
        }
    }

    private func makeRequest(
        sort: UserSortOption,
        order: UserSortOrder,
        page: Int,
        pageSize: Int
    ) throws -> URLRequest {
        guard var components = URLComponents(
            url: self.baseURL.appending(path: "/2.2/users"),
            resolvingAgainstBaseURL: false
        ) else {
            throw UsersRepositoryError.invalidResponse
        }

        components.queryItems = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "pagesize", value: "\(pageSize)"),
            URLQueryItem(name: "order", value: order.rawValue),
            URLQueryItem(name: "sort", value: sort.rawValue),
            URLQueryItem(name: "site", value: "stackoverflow"),
        ]

        guard let url = components.url else {
            throw UsersRepositoryError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        return request
    }

    private func retryAfterSeconds(from response: HTTPURLResponse) -> Int? {
        guard let retryAfterValue = response.value(forHTTPHeaderField: "Retry-After") else {
            return nil
        }

        return Int(retryAfterValue)
    }

#if DEBUG
    private func log(_ message: String) {
        print("[UsersRepository] \(message)")
    }
#else
    private func log(_: String) {}
#endif
}
