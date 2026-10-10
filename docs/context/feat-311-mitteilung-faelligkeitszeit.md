# Context: feat-311-mitteilung-faelligkeitszeit

Issue: [#311](https://github.com/henemm/loose-ends/issues/311) — Mitteilung zur Fälligkeitszeit, Uhrzeit ohne Fälligkeitszeit einstellbar
Phase 1 erstellt am 2026-10-10.

## Request Summary

Heute plant `DueReminders.plan` pro aktiver Aufgabe genau eine Mitteilung „Heute fällig“, immer am
Fälligkeitstag um 9:00 — auch wenn die Aufgabe eine Uhrzeit trägt. Ist 9:00 vorbei, entfällt sie
(Gerätetest zu #295: Aufgabe für heute angelegt, keine Mitteilung). Soll: Aufgaben mit Uhrzeit melden
sich zu dieser Uhrzeit, Aufgaben ohne Uhrzeit zu einer einstellbaren Stunde (Standard 9:00).

## PO-Entscheidungen (Henning, 2026-10-10, via Intake)

| Frage | Entscheidung |
|---|---|
| Wo wird die Uhrzeit eingestellt? | **Neuer Bildschirm „Einstellungen“**: Zahnrad in der Seitenleiste, Abschnitt „Mitteilungen“; auf dem Mac zusätzlich App-Menü > Einstellungen (⌘,) |
| Gilt sie geräteübergreifend? | **Ja, auf allen Geräten gleich** (über iCloud) |
| Text bei Aufgabe mit Uhrzeit | **„Jetzt fällig“**; ohne Uhrzeit bleibt **„Heute fällig“** |
| Vorwarnung morgens für Aufgaben mit Uhrzeit? | **Nein**, nur eine Mitteilung zur Fälligkeitszeit |

## Related Files

| Datei | Relevanz |
|---|---|
| `Shared/Notifications/DueReminders.swift` (63 LoC) | `plan(for:hour:now:calendar:)` setzt immer `hour:00` (Zeile 34). Neu: `dueHasTime` → `dueDate` selbst; sonst eingestellte Stunde (und Minute?). `Reminder` braucht die Art (jetzt/heute) für den Text |
| `LooseEnds/Notifications/DueNotificationCenter.swift` (132 LoC) | `reschedule()` ruft `plan(for:)` ohne Stunde (Zeile 61) → muss die Einstellung lesen; `request(for:)` setzt fest `"Due today"` (Zeile 77). Änderung der Einstellung muss `reschedule()` auslösen. **Gerätelisten-Pfad → Stufe 3** |
| `LooseEndsTests/DueRemindersTests.swift` | bestehende Tests nehmen 9:00 an; neue Fälle: mit Uhrzeit, ohne Uhrzeit mit eingestellter Stunde, Zeit vorbei |
| `LooseEnds/Views/SidebarView.swift` | Ort für den Einstieg (Zahnrad); `@AppStorage` wird hier schon für Ansichtsschalter benutzt |
| `LooseEnds/App/LooseEndsApp.swift` | hält `DueNotificationCenter`; auf macOS kommt die `Settings`-Szene dazu |
| `LooseEnds/App/ContentView.swift:80, 133` | `rescheduleSoon()` nach jedem Speichern, `reschedule()` beim Start — eine Änderung der Einstellung speichert nichts im Store, braucht also einen eigenen Auslöser |
| `LooseEnds/LooseEnds.entitlements` | hat CloudKit, aber **kein** `com.apple.developer.ubiquity-kvstore-identifier` → für iCloud-Synchronisierung per `NSUbiquitousKeyValueStore` nötig. **Gerätelisten-Pfad → Stufe 3** |
| `docs/project/02-datenmodell-und-ansichten.md:167-171` | Abschnitt „Mitteilungen“ anpassen (zwei Texte, Uhrzeit aus Aufgabe, Einstellung) |
| `Localizable.xcstrings` | neuer Text „Now due“/„Jetzt fällig“, Bildschirmtitel und Beschriftungen |

## Existing Patterns

- **Reine Planung, dünne Systemschicht:** `DueReminders` ist rein und testbar (Kalender und `now`
  hereingereicht), `DueNotificationCenter` spiegelt nur. Die Einstellung kommt als Parameter in
  `plan`, nicht als Lesezugriff darin.
- **Gerätelokale Schalter in `UserDefaults`/`@AppStorage`** (`SidebarView`, `OnboardingFlow`,
  `CalendarBridge`). Geräteübergreifende Einstellungen gibt es noch keine — hier entsteht das erste
  Muster.
- **`dueHasTime` ist ein Flag neben `dueDate`** (kein eigener Zeit-Slot); `TaskActions.move` setzt es
  auf `false` („ein verschobener Task behält den Tag, nicht die Uhrzeit“).
- **Unter Tests stumm:** `DueNotificationCenter.suppressed` — UI-Smoke kann den Bildschirm prüfen,
  nicht die Zustellung.

## Dependencies

- Upstream: `TaskItem.dueDate`/`dueHasTime` (Regelparser #95, Wiederholung #102/#127, Editor).
- Downstream: Zustellung echter Mitteilungen (nur Gerät), Aktionen Erledigt/Als nächstes/Morgen bleiben unverändert.
- Keine Änderung an `Shared/Models` → kein `mac-schema-init`, kein CloudKit-Deploy.

## Risks & Considerations

1. **Synchronisierung über iCloud KVS** braucht eine neue Berechtigung in der App-Entitlements-Datei
   (und ggf. Watch/Mac-Varianten nicht). Mit cloud-managed Signing in `testflight.yml` und der
   Prüfkennung `.probe` (#156) muss die Fähigkeit im Profil landen — beim ersten Gerätebau ggf.
   Registrierungslauf. Alternative ohne Entitlement wäre ein Einstellungs-Datensatz in SwiftData —
   das wäre eine Modelländerung (CloudKit-Deploy), daher nicht bevorzugt. Entscheidung in der Analyse.
2. **Minuten-Granularität:** Ticket sagt „Stunde“; ein `DatePicker` mit `.hourAndMinute` ist kaum
   teurer. In der Analyse festlegen (Vorschlag: Stunde und Minute).
3. **Aufgaben mit Uhrzeit, deren Zeit heute schon vorbei ist:** keine Mitteilung (DoD). Aufgaben
   ohne Uhrzeit, die nach der eingestellten Stunde heute angelegt werden: ebenfalls keine — genau
   Hennings Fall aus #295. In der Analyse prüfen, ob das gewollt bleibt.
4. **Änderung der Einstellung auf einem anderen Gerät** muss dort neu planen
   (`didChangeExternallyNotification`), sonst feuert das Gerät noch zur alten Zeit.
5. **Abnahme:** Simulator-Banner nur per `simctl push` (`add` scheitert im iOS-27-Simulator);
   Stufe 3 über TestFlight (Pfade `LooseEnds/Notifications/`, `*.entitlements`).
6. **Umfang:** Planung + Text + Einstellungsbildschirm + Synchronisierung könnten die 250-LoC-Grenze
   reißen → ggf. in zwei Schnitte teilen (Schnitt 1: Planung und Text mit fester 9:00, Schnitt 2:
   Einstellung).
