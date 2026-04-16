//
//  UsersRepositoryTests.swift
//  stackOverflowTestTask
//
//  Created by Anton Charny on 07.04.2026.
//

import Foundation
import Testing
@testable import stackOverflowTestTask

@MainActor
struct UsersRepositoryTests {
    @Test
    func fetchTopUsersBuildsExpectedRequest() async throws {
        let httpClient = MockHTTPClient()
        httpClient.result = .success((Data(#"{"items":[]}"#.utf8), makeHTTPURLResponse(statusCode: 200)))
        let repository = UsersRepository(httpClient: httpClient)

        _ = try await repository.fetchTopUsers()

        let request = try #require(httpClient.recordedRequests.first)
        #expect(request.httpMethod == "GET")
        #expect(request.url?.scheme == "https")
        #expect(request.url?.host == "api.stackexchange.com")
        #expect(request.url?.path == "/2.2/users")

        let url = try #require(request.url)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let queryItems = components.queryItems ?? []

        #expect(queryItems.contains(URLQueryItem(name: "page", value: "1")))
        #expect(queryItems.contains(URLQueryItem(name: "pagesize", value: "20")))
        #expect(queryItems.contains(URLQueryItem(name: "order", value: "desc")))
        #expect(queryItems.contains(URLQueryItem(name: "sort", value: "reputation")))
        #expect(queryItems.contains(URLQueryItem(name: "site", value: "stackoverflow")))
    }

    @Test
    func fetchUsersBuildsRequestWithSelectedSortAndOrder() async throws {
        let httpClient = MockHTTPClient()
        httpClient.result = .success((Data(#"{"items":[]}"#.utf8), makeHTTPURLResponse(statusCode: 200)))
        let repository = UsersRepository(httpClient: httpClient)

        _ = try await repository.fetchUsers(sort: .name, order: .ascending)

        let request = try #require(httpClient.recordedRequests.first)
        let url = try #require(request.url)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let queryItems = components.queryItems ?? []

        #expect(queryItems.contains(URLQueryItem(name: "order", value: "asc")))
        #expect(queryItems.contains(URLQueryItem(name: "sort", value: "name")))
    }

    @Test
    func fetchUsersBuildsRequestWithSelectedPageAndPageSize() async throws {
        let httpClient = MockHTTPClient()
        httpClient.result = .success((Data(#"{"items":[]}"#.utf8), makeHTTPURLResponse(statusCode: 200)))
        let repository = UsersRepository(httpClient: httpClient)

        _ = try await repository.fetchUsers(sort: .reputation, order: .descending, page: 3, pageSize: 50)

        let request = try #require(httpClient.recordedRequests.first)
        let url = try #require(request.url)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let queryItems = components.queryItems ?? []

        #expect(queryItems.contains(URLQueryItem(name: "page", value: "3")))
        #expect(queryItems.contains(URLQueryItem(name: "pagesize", value: "50")))
    }

    @Test
    func fetchTopUsersMapsResponsePayload() async throws {
        let httpClient = MockHTTPClient()
        httpClient.result = .success((Data(Self.validPayload.utf8), makeHTTPURLResponse(statusCode: 200)))
        let repository = UsersRepository(httpClient: httpClient)

        let users = try await repository.fetchTopUsers()

        #expect(users == [
            StackUser(
                id: 22656,
                displayName: "John Doe",
                reputation: 1_525_628,
                avatarURL: URL(string: "https://www.gravatar.com/avatar/example?s=256"),
                location: "New York, United States",
                websiteURL: URL(string: "https://example.com"),
                creationDate: Date(timeIntervalSince1970: 1_234_567_890),
                lastModifiedDate: Date(timeIntervalSince1970: 1_345_678_901)
            ),
        ])
    }

    @Test
    func fetchUsersMapsHasMorePayload() async throws {
        let httpClient = MockHTTPClient()
        httpClient.result = .success((Data(Self.validPayload.utf8), makeHTTPURLResponse(statusCode: 200)))
        let repository = UsersRepository(httpClient: httpClient)

        let page = try await repository.fetchUsers(sort: .reputation, order: .descending)

        #expect(page.hasMore)
        #expect(page.users.count == 1)
    }

    @Test
    func fetchTopUsersMapsEmptyItemsPayloadToEmptyArray() async throws {
        let httpClient = MockHTTPClient()
        httpClient.result = .success((Data(#"{"items":[]}"#.utf8), makeHTTPURLResponse(statusCode: 200)))
        let repository = UsersRepository(httpClient: httpClient)

        let users = try await repository.fetchTopUsers()

        #expect(users.isEmpty)
    }

    @Test
    func fetchTopUsersMapsNullProfileImageToNilAvatarURL() async throws {
        let httpClient = MockHTTPClient()
        httpClient.result = .success((Data(Self.validPayloadWithNullProfileImage.utf8), makeHTTPURLResponse(statusCode: 200)))
        let repository = UsersRepository(httpClient: httpClient)

        let users = try await repository.fetchTopUsers()

        #expect(users == [
            StackUser(
                id: 22656,
                displayName: "John Doe",
                reputation: 1_525_628,
                avatarURL: nil,
                location: nil,
                websiteURL: nil,
                creationDate: nil,
                lastModifiedDate: nil
            ),
        ])
    }

    @Test
    func fetchTopUsersMapsTransportErrors() async {
        let httpClient = MockHTTPClient()
        httpClient.result = .failure(URLError(.notConnectedToInternet))
        let repository = UsersRepository(httpClient: httpClient)

        await #expect(throws: UsersRepositoryError.transport) {
            _ = try await repository.fetchTopUsers()
        }
    }

    @Test
    func fetchTopUsersMapsServerStatusErrors() async {
        let httpClient = MockHTTPClient()
        httpClient.result = .success((Data(), makeHTTPURLResponse(statusCode: 503)))
        let repository = UsersRepository(httpClient: httpClient)

        await #expect(throws: UsersRepositoryError.serverStatus(503)) {
            _ = try await repository.fetchTopUsers()
        }
    }

    @Test
    func fetchTopUsersMapsRateLimitStatusErrors() async {
        let httpClient = MockHTTPClient()
        httpClient.result = .success((
            Data(),
            makeHTTPURLResponse(statusCode: 429, headerFields: ["Retry-After": "30"])
        ))
        let repository = UsersRepository(httpClient: httpClient)

        await #expect(throws: UsersRepositoryError.rateLimited(retryAfterSeconds: 30)) {
            _ = try await repository.fetchTopUsers()
        }
    }

    @Test
    func fetchTopUsersMapsDecodingErrors() async {
        let httpClient = MockHTTPClient()
        httpClient.result = .success((Data(#"{"items":[{"user_id":"wrong"}]}"#.utf8), makeHTTPURLResponse(statusCode: 200)))
        let repository = UsersRepository(httpClient: httpClient)

        await #expect(throws: UsersRepositoryError.decoding) {
            _ = try await repository.fetchTopUsers()
        }
    }

    @Test
    func fetchTopUsersMapsInvalidResponseErrors() async {
        let httpClient = MockHTTPClient()
        httpClient.result = .failure(HTTPClientError.invalidResponse)
        let repository = UsersRepository(httpClient: httpClient)

        await #expect(throws: UsersRepositoryError.invalidResponse) {
            _ = try await repository.fetchTopUsers()
        }
    }

    @Test
    func fetchTopUsersMapsMissingRequiredFieldsAsDecodingError() async {
        let httpClient = MockHTTPClient()
        httpClient.result = .success((Data(#"{"items":[{"user_id":22656,"reputation":1525628}]}"#.utf8), makeHTTPURLResponse(statusCode: 200)))
        let repository = UsersRepository(httpClient: httpClient)

        await #expect(throws: UsersRepositoryError.decoding) {
            _ = try await repository.fetchTopUsers()
        }
    }

    private static let validPayload = """
    {
      "items": [
        {
          "user_id": 22656,
          "display_name": "John Doe",
          "reputation": 1525628,
          "profile_image": "https://www.gravatar.com/avatar/example?s=256",
          "location": "New York, United States",
          "website_url": "https://example.com",
          "creation_date": 1234567890,
          "last_modified_date": 1345678901
        }
      ],
      "has_more": true
    }
    """

    private static let validPayloadWithNullProfileImage = """
    {
      "items": [
        {
          "user_id": 22656,
          "display_name": "John Doe",
          "reputation": 1525628,
          "profile_image": null
        }
      ]
    }
    """
}

private func makeHTTPURLResponse(
    statusCode: Int,
    headerFields: [String: String]? = nil
) -> HTTPURLResponse {
    HTTPURLResponse(
        url: URL(string: "https://api.stackexchange.com/2.2/users")!,
        statusCode: statusCode,
        httpVersion: nil,
        headerFields: headerFields
    )!
}
