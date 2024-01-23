# Swift OpenAPI Hummingbird

Hummingbird transport for [OpenAPI generator](https://github.com/apple/swift-openapi-generator).

```swift
// Create your router.
let router = HBRouter()

// Create an instance of your handler type that conforms the generated protocol
// defining your service API.
let api = MyServiceAPIImpl()

// Call the generated function on your implementation to add its request
// handlers to the app.
try api.registerHandlers(on: router)

// Create the application and run as you would normally.
let app = HBApplication(router: router)
try await app.runService()
```

## Documentation

To get started, check out the full [documentation][docs-generator], which contains step-by-step tutorials!

[docs-generator]: https://swiftpackageindex.com/apple/swift-openapi-generator/documentation
