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

import HTTPTypes
import Hummingbird
import HummingbirdCore
import HummingbirdXCT
import NIOCore
import NIOHTTP1
import OpenAPIRuntime
import NIOHTTPTypes
import XCTest

@testable import OpenAPIHummingbird

extension HTTPField.Name {
    static let xMumble = Self("X-Mumble")!
    static let host = Self("host")!
}

final class HBOpenAPITransportTests: XCTestCase {
    func test_requestConversion() async throws {
        let router = HBRouter()

        router.post("/hello/:name") { hbRequest, context -> HBResponse in
            // Hijack the request handler to test the request-conversion functions.
            let expectedRequest = HTTPRequest(
                method: .post,
                scheme: nil,
                authority: nil,
                path: "/hello/Maria?greeting=Howdy",
                headerFields: [
                    .xMumble: "mumble",
                    .connection: "keep-alive",
                    .host: "localhost",
                    .contentLength: "4",
                ]
            )
            let expectedRequestMetadata = ServerRequestMetadata(
                pathParameters: ["name": "Maria"]
            )
            let (request, body) = try hbRequest.makeOpenAPIRequest(context: context)
            let collectedBody: [UInt8]
            if let body = body {
                collectedBody = try await .init(collecting: body, upTo: .max)
            } else {
                collectedBody = []
            }
            XCTAssertEqual(request, expectedRequest)
            XCTAssertEqual(collectedBody, [UInt8]("👋".utf8))
            XCTAssertEqual(context.makeOpenAPIRequestMetadata(), expectedRequestMetadata)

            // Use the response-conversion to create the HBRequest for returning.
            let response = HTTPResponse(status: .created, headerFields: [.xMumble: "mumble"])
            return HBResponse(response, body: .init([UInt8]("👋".utf8)))
        }

        let app = HBApplication(responder: router.buildResponder())

        try await app.test(.live) { client in
            try await client.XCTExecute(
                uri: "/hello/Maria?greeting=Howdy",
                method: .post,
                headers: [
                    .xMumble: "mumble",
                ],
                body: ByteBuffer(string: "👋")
            ) { hbResponse in
                // Check the HBResponse (created from the Response) is what meets expectations.
                XCTAssertEqual(hbResponse.status, .created)
                XCTAssertEqual(hbResponse.headers[.xMumble], "mumble")
                XCTAssertEqual(try String(buffer: XCTUnwrap(hbResponse.body)), "👋")
            }
        }
    }

    func test_largeBody() async throws {
        let router = HBRouter()
        let bytes = (0..<1_000_000).map { _ in UInt8.random(in: 0...255)}
        let byteBuffer = ByteBuffer(bytes: bytes)

        router.post("/hello/:name") { hbRequest, context -> HBResponse in
            // Hijack the request handler to test the request-conversion functions.
            let expectedRequest = HTTPRequest(
                method: .post,
                scheme: "http",
                authority: "localhost",
                path: "/hello/Maria?greeting=Howdy",
                headerFields: [
                    .connection: "keep-alive",
                    .contentLength: "1000000",
                ]
            )
            let expectedRequestMetadata = ServerRequestMetadata(
                pathParameters: ["name": "Maria"]
            )
            let (request, body) = try hbRequest.makeOpenAPIRequest(context: context)
            XCTAssertEqual(request, expectedRequest)
            XCTAssertEqual(context.makeOpenAPIRequestMetadata(), expectedRequestMetadata)

            // Use the response-conversion to create the HBRequest for returning.
            let response = HTTPResponse(status: .ok)
            return HBResponse(response, body: body)
        }

        let app = HBApplication(
            router: router,
            server: .http1(
                additionalChannelHandlers: [
                    BreakupHTTPBodyChannelHandler()
                ]
            )
        )

        try await app.test(.live) { client in
            try await client.XCTExecute(
                uri: "/hello/Maria?greeting=Howdy",
                method: .post,
                body: byteBuffer
            ) { hbResponse in
                // Check the HBResponse (created from the Response) is what meets expectations.
                XCTAssertEqual(hbResponse.status, .ok)
                XCTAssertEqual(byteBuffer, hbResponse.body)
            }
        }
    }
}

/// To test streaming we need to break up the HTTP body into multiple chunks. This channel handler
/// breaks up the incoming HTTP body into multiple chunks
class BreakupHTTPBodyChannelHandler: ChannelInboundHandler, RemovableChannelHandler {
    typealias InboundIn = HTTPRequestPart
    typealias InboundOut = HTTPRequestPart

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let part = unwrapInboundIn(data)

        switch part {
        case .head, .end:
            context.fireChannelRead(data)
        case .body(var buffer):
            while buffer.readableBytes > 0 {
                let size = min(32768, buffer.readableBytes)
                let slice = buffer.readSlice(length: size)!
                context.fireChannelRead(self.wrapInboundOut(.body(slice)))
            }
        }
    }
}
