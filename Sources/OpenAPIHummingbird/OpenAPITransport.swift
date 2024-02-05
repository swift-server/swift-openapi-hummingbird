//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2023 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Foundation
import HTTPTypes
import Hummingbird
import NIOHTTP1
import OpenAPIRuntime

extension HBRouter: ServerTransport {
    /// Registers an HTTP operation handler at the provided path and method.
    /// - Parameters:
    ///   - handler: A handler to be invoked when an HTTP request is received.
    ///   - method: An HTTP request method.
    ///   - path: The URL path components, for example `["pets", ":petId"]`.
    ///   - queryItemNames: The names of query items to be extracted
    ///   from the request URL that matches the provided HTTP operation.
    public func register(
        _ handler: @escaping @Sendable (HTTPRequest, HTTPBody?, ServerRequestMetadata) async throws -> (
            HTTPResponse, HTTPBody?
        ),
        method: HTTPRequest.Method,
        path: String
    ) throws {
        self.on(
            path,
            method: method
        ) { request, context in
            let (openAPIRequest, openAPIRequestBody) = try request.makeOpenAPIRequest(context: context)
            let openAPIRequestMetadata = context.makeOpenAPIRequestMetadata()
            let (openAPIResponse, openAPIResponseBody) = try await handler(openAPIRequest, openAPIRequestBody, openAPIRequestMetadata)
            return HBResponse(openAPIResponse, body: openAPIResponseBody)
        }
    }
}

extension HBRequest {
    /// Construct ``OpenAPIRuntime.Request`` from Hummingbird ``HBRequest``
    func makeOpenAPIRequest<Context: HBBaseRequestContext>(context: Context) throws -> (HTTPRequest, HTTPBody?) {
        let request = self.head
        let body = HTTPBody(
            self.body.map { [UInt8](buffer: $0) },
            length: .unknown,
            iterationBehavior: .single
        )
        return (request, body)
    }
}

extension HBBaseRequestContext {
    /// Construct ``OpenAPIRuntime.ServerRequestMetadata`` from Hummingbird ``HBRequest``
    func makeOpenAPIRequestMetadata() -> ServerRequestMetadata {
        let keyAndValues = self.parameters.map { (key: String($0.0), value: $0.1) }
        let openAPIParameters = [String: Substring](keyAndValues) { first, _ in first }
        return .init(
            pathParameters: openAPIParameters
        )
    }
}

extension HBResponse {
    init(_ response: HTTPResponse, body: HTTPBody?) {
        let responseBody: HBResponseBody
        if let body = body {
            let bufferSequence = body.map { ByteBuffer(bytes: $0)}
            responseBody = .init(asyncSequence: bufferSequence)
        } else {
            responseBody = .init(byteBuffer: ByteBuffer())
        }

        self.init(
            status: response.status,
            headers: response.headerFields,
            body: responseBody
        )
    }
}
