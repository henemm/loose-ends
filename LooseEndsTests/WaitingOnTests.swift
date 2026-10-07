import Foundation
import SwiftData
import Testing
@testable import LooseEnds

/// „Wartet auf“ von Hand (#251, Entscheidung zu #27): ein Verweis auf eine eigene Aufgabe, keine
/// Unteraufgabe. Verbinden und Lösen ändern nur die Verbindung, beide Aufgaben bleiben.
@Suite("Wartet auf: Verweise von Hand (#251)")
@MainActor
struct WaitingOnTests {
    private func task(_ rawText: String, in store: TestStore, minutesAgo: Double = 0) -> TaskItem {
        let task = TaskItem(rawText: rawText)
        task.status = .active
        task.capturedAt = Date(timeIntervalSince1970: 1_800_000_000 - minutesAgo * 60)
        store.context.insert(task)
        return task
    }

    @Test("Verbinden setzt den Verweis und schreibt eine Nutzer-Revision mit Titeln")
    func linkSetsBlockerAndRevision() throws {
        let store = try TestStore()
        let hedge = task("Hecke schneiden", in: store)
        let shears = task("Heckenschere holen", in: store)

        let revision = try #require(WaitingOn.link(shears, to: hedge))
        try store.context.save()

        #expect(hedge.isBlocked)
        #expect((shears.blocks ?? []).map(\.id) == [hedge.id], "die Gegenrichtung kennt SwiftData")
        #expect(revision.field == .blockedBy)
        #expect(revision.author == .user)
        #expect(revision.oldValue == nil)
        #expect(FieldCodec.decode(revision.newValue) == ["Heckenschere holen"])
    }

    @Test("Ein zweites Verbinden derselben Aufgabe ändert nichts")
    func linkingTwiceIsANoOp() throws {
        let store = try TestStore()
        let hedge = task("Hecke schneiden", in: store)
        let shears = task("Heckenschere holen", in: store)
        WaitingOn.link(shears, to: hedge)

        #expect(WaitingOn.link(shears, to: hedge) == nil)
        #expect(hedge.blockedBy?.count == 1)
        #expect((hedge.revisions ?? []).count == 1)
    }

    @Test("Lösen entfernt nur die Verbindung, beide Aufgaben bleiben")
    func loosenKeepsBothTasks() throws {
        let store = try TestStore()
        let hedge = task("Hecke schneiden", in: store)
        let shears = task("Heckenschere holen", in: store)
        let gloves = task("Handschuhe kaufen", in: store)
        WaitingOn.link(shears, to: hedge)
        WaitingOn.link(gloves, to: hedge)
        try store.context.save()

        let revision = try #require(WaitingOn.loosen(shears, from: hedge))
        try store.context.save()

        #expect((hedge.blockedBy ?? []).map(\.id) == [gloves.id])
        #expect(shears.isOpen, "die andere Aufgabe bleibt bestehen")
        #expect(try store.context.fetch(FetchDescriptor<TaskItem>()).count == 3)
        // Titelreihenfolge, nicht Verknüpfungsreihenfolge: SwiftData liefert die Beziehung nach dem
        // Speichern in beliebiger Folge (main, Lauf 37616537324).
        #expect(FieldCodec.decode(revision.oldValue) == ["Handschuhe kaufen", "Heckenschere holen"])
        #expect(FieldCodec.decode(revision.newValue) == ["Handschuhe kaufen"])
        #expect(WaitingOn.loosen(shears, from: hedge) == nil, "schon gelöst")
    }

