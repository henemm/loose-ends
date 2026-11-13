---
entity_id: fix-883-widget-nachziehen-schnitt2
type: bug
created: 2026-11-13
updated: 2026-11-13
status: draft
workflow: fix-883-widget-schnitt2
---

# Spec: #883 Schnitt 2 — Die App lädt das Widget „Als nächstes“ auch beim Öffnen neu

## Approval

- [ ] Approved (Henning)

Henning, 2026-11-13: Das Widget „Als nächstes“ zeigt nach Änderungen keinen neuen Stand, auf dem Mac **und** auf dem iPad. Er hat auf einem
anderen Gerät (iPhone oder Mac) geändert, das Widget blieb alt. Seine Beobachtung stammt vom Stand **ohne** Schnitt 1 (PR #901 steckt in
keinem TestFlight-Bau). Hat es früher funktioniert? Nein, auf dem Mac nie geprüft, also keine belegte Verschlechterung.

## Purpose

Schnitt 1 lädt das Widget bei jedem Speichern und jedem Import neu, solange die App läuft. Eine Lücke bleibt:

**Eine im Hintergrund oder beendete App importiert nicht** (Foren 654059, 682156, 739864: stille Pushes starten eine weggewischte App praktisch
nie). Dann gibt es nichts, was das Widget neu lädt, bis die App wieder geöffnet wird. Beim Öffnen holt sie den Stand ein, aber heute lädt
nur ein Import oder ein Speichern das Widget neu, nicht das Öffnen selbst.

Dieser Schnitt: die App lädt das Widget auch beim Wechsel in den Vordergrund neu. Kein Modell im Spiel; Regel und Beobachter.

**Teil A entfällt (Rücksprung 2026-11-13, nach dem Nachstellen).** Die erste Fassung vermutete zusätzlich, der Widget-Prozess lese über den
zwischengespeicherten Container (`ModelContainerFactory.make(syncs: false)`) alte Zeilen (Apple-Forum 668144) und wollte ihn durch einen je Aufruf frisch
geöffneten ersetzen. Der Test dazu (zwei Container auf einer temporären Datei, ein Leser, der erst liest und nach dem Schreiben des zweiten
Containers mit frischem `ModelContext` erneut liest) war **schon gegen den bisherigen, zwischengespeicherten Weg grün**: der Zwischenspeicher
hält hier keine alten Zeilen fest. Hypothese widerlegt, kein Bau ohne Beleg. Grenze des Befunds: der Test bildet den Widget-Abruf nach, ohne einen
echten, langlebigen Widget-Prozess; ob der iPad-/Mac-Befund eine andere Ursache hat, zeigt der TestFlight-Durchlauf (Definition of Done).

