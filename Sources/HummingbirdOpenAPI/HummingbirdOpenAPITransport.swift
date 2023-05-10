import Foundation
import Hummingbird
import NIOHTTP1
import OpenAPIRuntime

/// Hummingbird Transport for OpenAPI generator
public struct HBOpenAPITransport: ServerTransport {
    let application: HBApplication

    /// Initialise ``HBOpenAPITransport``
    /// - Parameter application: Hummingbird application
    public init(_ application: HBApplication) {
        self.application = application
    }
}

extension HBOpenAPITransport {
    /// Registers an HTTP operation handler at the provided path and method.
    /// - Parameters:
    ///   - handler: A handler to be invoked when an HTTP request is received.
    ///   - method: An HTTP request method.
    ///   - path: The URL path components, for example `["pets", ":petId"]`.
    ///   - queryItemNames: The names of query items to be extracted
    ///   from the request URL that matches the provided HTTP operation.
    public func register(
        _ handler: @escaping @Sendable (Request, ServerRequestMetadata) async throws -> Response,
        method: OpenAPIRuntime.HTTPMethod,
        path: [OpenAPIRuntime.RouterPathComponent],
        queryItemNames: Set<String>
    ) throws {
        self.application.router.on(
            Self.makeHummingbirdPath(from: path), // path.map(\.hbPathComponent).joined(separator: "/"),
            method: .init(method)
        ) { request in
            let openAPIRequest = try request.makeOpenAPIRequest()
            let openAPIRequestMetadata = request.makeOpenAPIRequestMetadata()
            let openAPIResponse: Response = try await handler(openAPIRequest, openAPIRequestMetadata)
            return openAPIResponse.makeHBResponse()
        }
    }

    /// Make hummingbird path string from RouterPathComponent array
    static func makeHummingbirdPath(from path: [OpenAPIRuntime.RouterPathComponent]) -> String {
        path.map(\.hbPathComponent).joined(separator: "/")
    }
}

extension RouterPathComponent {
    /// Return path component as String
    var hbPathComponent: String {
        switch self {
        case .constant(let string):
            return string
        case .parameter(let parameter):
            return "${\(parameter)}"
        }
    }
}

extension HBRequest {
    /// Construct ``OpenAPIRuntime.Request`` from Hummingbird ``HBRequest``
    func makeOpenAPIRequest() throws -> Request {
        guard let method = OpenAPIRuntime.HTTPMethod(self.method) else {
            // if we cannot create an OpenAPI http method then we can't create a
            // a request and there is no handler for this method
            throw HBHTTPError(.notFound)
        }
        let headers: [HeaderField] = self.headers.map { .init(name: $0.name, value: $0.value) }
        let body = self.body.buffer.map { Data(buffer: $0, byteTransferStrategy: .noCopy) }
        return .init(
            path: self.uri.path,
            query: self.uri.query,
            method: method,
            headerFields: headers,
            body: body
        )
    }

    /// Construct ``OpenAPIRuntime.ServerRequestMetadata`` from Hummingbird ``HBRequest``
    /// - Parameter queryItemNames: Query items required from ``HBRequest``
    /// - Returns: Constructed ServerRequestMetadata
    func makeOpenAPIRequestMetadata() -> ServerRequestMetadata {
        let keyAndValues = self.parameters.map { (key: String($0.0), value: String($0.1)) }
        let openAPIParameters = [String: String](keyAndValues) { first, _ in first }
        let openAPIQueryItems = self.uri.queryParameters.map { URLQueryItem(name: String($0.key), value: String($0.value)) }
        return .init(
            pathParameters: openAPIParameters,
            queryParameters: openAPIQueryItems
        )
    }
}

extension Response {
    /// Construct Hummingbird ``HBResponse`` from ``OpenAPIRuntime.Response``
    func makeHBResponse() -> HBResponse {
        let statusCode = HTTPResponseStatus(statusCode: self.statusCode)
        let headers = HTTPHeaders(self.headerFields.map { (name: $0.name, value: $0.value) })
        let body = ByteBuffer(data: self.body)
        return .init(
            status: statusCode,
            headers: headers,
            body: .byteBuffer(body)
        )
    }
}

extension OpenAPIRuntime.HTTPMethod {
    init?(_ method: NIOHTTP1.HTTPMethod) {
        switch method {
        case .GET: self = .get
        case .PUT: self = .put
        case .POST: self = .post
        case .DELETE: self = .delete
        case .OPTIONS: self = .options
        case .HEAD: self = .head
        case .PATCH: self = .patch
        case .TRACE: self = .trace
        default: return nil
        }
    }
}

extension NIOHTTP1.HTTPMethod {
    init(_ method: OpenAPIRuntime.HTTPMethod) {
        switch method {
        case .get:
            self = .GET
        case .put:
            self = .PUT
        case .post:
            self = .POST
        case .delete:
            self = .DELETE
        case .options:
            self = .OPTIONS
        case .head:
            self = .HEAD
        case .patch:
            self = .PATCH
        case .trace:
            self = .TRACE
        default:
            self = .RAW(value: method.name)
        }
    }
}