    @Test("Ist die andere Aufgabe erledigt, wartet die Aufgabe nicht mehr; der Verweis bleibt sichtbar")
    func doneBlockerStaysVisibleButUnblocks() throws {
        let store = try TestStore()
        let hedge = task("Hecke schneiden", in: store)
        let shears = task("Heckenschere holen", in: store)
        let gloves = task("Handschuhe kaufen", in: store)
        WaitingOn.link(shears, to: hedge)
        WaitingOn.link(gloves, to: hedge)

        TaskActions.complete(shears)

        #expect(hedge.isBlocked, "die Handschuhe fehlen noch")
        #expect(WaitingOn.blockers(of: hedge).map(\.rawText) == ["Handschuhe kaufen", "Heckenschere holen"],
                "offene zuerst, erledigte danach")
        TaskActions.complete(gloves)
        #expect(!hedge.isBlocked)
        #expect(WaitingOn.blockers(of: hedge).count == 2)
    }

    @Test("Die Auswahl bietet nur offene, fremde, noch nicht verbundene Aufgaben der obersten Ebene an")
    func candidatesExcludeSelfLinkedDoneAndSubtasks() throws {
        let store = try TestStore()
        let hedge = task("Hecke schneiden", in: store)
        let shears = task("Heckenschere holen", in: store, minutesAgo: 10)
        let gloves = task("Handschuhe kaufen", in: store, minutesAgo: 5)
        let done = task("Rasen mähen", in: store)
        TaskActions.complete(done)
        let sub = task("Akku laden", in: store)
        sub.parent = shears
        WaitingOn.link(shears, to: hedge)
        try store.context.save()

        let all = try store.context.fetch(FetchDescriptor<TaskItem>())
        #expect(WaitingOn.candidates(for: hedge, among: all).map(\.id) == [gloves.id])
    }

    @Test("Eine Aufgabe, die (auch über andere) auf diese wartet, wird nicht angeboten: kein Kreis")
    func candidatesExcludeTheWaitingChain() throws {
        let store = try TestStore()
        let a = task("Angebot einholen", in: store)
        let b = task("Auftrag erteilen", in: store)
        let c = task("Termin vereinbaren", in: store)
        let d = task("Zettel sortieren", in: store)
        WaitingOn.link(a, to: b)   // b wartet auf a
        WaitingOn.link(b, to: c)   // c wartet auf b
        try store.context.save()

        let all = try store.context.fetch(FetchDescriptor<TaskItem>())
        #expect(Set(WaitingOn.candidates(for: a, among: all).map(\.id)) == [d.id])
        #expect(WaitingOn.link(c, to: a) == nil, "a auf c warten zu lassen schlösse den Kreis")
        #expect((a.blockedBy ?? []).isEmpty)
    }

    @Test("Die Suche findet Titel und Rohtext, ohne Rücksicht auf Groß- und Kleinschreibung oder Akzente")
    func candidatesFilterByQuery() throws {
        let store = try TestStore()
        let hedge = task("Hecke schneiden", in: store)
        let call = task("Müller anrufen wegen Angebot", in: store)
        call.title = "Müller anrufen"
        _ = task("Zettel sortieren", in: store)
        try store.context.save()

        let all = try store.context.fetch(FetchDescriptor<TaskItem>())
        #expect(WaitingOn.candidates(for: hedge, among: all, matching: "muller").map(\.id) == [call.id])
        #expect(WaitingOn.candidates(for: hedge, among: all, matching: "angebot").map(\.id) == [call.id])
        #expect(WaitingOn.candidates(for: hedge, among: all, matching: "  ").count == 2)
    }

    @Test("Die Listenzeile nennt die erste offene Aufgabe, gekürzt, und zählt weitere")
    func rowLabel() throws {
        let store = try TestStore()
        let hedge = task("Hecke schneiden", in: store)
        #expect(WaitingOn.rowLabel(for: hedge) == nil)

        let offer = task("Angebot vom Gartenbauer für die neue Hecke einholen", in: store)
        WaitingOn.link(offer, to: hedge)
        #expect(WaitingOn.rowLabel(for: hedge) == "Angebot vom Gartenbauer…")

        let shears = task("Schere holen", in: store)
        WaitingOn.link(shears, to: hedge)
        #expect(WaitingOn.rowLabel(for: hedge) == "Angebot vom Gartenbauer… +1")

        TaskActions.complete(offer)
        TaskActions.complete(shears)
        #expect(WaitingOn.rowLabel(for: hedge) == nil, "alles erledigt: wartet nicht mehr")
    }
}
