/// A property wrapper that resolves a dependency from ``DependencyContainer/shared``.
///
/// ## Default behaviour (lazy resolution)
///
/// The dependency is resolved on first access of `wrappedValue`, not at init time.
/// This means the dependency does not need to be registered yet when the owning object is created.
///
/// ```swift
/// class ProfileViewModel {
///     @Injected var analytics: AnalyticsProviding
/// }
/// ```
///
/// ## Eager resolution (`INJECTED_EAGER_RESOLVE`)
///
/// When the `INJECTED_EAGER_RESOLVE` Active Compilation Condition is set, the dependency is resolved
/// immediately in `init`. This is useful for tests — a missing registration crashes at construction
/// time rather than deep inside a call chain.
///
/// ## Explicit key
///
/// ```swift
/// @Injected("myService") var service: ServiceProtocol
/// ```
@MainActor
@propertyWrapper
public final class Injected<Dependency> {
    deinit {}

    #if INJECTED_EAGER_RESOLVE
    private let dependency: Dependency

    /// Creates the property wrapper and eagerly resolves the dependency.
    ///
    /// - Parameter explicitKey: An optional string key. When `nil`, the type name is used.
    public init(_ explicitKey: String? = nil) {
        self.dependency = explicitKey.map {
            DependencyContainer.shared.resolve(key: $0)
        } ?? DependencyContainer.shared.resolve()
    }

    public var wrappedValue: Dependency {
        dependency
    }
    #else
    private var dependency: Dependency?
    private let explicitKey: String?

    /// Creates the property wrapper. Resolution is deferred until first access.
    ///
    /// - Parameter explicitKey: An optional string key. When `nil`, the type name is used.
    public init(_ explicitKey: String? = nil) {
        self.explicitKey = explicitKey
    }

    public var wrappedValue: Dependency {
        if let resolvedValue = dependency {
            return resolvedValue
        }
        let value: Dependency = explicitKey.map {
            DependencyContainer.shared.resolve(key: $0)
        } ?? DependencyContainer.shared.resolve()
        dependency = value
        return value
    }
    #endif
}
