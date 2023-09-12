import HTTPTypes
import Hummingbird
import HummingbirdXCT
import NIOCore
import NIOHTTP1
import OpenAPIRuntime
import XCTest

@testable import OpenAPIHummingbird

extension HTTPField.Name {
    static let xMumble = Self("X-Mumble")!
    static let host = Self("host")!
}

final class HBOpenAPITransportTests: XCTestCase {
    func test_requestConversion() async throws {
        let app = HBApplication(testing: .live)

        app.router.post("/hello/:name") { hbRequest -> HBResponse in
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
                    .contentLength: "4"
                ]
            )
            let expectedRequestMetadata = ServerRequestMetadata(
                pathParameters: ["name": "Maria"]
            )
            let (request, body) = try hbRequest.makeOpenAPIRequest()
            let collectedBody = try await body?.collect(upTo: .max)
            XCTAssertEqual(request, expectedRequest)
            XCTAssertEqual(collectedBody, [UInt8]("👋".utf8)[...])
            XCTAssertEqual(hbRequest.makeOpenAPIRequestMetadata(), expectedRequestMetadata)

            // Use the response-conversion to create the HBRequest for returning.
            let response = HTTPResponse(status: .created, headerFields: [.xMumble: "mumble"])
            return HBResponse(response,  body: .init(bytes: [UInt8]("👋".utf8)))
        }

        try app.XCTStart()
        defer { app.XCTStop() }

        try app.XCTExecute(
            uri: "/hello/Maria?greeting=Howdy",
            method: .POST,
            headers: ["X-Mumble": "mumble"],
            body: ByteBuffer(string: "👋")
        ) { hbResponse in
            // Check the HBResponse (created from the Response) is what meets expectations.
            XCTAssertEqual(hbResponse.status, .created)
            XCTAssertEqual(hbResponse.headers.first(name: "X-Mumble"), "mumble")
            XCTAssertEqual(try String(buffer: XCTUnwrap(hbResponse.body)), "👋")
        }
    }

    func test_largeBody() async throws {
        let app = HBApplication(testing: .live)
        app.server.addChannelHandler(BreakupHTTPBodyChannelHandler())
        let bytes = (0..<1_000_000).map { _ in UInt8.random(in: 0...255)}
        let byteBuffer = ByteBuffer(bytes: bytes)

        app.router.post("/hello/:name") { hbRequest -> HBResponse in
            // Hijack the request handler to test the request-conversion functions.
            let expectedRequest = HTTPRequest(
                method: .post,                
                scheme: nil,
                authority: nil,
                path: "/hello/Maria?greeting=Howdy",
                headerFields: [
                    .connection: "keep-alive",
                    .host: "localhost",
                    .contentLength: "1000000"
                ]
            )
            let expectedRequestMetadata = ServerRequestMetadata(
                pathParameters: ["name": "Maria"]
            )
            let (request, body) = try hbRequest.makeOpenAPIRequest()
            XCTAssertEqual(request, expectedRequest)
            XCTAssertEqual(hbRequest.makeOpenAPIRequestMetadata(), expectedRequestMetadata)

            // Use the response-conversion to create the HBRequest for returning.
            let response = HTTPResponse(status: .ok)
            return HBResponse(response,  body: body)
        }

        try app.XCTStart()
        defer { app.XCTStop() }

        try app.XCTExecute(
            uri: "/hello/Maria?greeting=Howdy",
            method: .POST,
            body: byteBuffer
        ) { hbResponse in
            // Check the HBResponse (created from the Response) is what meets expectations.
            XCTAssertEqual(hbResponse.status, .ok)
            XCTAssertEqual(byteBuffer, hbResponse.body)
        }
    }
}

/// To test streaming we need to break up the HTTP body into multiple chunks. This channel handler
/// breaks up the incoming HTTP body into multiple chunks
class BreakupHTTPBodyChannelHandler: ChannelInboundHandler, RemovableChannelHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias InboundOut = HTTPServerRequestPart

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
