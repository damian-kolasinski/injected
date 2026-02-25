import Testing

@testable import Injected

@MainActor
@Suite("@Injected property wrapper")
struct InjectedTests {

    @Test("Resolves from DependencyContainer.shared")
    func resolvesFromShared() {
        let container = DependencyContainer.shared
        container.register(.eager(MockService(label: "shared")))

        let holder = Holder()
        #expect(holder.service.label == "shared")
    }

    @Test("Resolves from a scoped container via TaskLocal")
    func resolvesFromScopedContainer() {
        DependencyContainer.shared.register(.eager(MockService(label: "outer")))

        let scoped = DependencyContainer()
        scoped.register(.eager(MockService(label: "scoped")))

        let label = DependencyContainer.$shared.withValue(scoped) {
            let holder = Holder()
            return holder.service.label
        }

        #expect(label == "scoped")
    }

    @Test("Resolves with an explicit key")
    func resolvesWithExplicitKey() {
        DependencyContainer.shared.register(.eager(MockService(label: "keyed")), for: "myKey")

        let holder = KeyedHolder()
        #expect(holder.service.label == "keyed")
    }

    @Test("Lazy resolution — dependency resolved on first access, not at init")
    func lazyResolution() {
        var factoryCalled = false
        DependencyContainer.shared.register(.volatile {
            factoryCalled = true
            return MockService(label: "lazy")
        })

        let holder = Holder()
        #expect(!factoryCalled)

        _ = holder.service
        #expect(factoryCalled)
    }
}

// MARK: - Test Doubles

@MainActor
private final class MockService {
    let label: String
    init(label: String) {
        self.label = label
    }
}

@MainActor
private final class Holder {
    @Injected var service: MockService
}

@MainActor
private final class KeyedHolder {
    @Injected("myKey") var service: MockService
}
