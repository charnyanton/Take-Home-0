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

    func fetchTopUsers() async throws -> [StackUser] {
        let request = try self.makeRequest()

        do {
            let (data, response) = try await self.httpClient.send(request)

            guard (200...299).contains(response.statusCode) else {
                throw UsersRepositoryError.serverStatus(response.statusCode)
            }

            print("Users response: \(String(data: data, encoding: .utf8))")

            do {
                let payload = try self.decoder.decode(UsersResponseDTO.self, from: data)
                return payload.items.map(\.stackUser)
            } catch {
                print("Decoding error: \(error)")
                throw UsersRepositoryError.decoding
            }
        } catch let error as UsersRepositoryError {
            throw error
        } catch let error as HTTPClientError {
            switch error {
            case .invalidResponse:
                throw UsersRepositoryError.invalidResponse
            }
        } catch {
            throw UsersRepositoryError.transport
        }
    }

    private func makeRequest() throws -> URLRequest {
        guard var components = URLComponents(
            url: self.baseURL.appending(path: "/2.2/users"),
            resolvingAgainstBaseURL: false
        ) else {
            throw UsersRepositoryError.invalidResponse
        }

        components.queryItems = [
            URLQueryItem(name: "page", value: "1"),
            URLQueryItem(name: "pagesize", value: "20"),
            URLQueryItem(name: "order", value: "desc"),
            URLQueryItem(name: "sort", value: "reputation"),
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
}
