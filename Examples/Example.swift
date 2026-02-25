// Example.swift
// ─────────────────────────────────────────────────────────────────────
// A runnable example that demonstrates Injected's core features:
//
//   • Registration strategies — eager, lazy, volatile
//   • Protocol-based registration
//   • The @Dependency wrapper pattern
//   • Testing with scoped containers
// ─────────────────────────────────────────────────────────────────────

import Injected

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - App-Level @Dependency Wrapper
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Encodes a single resolution policy so feature code doesn't repeat
// the strategy at every call site.

@MainActor
@propertyWrapper
final class Dependency<T> {
    private let injected: Injected<T>

    init(key: String? = nil) {
        self.injected = Injected(resolve: .lazy, key: key)
    }

    var wrappedValue: T {
        injected.wrappedValue
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Protocols
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

@MainActor
protocol UserSessionProviding {
    var currentUserId: String? { get }
    var isLoggedIn: Bool { get }
}

@MainActor
protocol AnalyticsTracking {
    func track(event: String, properties: [String: String])
}

@MainActor
protocol ProfileWebService {
    func fetchProfile(userId: String) async throws -> String
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Stateful Service → .eager / .lazy
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Services that hold shared mutable state. Use .eager when the
// instance must exist from app launch, .lazy when you can defer
// creation until first access.

@MainActor
final class UserSession: UserSessionProviding {
    private(set) var currentUserId: String?
    var isLoggedIn: Bool { currentUserId != nil }

    func logIn(userId: String) { currentUserId = userId }
    func logOut() { currentUserId = nil }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Stateless Service With Init Logic → .lazy
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// The service itself is stateless, but construction is non-trivial
// (reads config, builds an internal pipeline, etc.). Use .lazy so the
// work happens once and the result is reused.

@MainActor
final class AnalyticsService: AnalyticsTracking {
    private let apiKey: String

    init() {
        // Simulate reading configuration at init time
        self.apiKey = "ak_live_abc123"
    }

    func track(event: String, properties: [String: String]) {
        print("[\(event)] \(properties)")
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Stateless Service → .volatile
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Pure functions wrapped in a type. No shared state, no setup cost.
// A fresh instance per injection site keeps things simple and avoids
// accidental coupling between call sites.

@MainActor
final class ProfileWebServiceImp: ProfileWebService {
    @Dependency var session: UserSessionProviding

    func fetchProfile(userId: String) async throws -> String {
        // URLSession call in a real app
        "Profile(\(userId))"
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Consumer
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

@MainActor
final class ProfileViewModel {
    @Dependency var session: UserSessionProviding
    @Dependency var analytics: AnalyticsTracking
    @Dependency var webService: ProfileWebService

    func onAppear() async {
        analytics.track(
            event: "profile_viewed",
            properties: ["user_id": session.currentUserId ?? "anonymous"]
        )
        if let userId = session.currentUserId {
            let profile = try? await webService.fetchProfile(userId: userId)
            print("Loaded: \(profile ?? "nil")")
        }
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Registration
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

@MainActor
func registerDependencies() {
    let container = DependencyContainer.shared

    // Stateful — created once at launch, same instance everywhere
    container.register(
        .eager(UserSession()),
        for: UserSessionProviding.self
    )

    // Stateless with init logic — created once on first access
    container.register(
        .lazy { AnalyticsService() },
        for: AnalyticsTracking.self
    )

    // Stateless — fresh instance every time it's injected
    container.register(
        .volatile { ProfileWebServiceImp() },
        for: ProfileWebService.self
    )
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Entry Point
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

@main
struct App {
    @MainActor
    static func main() async {
        registerDependencies()

        let vm = ProfileViewModel()
        await vm.onAppear()
    }
}
