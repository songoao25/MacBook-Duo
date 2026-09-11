import Foundation

@main
struct PermissionPreparationTests {
    static func main() {
        let suite = "studio.prototype.HingeGlass.permission-tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        typealias Preparation = ScreenCapturePermissionPreparation
        assert(Preparation.needsReset(identity: "build-a", defaults: defaults))
        // A failure does not write a successful migration marker.
        assert(Preparation.needsReset(identity: "build-a", defaults: defaults))
        Preparation.recordSuccess(identity: "build-a", defaults: defaults)
        assert(!Preparation.needsReset(identity: "build-a", defaults: defaults))
        let reopened = UserDefaults(suiteName: suite)!
        assert(!Preparation.needsReset(identity: "build-a", defaults: reopened))
        assert(Preparation.needsReset(identity: "build-b", defaults: reopened))
        Preparation.recordSuccess(identity: "build-b", defaults: reopened)
        assert(!Preparation.needsReset(identity: "build-b", defaults: reopened))
        print("PASS: first launch, persisted relaunch, changed build identity")
    }
}
