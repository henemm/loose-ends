import Foundation
@testable import LooseEnds

/// Runs `body` with `packs` as the active language packs (#755). The packs are a task-local value: tests running
/// side by side in one process never see them, and they are gone when the closure ends or throws.
func withPacks<R>(_ packs: [LanguagePack], _ body: () throws -> R) rethrows -> R {
    try LanguagePacks.$pluggedIn.withValue(packs, operation: body)
}
