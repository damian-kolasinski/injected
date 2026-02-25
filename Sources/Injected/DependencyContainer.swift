/// A lightweight service locator that stores dependency registrations keyed by type name or explicit string key.
///
/// `DependencyContainer` is bound to `@MainActor` — dependency registration and resolution happen
/// on the main thread, which eliminates all synchronisation overhead. The container itself is near-zero
/// cost: a dictionary lookup followed by a switch branch (nanoseconds). The dominant cost is always the
/// dependency being created, never the container.
///
/// A default instance is available via the `shared` task-local property. You can scope a different
/// container for a given task tree using `DependencyContainer.$shared.withValue(...)`.
///
/// ## Example
///
/// ```swift
/// let container = DependencyContainer.shared
/// container.register(.lazy { NetworkService() })
/// container.register(.eager(AnalyticsService()), for: AnalyticsProviding.self)
/// ```
@MainActor
public final class DependencyContainer {

    /// The current container for the calling task.
    ///
    /// Override it for a subtree with:
    /// ```swift
    /// DependencyContainer.$shared.withValue(myContainer) { … }
    /// ```
    @TaskLocal
    public static var shared = DependencyContainer()

    /// Creates an empty container.
    public init() {}

    // MARK: - Registration

    /// A strategy that controls when and how often a dependency's factory is invoked.
    public enum Registration<Dependency> {

        /// The dependency is created up front and returned as-is on every resolution.
        case eager(Dependency)

        /// The dependency is created on first resolution and cached for all subsequent resolutions.
        case lazy(LazyStorage<Dependency>)

        /// The dependency is created fresh on every resolution.
        case volatile(() -> Dependency)

        /// Convenience factory that wraps a closure in ``LazyStorage``.
        ///
        /// ```swift
        /// container.register(.lazy { HeavyService() })
        /// ```
        public static func lazy(
            _ makeDependency: @escaping () -> Dependency
        ) -> Registration {
            .lazy(LazyStorage(makeDependency: makeDependency))
        }

        /// Once-only storage used by the ``lazy(_:)`` registration strategy.
        public final class LazyStorage<T> {
            deinit {}

            private var dep: T?
            private let makeDependency: () -> T

            /// Creates storage backed by the given factory.
            init(makeDependency: @escaping () -> T) {
                self.makeDependency = makeDependency
            }

            /// Returns the cached instance, creating it on first call.
            func get() -> T {
                if let existing = dep {
                    return existing
                }
                let newDep = makeDependency()
                dep = newDep
                return newDep
            }
        }
    }

    // MARK: - Storage

    private var storage = [String: Any]()

    // MARK: - Register

    /// Registers a dependency using its type name as the key.
    ///
    /// - Parameter registration: The registration strategy wrapping the dependency.
    public func register<Dependency>(
        _ registration: Registration<Dependency>
    ) {
        register(registration, for: Dependency.self)
    }

    /// Registers a dependency under an explicit type's name.
    ///
    /// Use this when the registration type differs from the protocol the consumers expect:
    /// ```swift
    /// container.register(.eager(RealService()), for: ServiceProtocol.self)
    /// ```
    ///
    /// - Parameters:
    ///   - registration: The registration strategy wrapping the dependency.
    ///   - type: The type whose name is used as the storage key.
    public func register<Dependency>(
        _ registration: Registration<Dependency>,
        for type: Dependency.Type
    ) {
        register(registration, for: String(describing: type))
    }

    /// Registers a dependency under an explicit string key.
    ///
    /// - Parameters:
    ///   - registration: The registration strategy wrapping the dependency.
    ///   - key: The string key to store the registration under.
    public func register<Dependency>(
        _ registration: Registration<Dependency>,
        for key: String
    ) {
        storage[key] = registration
    }

    // MARK: - Resolve

    func resolve<Dependency>() -> Dependency {
        resolve(key: String(describing: Dependency.self))
    }

    func resolve<Dependency>(key: String) -> Dependency {
        guard let value = storage[key] else {
            fatalError("\(key) not found — make sure the dependency is registered before resolution")
        }
        guard let registration = value as? Registration<Dependency> else {
            fatalError("\(key) contains invalid type — expected \(Dependency.self)")
        }
        switch registration {
        case .volatile(let createDependency): return createDependency()
        case .lazy(let storage): return storage.get()
        case .eager(let dependency): return dependency
        }
    }
}
