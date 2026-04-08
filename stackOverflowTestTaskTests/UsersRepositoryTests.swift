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
                avatarURL: URL(string: "https://www.gravatar.com/avatar/example?s=256")
            ),
        ])
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
                avatarURL: nil
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
          "profile_image": "https://www.gravatar.com/avatar/example?s=256"
        }
      ]
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

private func makeHTTPURLResponse(statusCode: Int) -> HTTPURLResponse {
    HTTPURLResponse(
        url: URL(string: "https://api.stackexchange.com/2.2/users")!,
        statusCode: statusCode,
        httpVersion: nil,
        headerFields: nil
    )!
}
