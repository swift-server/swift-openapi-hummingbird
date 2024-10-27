# Swift OpenAPI Hummingbird

Hummingbird transport for [OpenAPI generator](https://github.com/apple/swift-openapi-generator).

```swift
// Create your router.
let router = Router()

// Create an instance of your handler type that conforms the generated protocol
// defining your service API.
let api = MyServiceAPIImpl()

// Call the generated function on your implementation to add its request
// handlers to the app.
try api.registerHandlers(on: router)

// Create the application and run as you would normally.
let app = Application(router: router)
try await app.runService()
```

## RequestContext

It is a common requirement that the router `RequestContext` is needed in OpenAPI endpoints. You can do this by adding a middleware that stores the RequestContext in a TaskLocal. 

```swift
struct RequestContextMiddleware: RouterMiddleware {
    typealias Context = MyRequestContext
    @TaskLocal static var requestContext: Context?

    func handle(_ request: Request, context: Context, next: (Request, Context) async throws -> Response) async throws -> Response {
        try await Self.$requestContext.withValue(context) {
            try await next(request, context)
        }
    }
}
```

If you add a version of this middleware, replacing `MyRequestContext` with your own `RequestContext`, to the end of your router middleware chain then the request context is available via `RequestContextMiddleware.requestContext`.

## Documentation

To get started, check out the full [documentation][docs-generator], which contains step-by-step tutorials!

[docs-generator]: https://swiftpackageindex.com/apple/swift-openapi-generator/documentation
