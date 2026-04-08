//
//  MockHTTPClient.swift
//  stackOverflowTestTask
//
//  Created by Anton Charny on 08.04.2026.
//

import Foundation

final class MockHTTPClient: HTTPClientProtocol {
    internal private(set) var recordedRequests: [URLRequest] = []
    internal var result: Result<(Data, HTTPURLResponse), Error>?

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        self.recordedRequests.append(request)

        guard let result else {
            fatalError("MockHTTPClient.result must be set before use.")
        }

        switch result {
        case let .success(value):
            return value
        case let .failure(error):
            throw error
        }
    }
}
