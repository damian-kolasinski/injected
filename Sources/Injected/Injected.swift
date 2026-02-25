/// A property wrapper that resolves a dependency from ``DependencyContainer/shared``.
///
/// ## Lazy resolution (default)
///
/// The dependency is resolved on first access of `wrappedValue`, not at init time.
/// This means the dependency does not need to be registered yet when the owning object is created.
///
/// ```swift
/// class ProfileViewModel {
///     @Injected(resolve: .lazy) var analytics: AnalyticsProviding
/// }
/// ```
///
/// ## Eager resolution
///
/// The dependency is resolved immediately at init time. A missing registration crashes
/// at construction time rather than deep in a Combine chain or async call — useful for tests.
///
/// ```swift
/// class ProfileViewModel {
///     @Injected(resolve: .eager) var analytics: AnalyticsProviding
/// }
/// ```
///
/// ## Explicit key
///
/// ```swift
/// @Injected(resolve: .lazy, key: "myService") var service: ServiceProtocol
/// ```
@MainActor
@propertyWrapper
public final class Injected<Dependency> {
    deinit {}

    /// Controls when the dependency is resolved from the container.
    public enum ResolveStrategy {
        /// Resolve immediately at init time.
        case eager
        /// Defer resolution until first access of `wrappedValue`.
        case lazy
    }

    private var dependency: Dependency?
    private let explicitKey: String?

    /// Creates the property wrapper with the given resolution strategy.
    ///
    /// - Parameters:
    ///   - strategy: Whether to resolve eagerly (at init) or lazily (on first access).
    ///   - key: An optional string key. When `nil`, the type name is used.
    public init(resolve strategy: ResolveStrategy, key: String? = nil) {
        self.explicitKey = key

        if case .eager = strategy {
            let resolved: Dependency = key.map {
                DependencyContainer.shared.resolve(key: $0)
            } ?? DependencyContainer.shared.resolve()
            self.dependency = resolved
        }
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
}
