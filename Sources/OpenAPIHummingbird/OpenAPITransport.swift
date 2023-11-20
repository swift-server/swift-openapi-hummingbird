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

extension HBRouterBuilder {
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
            Self.makeHummingbirdPath(from: path),
            method: .init(rawValue: method.rawValue),
            options: .streamBody
        ) { request, context in
            let (openAPIRequest, openAPIRequestBody) = try request.makeOpenAPIRequest(context: context)
            let openAPIRequestMetadata = context.makeOpenAPIRequestMetadata()
            let (openAPIResponse, openAPIResponseBody) = try await handler(openAPIRequest, openAPIRequestBody, openAPIRequestMetadata)
            return HBResponse(openAPIResponse, body: openAPIResponseBody)
        }
    }

    /// Make hummingbird path string from OpenAPI path
    static func makeHummingbirdPath(from path: String) -> String {
        // frustratingly hummingbird supports `${parameter}` style path which is oh so close
        // to the OpenAPI `{parameter}` format
        return path.replacingOccurrences(of: "{", with: "${")
    }
}

extension HBRequest {
    /// Construct ``OpenAPIRuntime.Request`` from Hummingbird ``HBRequest``
    func makeOpenAPIRequest<Context: HBRequestContext>(context: Context) throws -> (HTTPRequest, HTTPBody?) {
        guard let method = HTTPRequest.Method(rawValue: self.method.rawValue) else {
            // if we cannot create an OpenAPI http method then we can't create a
            // a request and there is no handler for this method
            throw HBHTTPError(.notFound)
        }
        var httpFields = HTTPFields()
        for header in self.headers {
            if let fieldName = HTTPField.Name(header.name) {
                httpFields[fieldName] = header.value
            }
        }
        let request = HTTPRequest(
            method: method,
            scheme: nil,
            authority: nil,
            path: self.uri.string,
            headerFields: httpFields
        )
        let body: HTTPBody?
        switch self.body {
        case .byteBuffer(let buffer):
            body = HTTPBody([UInt8](buffer: buffer))
        case .stream(let streamer):
            body = .init(
                AsyncStreamerToByteChunkSequence(streamer: streamer),
                length: .unknown,
                iterationBehavior: .single
            )
        }
        return (request, body)
    }
}

extension HBRequestContext {
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
            status: .init(statusCode: response.status.code, reasonPhrase: response.status.reasonPhrase),
            headers: .init(response.headerFields.map { (key: $0.name.canonicalName, value: $0.value) }),
            body: responseBody
        )
    }
}
