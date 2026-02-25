import Testing

@testable import Injected

@MainActor
@Suite("DependencyContainer")
struct DependencyContainerTests {

    // MARK: - Eager

    @Test("Eager registration resolves the same instance")
    func eagerResolution() {
        let container = DependencyContainer()
        let service = StubService()
        container.register(.eager(service))

        let resolved: StubService = container.resolve()
        #expect(resolved === service)
    }

    // MARK: - Lazy

    @Test("Lazy registration calls factory on first resolve and caches the result")
    func lazyCaching() {
        let container = DependencyContainer()
        var callCount = 0
        container.register(.lazy {
            callCount += 1
            return StubService()
        })

        let first: StubService = container.resolve()
        let second: StubService = container.resolve()

        #expect(callCount == 1)
        #expect(first === second)
    }

    // MARK: - Volatile

    @Test("Volatile registration creates a new instance on every resolve")
    func volatileResolution() {
        let container = DependencyContainer()
        var callCount = 0
        container.register(.volatile {
            callCount += 1
            return StubService()
        })

        let first: StubService = container.resolve()
        let second: StubService = container.resolve()

        #expect(callCount == 2)
        #expect(first !== second)
    }

    // MARK: - Explicit key

    @Test("Registration and resolution with an explicit string key")
    func explicitKey() {
        let container = DependencyContainer()
        let service = StubService()
        container.register(.eager(service), for: "customKey")

        let resolved: StubService = container.resolve(key: "customKey")
        #expect(resolved === service)
    }

    // MARK: - Protocol type registration

    @Test("Register a concrete type under a protocol type and resolve by protocol")
    func protocolTypeResolution() {
        let container = DependencyContainer()
        let service = StubService()
        container.register(.eager(service), for: StubProtocol.self)

        let resolved: StubProtocol = container.resolve()
        #expect(resolved === service)
    }

    // MARK: - TaskLocal scoping

    @Test("TaskLocal scoping resolves from the scoped container")
    func taskLocalScoping() {
        let outer = DependencyContainer.shared
        outer.register(.eager(StubService(label: "outer")))

        let scoped = DependencyContainer()
        scoped.register(.eager(StubService(label: "scoped")))

        let resolvedFromScoped: StubService = DependencyContainer.$shared.withValue(scoped) {
            DependencyContainer.shared.resolve()
        }

        let resolvedFromOuter: StubService = DependencyContainer.shared.resolve()

        #expect(resolvedFromScoped.label == "scoped")
        #expect(resolvedFromOuter.label == "outer")
    }
}

// MARK: - Test Doubles

@MainActor
protocol StubProtocol: AnyObject {
    var label: String { get }
}

@MainActor
final class StubService: StubProtocol {
    let label: String
    init(label: String = "default") {
        self.label = label
    }
}
