//
//  URLSessionHTTPClient.swift
//  stackOverflowTestTask
//
//  Created by Anton Charny on 07.04.2026.
//

import Foundation

final class URLSessionHTTPClient: HTTPClientProtocol {
    private let session: URLSession

    internal init(session: URLSession) {
        self.session = session
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await self.session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw HTTPClientError.invalidResponse
        }

        return (data, httpResponse)
    }
}
