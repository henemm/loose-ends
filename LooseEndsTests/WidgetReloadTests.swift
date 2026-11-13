import Foundation
import SwiftData
import Testing
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
@testable import LooseEnds

/// #883: the "Next up" widget reloads for every save and every finished CloudKit import, with no window
/// needed. Reload is handed in and counted; events are fed by hand (no test talks to CloudKit or WidgetKit).
@Suite("WidgetReload (#883)", .serialized) @MainActor struct WidgetReloadTests {
    final class Counter {
        var count = 0
    }

    private func make(_ counter: Counter) -> WidgetReload {
        WidgetReload(debounce: .milliseconds(60)) { counter.count += 1 }
    }

    private func settle() async throws {
        try await Task.sleep(for: .milliseconds(400))
    }

    private func event(_ kind: SyncStatus.Kind, ended: Date?, error: String? = nil) -> SyncStatus.Event {
        SyncStatus.Event(kind: kind, endDate: ended, errorMessage: error)
    }

    @Test("A finished, successful import reloads exactly once (AC-1)")
    func testFinishedImportReloadsOnce() async throws {
        let counter = Counter()
        let reload = make(counter)
        reload.handle(event(.imported, ended: Date()))
        try await settle()
        #expect(counter.count == 1)
    }

    @Test("An unfinished import, a failed import and an export reload nothing (AC-1)")
    func testUnfinishedFailedAndExportDoNotReload() async throws {
        let counter = Counter()
        let reload = make(counter)
        reload.handle(event(.imported, ended: nil))
        reload.handle(event(.imported, ended: Date(), error: "offline"))
        reload.handle(event(.exported, ended: Date()))
        reload.handle(event(.setup, ended: Date()))
        try await settle()
        #expect(counter.count == 0)
    }

    @Test("A save in the app's context reloads with no ContentView around (AC-2)")
    func testDidSaveReloadsWithoutAnyView() async throws {
        let counter = Counter()
        let reload = make(counter)
        reload.start()
        let store = try TestStore()
        store.context.insert(TaskItem(rawText: "Milch kaufen"))
        try store.context.save()
        try await settle()
        #expect(counter.count >= 1)
    }

    @Test("Ten messages within a second reload once (AC-3)")
    func testBurstOfTenMessagesReloadsOnce() async throws {
        let counter = Counter()
        let reload = make(counter)
        for _ in 0..<10 { reload.handle(event(.imported, ended: Date())) }
        try await settle()
        #expect(counter.count == 1)
    }

    private var becameActive: Notification.Name {
        #if canImport(UIKit)
        UIApplication.didBecomeActiveNotification
        #else
        NSApplication.didBecomeActiveNotification
        #endif
    }

    @Test("Becoming active reloads exactly once (#883 Schnitt 2, AC-3)")
    func testBecomingActiveReloadsOnce() async throws {
        let counter = Counter()
        let reload = make(counter)
        reload.start()
        NotificationCenter.default.post(name: becameActive, object: nil)
        try await settle()
        #expect(counter.count == 1)
    }

    @Test("Ten active messages within a second reload once (#883 Schnitt 2, AC-3)")
    func testBurstOfActiveMessagesReloadsOnce() async throws {
        let counter = Counter()
        let reload = make(counter)
        reload.start()
        for _ in 0..<10 { NotificationCenter.default.post(name: becameActive, object: nil) }
        try await settle()
        #expect(counter.count == 1)
    }

    private func source(_ relative: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8)
    }

    @Test("ContentView no longer calls reloadTimelines itself (AC-4)")
    func testContentViewNoLongerCallsReloadTimelines() throws {
        #expect(try !source("LooseEnds/App/ContentView.swift").contains("reloadTimelines"))
    }

    @Test("The app creates and starts one WidgetReload at process level (AC-4)")
    func testAppCreatesAndStartsWidgetReload() throws {
        let app = try source("LooseEnds/App/LooseEndsApp.swift")
        #expect(app.contains("WidgetReload("))
        #expect(app.contains("widgetReload.start()"))
    }
}
