//
//  HTTPClientProtocol.swift
//  stackOverflowTestTask
//
//  Created by Anton Charny on 07.04.2026.
//

import Foundation

protocol HTTPClientProtocol {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

enum HTTPClientError: Error {
    case invalidResponse
}
