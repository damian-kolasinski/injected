# Injected

A lightweight, `@MainActor`-bound dependency injection library for Swift.

## Installation

Add the package to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/damian-kolasinski/injected.git", from: "1.0.0")
]
```

Then add `"Injected"` to your target's dependencies.

## Quick Start

```swift
import Injected

// Register
DependencyContainer.shared.register(.lazy { NetworkService() })

// Inject
class ProfileViewModel {
    @Injected(resolve: .lazy) var network: NetworkService
}
```

## Registration Strategies

| Strategy | Factory called | Instance cached |
|----------|---------------|-----------------|
| `.eager(instance)` | Immediately (by you) | Yes |
| `.lazy { ... }` | On first resolve | Yes |
| `.volatile { ... }` | On every resolve | No |

### Eager

Provide a pre-built instance. Returned as-is on every resolution.

```swift
container.register(.eager(AnalyticsService()))
```

### Lazy

The factory runs once on first resolution; the result is cached for all subsequent resolutions.

```swift
container.register(.lazy { DatabaseService() })
```

### Volatile

A fresh instance is created on every resolution. Useful for stateful, short-lived objects.

```swift
container.register(.volatile { RequestContext() })
```

### Protocol Registration

Register a concrete type under a protocol so consumers depend on the abstraction:

```swift
container.register(.eager(RealService()), for: ServiceProtocol.self)

class ViewModel {
    @Injected(resolve: .lazy) var service: ServiceProtocol
}
```

## Testing

Use `DependencyContainer.$shared.withValue(...)` to replace the container in tests:

```swift
@Test("ViewModel uses mock service")
func viewModelUsesMock() async {
    let testContainer = DependencyContainer()
    testContainer.register(.eager(MockService()), for: ServiceProtocol.self)

    await DependencyContainer.$shared.withValue(testContainer) {
        let vm = ViewModel()
        #expect(vm.service is MockService)
    }
}
```

## Wrapping `@Injected` in Your App

`@Injected` requires an explicit `ResolveStrategy` so each call site declares its intent. In practice you'll want a single policy for your entire app. The recommended approach is a thin wrapper that encodes that policy:

```swift
@MainActor
@propertyWrapper
final class Dependency<T> {
    private let injected: Injected<T>

    init(key: String? = nil) {
        self.injected = Injected(resolve: AppEnvironment.isTest ? .eager : .lazy, key: key)
    }

    var wrappedValue: T {
        injected.wrappedValue
    }
}
```

Now your feature code uses `@Dependency` with no strategy argument, and the resolution policy is defined in one place:

```swift
class ProfileViewModel {
    @Dependency var analytics: AnalyticsProviding
}
```

## Design Decisions

### Why a required `ResolveStrategy` parameter

Production code benefits from lazy resolution (zero-cost init, resolve on first access). Tests benefit from eager resolution — a missing registration crashes at construction time rather than deep in a Combine chain or async call.

Rather than hiding this choice behind a compilation flag or global setting, `@Injected` makes it an explicit init parameter. This keeps the library simple and portable (no SPM flag propagation issues), and lets each app define its own resolution policy via a wrapper property wrapper.

### Why `@MainActor`

DI resolution happens during object initialisation and property access — main-thread work in iOS/macOS apps. `@MainActor` eliminates all synchronisation overhead (no locks, no atomics). The container itself is near-zero overhead: a dictionary lookup + switch branch — nanoseconds. The dominant cost is always the dependency itself, not the container. `@MainActor` ensures this stays true by avoiding any locking mechanism.

If a dependency needs to perform heavy work, offload it inside the service using `@concurrent`:

```swift
protocol ImageProcessing {
    func process(_ image: UIImage) async -> UIImage
}

final class ImageProcessor: ImageProcessing {
    @concurrent
    func process(_ image: UIImage) async -> UIImage {
        applyFilters(to: image) // runs on the global executor
    }
}
```

The service is resolved on `@MainActor`, but `@concurrent` methods automatically run on the global executor. Callers stay simple — the concurrency boundary lives in the implementation, not at the injection site.

## Releasing

Push a semver tag to create a GitHub Release with auto-generated notes:

```bash
git tag 1.x.x && git push --tags
```

## License

MIT — see [LICENSE](LICENSE) for details.