Nicht Teil dieses Schnitts: Zeitplan des Widgets (`.after(+15 min)`), iCloud für das Widget (#307), Watch-Komplikation, `Shared/Models`
(kein CloudKit-Deploy), `ModelContainerFactory` (bleibt unverändert), ein Hintergrundstart der App durch Pushes (nicht zu erzwingen, siehe Alternativen).

## Source

- **Geändert:** `LooseEnds/App/WidgetReload.swift` (Beobachter für den Wechsel in den Vordergrund)
- **Geändert:** `LooseEndsTests/WidgetReloadTests.swift` (AC-3)

## Implementation Details

**`WidgetReload.start()`.** Dritter Beobachter: `UIApplication.didBecomeActiveNotification` (iOS) bzw. `NSApplication.didBecomeActiveNotification`
(macOS), wie in `ClaudeSyncTrigger` (kein `scenePhase`, das fehlt bei geschlossenem Mac-Fenster) → `reloadSoon()`. Dieselbe 1-s-Bündelung,
derselbe stille Produkt-Closure unter Tests. Der Produkt-Closure schreibt vor `reloadTimelines` die Zeile `Widget reload requested` ins Log.

## Acceptance Criteria

- **AC-3:** Eine im Unit-Test gesendete „App wird aktiv“-Meldung löst genau ein Neuladen aus; zehn Meldungen innerhalb einer Sekunde ergeben
  genau eines (Unit-Test, Neuladen eingespeist).
- **AC-4:** Die Beobachter von Schnitt 1 (Speichern, beendeter Import) laden weiter neu: alle `WidgetReloadTests` aus Schnitt 1 bleiben grün.
- **AC-6:** `./scripts/sim.sh unit` und `build` grün, `generate` hinterlässt keinen Diff.
- **AC-7:** Simulator-Durchlauf (App starten, Aufgabe erfassen, in den Hintergrund und zurück) ohne Absturz; `WidgetReload` schreibt bei jedem
  Neuladen die feste Protokollzeile `Widget reload requested` (Kategorie „Widget“, Subsystem `com.henning.looseends`), im Simulator-Log
  nach dem Zurückkehren in den Vordergrund mindestens einmal zu finden.

(AC-1, AC-2, AC-5 der ersten Fassung gehörten zu Teil A und entfallen; die Nummern bleiben, damit Verweise stabil sind.)

## Definition of Done

- AC-3, AC-4, AC-6 und AC-7 erfüllt, Tests und Build grün, PR mit `Refs #883`, gemergt nach grüner CI.
- Gerätepunkt (Stufe 3, TestFlight, iPad und Mac): Henning erledigt am iPhone eine Aufgabe; öffnet er danach die App auf iPad oder Mac,
  zeigt das Widget „Als nächstes“ binnen Sekunden den neuen Stand; mit laufender App auch ohne Öffnen binnen weniger Minuten. Erst seine
  Rückmeldung schließt das Ticket. Der TestFlight-Bau enthält Schnitt 1 **und** 2 (Schnitt 1 war noch in keinem Bau). Zeigt das Widget auch
  danach alte Zeilen, ist die Ursache eine andere und bekommt ein eigenes Ticket.

## Test Plan

- `WidgetReloadTests`: `testBecomingActiveReloadsOnce`, `testBurstOfActiveMessagesReloadsOnce` (AC-3), bestehende Tests unverändert (AC-4).
- AC-6 und AC-7: `./scripts/sim.sh unit`, `build`, `generate`, `launch` plus `screenshot` und Log-Abfrage; UI-Smoke in der CI.

## Abnahme

Stufe 1 (Unit-Tests) und Stufe 2 (Simulator, Vordergrundwechsel durchgespielt) sind Pflicht. Ein Widget auf dem Mac und die Auslieferung
echter Pushes zeigt der Simulator nicht. Der Schnitt berührt `LooseEnds/App/WidgetReload.swift`; das steht nicht in der Geräteliste, die
Beobachtung am echten Widget bleibt aber offen, weil Henning den Fehler auf iPad und Mac sieht. Deshalb der Gerätepunkt in der Definition of
Done über TestFlight, nicht als AC; `Refs #883` statt `Closes #883`. Nichts auf Hennings Geräten ohne sein „jetzt ist ein Test möglich“.
Henning bekommt danach in einfachen Worten, was er ausprobieren soll.

## Alternativen (verworfen)

- **A (erste Fassung):** Widget liest je Aufruf über einen frisch geöffneten Container: am Nachstellen widerlegt (Test grün gegen den bisherigen Weg).
- **B:** Zeitplan des Widgets auf 5 min kürzen: budgetiert, ändert nichts an der Lücke bei geschlossener App.
- **C:** Widget bekommt eigenes iCloud: scheitert am Entitlement (#307), würde die App-Gruppe als einzige Quelle kippen.
- **D:** Hintergrundstart der App erzwingen (Push, `BGAppRefreshTask` für Sync): vom System budgetiert und für weggewischte Apps nicht
  zugesagt; nicht belegbar, ohne Gerät nicht prüfbar.
- **E:** Nur Schnitt 1 ausliefern und prüfen, nichts bauen: legitim, weil Henning ohne Schnitt 1 beobachtet hat. Der TestFlight-Bau trägt
  deshalb beide Schnitte.

## Scope

2 Dateien (beide geändert), etwa +40 LoC, im Limit. Keine Berechtigung, kein Schlüssel, kein Katalogeintrag, kein Modell.

## Architektur-Entscheidung (ADR)

**ADR-Nr.:** keine neue; ergänzt #307 (Widget liest über die App-Gruppe) und Schnitt 1 (Neuladen auch beim Öffnen).

## Changelog

- 2026-11-13: Teil A (frischer Container, AC-1, AC-2, AC-5) gestrichen, am Nachstellen widerlegt; nur Teil B bleibt.
