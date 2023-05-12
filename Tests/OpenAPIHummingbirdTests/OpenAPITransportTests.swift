import Hummingbird
import HummingbirdXCT
@testable import OpenAPIHummingbird
import OpenAPIRuntime
import XCTest

final class HBOpenAPITransportTests: XCTestCase {
    func test_makeHummingbirdPath() throws {
        XCTAssert(function: HBOpenAPITransport.makeHummingbirdPath(from:), behavesAccordingTo: [
            ([], ""),
            ([.constant("hello")], "hello"),
            ([.constant("hello"), .constant("world")], "hello/world"),
            ([.constant("hello"), .parameter("name")], "hello/${name}"),
            ([.parameter("greeting"), .constant("world")], "${greeting}/world"),
            ([.parameter("greeting"), .parameter("name")], "${greeting}/${name}"),
        ])
    }

    func test_requestConversion() async throws {
        let app = HBApplication(testing: .embedded)

        app.router.post("/hello/:name") { hbRequest in
            // Hijack the request handler to test the request-conversion functions.
            let expectedRequest = Request(
                path: "/hello/Maria",
                query: "greeting=Howdy",
                method: .post,
                headerFields: [
                    .init(name: "X-Mumble", value: "mumble"),
                ],
                body: Data("👋".utf8)
            )
            let expectedRequestMetadata = ServerRequestMetadata(
                pathParameters: ["name": "Maria"],
                queryParameters: [.init(name: "greeting", value: "Howdy")]
            )
            let request = try hbRequest.makeOpenAPIRequest()
            XCTAssertEqual(request, expectedRequest)
            XCTAssertEqual(hbRequest.makeOpenAPIRequestMetadata(), expectedRequestMetadata)

            // Use the response-conversion to create the HBRequest for returning.
            let response = Response(
                statusCode: 201,
                headerFields: [
                    .init(name: "X-Mumble", value: "mumble"),
                ],
                body: Data("👋".utf8)
            )
            return response.makeHBResponse()
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

    func testHTTPMethodConversion() throws {
        XCTAssert(function: Hummingbird.HTTPMethod.init(_:), behavesAccordingTo: [
            (.get, .GET),
            (.put, .PUT),
            (.post, .POST),
            (.delete, .DELETE),
            (.options, .OPTIONS),
            (.head, .HEAD),
            (.patch, .PATCH),
            (.trace, .TRACE),
        ])
        XCTAssert(function: OpenAPIRuntime.HTTPMethod.init(_:), behavesAccordingTo: [
            (.GET, .get),
            (.PUT, .put),
            (.POST, .post),
            (.DELETE, .delete),
            (.OPTIONS, .options),
            (.HEAD, .head),
            (.PATCH, .patch),
            (.TRACE, .trace),
        ])
    }
}

private func XCTAssert<Input, Output>(
    function: (Input) throws -> Output,
    behavesAccordingTo expectations: [(Input, Output)],
    file: StaticString = #file,
    line: UInt = #line
) rethrows where Output: Equatable {
    for (input, output) in expectations {
        try XCTAssertEqual(function(input), output, file: file, line: line)
    }
}
