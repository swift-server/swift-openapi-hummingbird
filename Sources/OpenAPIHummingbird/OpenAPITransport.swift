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

struct TaskLocalRequestContext<Context: RequestContext> {
    @TaskLocal static var instance: Context?
}

extension RouterMethods {
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
            .init(path),
            method: method
        ) { request, context in
            let (openAPIRequest, openAPIRequestBody) = try request.makeOpenAPIRequest(context: context)
            let openAPIRequestMetadata = context.makeOpenAPIRequestMetadata()
            let (openAPIResponse, openAPIResponseBody) = try await TaskLocalRequestContext<Context>.$instance.withValue(context) {
                TaskLocalRequestContext<Context>.instance?.logger.info("Yeah")
                try await handler(openAPIRequest, openAPIRequestBody, openAPIRequestMetadata) 
            }
            return Response(openAPIResponse, body: openAPIResponseBody)
        }
    }
}

extension Request {
    /// Construct ``OpenAPIRuntime.Request`` from Hummingbird ``Request``
    func makeOpenAPIRequest<Context: RequestContext>(context: Context) throws -> (HTTPRequest, HTTPBody?) {
        let request = self.head
        // extract length from content-length header
        let length = if let contentLengthHeader = self.headers[.contentLength], let contentLength = Int(contentLengthHeader) {
            HTTPBody.Length.known(numericCast(contentLength))
        } else {
            HTTPBody.Length.unknown
        }
        let body = HTTPBody(
            self.body.map { [UInt8](buffer: $0) },
            length: length,
            iterationBehavior: .single
        )
        return (request, body)
    }
}

extension RequestContext {
    /// Construct ``OpenAPIRuntime.ServerRequestMetadata`` from Hummingbird ``Request``
    func makeOpenAPIRequestMetadata() -> ServerRequestMetadata {
        let keyAndValues = self.parameters.map { (key: String($0.0), value: $0.1) }
        let openAPIParameters = [String: Substring](keyAndValues) { first, _ in first }
        return .init(
            pathParameters: openAPIParameters
        )
    }
}

extension Response {
    init(_ response: HTTPResponse, body: HTTPBody?) {
        let responseBody: ResponseBody
        if let body = body {
            let bufferSequence = body.map { ByteBuffer(bytes: $0)}
            if case .known(let length) = body.length {
                responseBody = .init(contentLength: numericCast(length)) { writer in
                    for try await buffer in bufferSequence {
                        try await writer.write(buffer)
                    }
                    try await writer.finish(nil)
                }
            } else {
                responseBody = .init(asyncSequence: bufferSequence)
            }
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

#if hasFeature(RetroactiveAttribute)
extension Router: @retroactive ServerTransport {}
extension RouterGroup: @retroactive ServerTransport {}
extension RouteCollection: @retroactive ServerTransport {}
#else
extension Router: ServerTransport {}
extension RouterGroup: ServerTransport {}
extension RouteCollection: ServerTransport {}
#endif