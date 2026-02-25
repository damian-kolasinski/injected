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
    @Injected var network: NetworkService
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
    @Injected var service: ServiceProtocol
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

## Design Decisions

### Why `@MainActor`

DI resolution happens during object initialisation and property access — main-thread work in iOS/macOS apps. `@MainActor` eliminates all synchronisation overhead (no locks, no atomics). The container itself is near-zero overhead: a dictionary lookup + switch branch — nanoseconds. The dominant cost is always the dependency itself, not the container. `@MainActor` ensures this stays true by avoiding any locking mechanism.

If a dependency is needed off the main actor, capture it in a local variable first:

```swift
let service = viewModel.service // on MainActor
Task.detached {
    await service.doWork() // safe — captured before leaving MainActor
}
```

### Why `#if INJECTED_EAGER_RESOLVE`

Production uses lazy resolution (zero-cost init, `if let` on access). Tests benefit from eager resolution — a missing registration crashes at construction time rather than deep in a Combine chain or async call.

## Configuration

### Xcode / Tuist

Add `INJECTED_EAGER_RESOLVE` to **Active Compilation Conditions** on the *Injected* framework target's test build configuration (or the test target that imports it).

### SPM

The lazy path is always active when building with SPM. Tests still work — failures simply appear on first property access instead of at init time.

## License

MIT — see [LICENSE](LICENSE) for details.
