# Adversary Dialog — bug-203-kalender-termin
Spec: docs/specs/fix-203-kalender-quelle.md
Datum: 2026-10-06 19:18

## Checkliste

- [x] AC-1: `CalendarSync.sourceOrder` liefert iCloud → lokal → Standardkonto → übrige CalDAV, je einmal, nie Exchange/abonniert/Geburtstage
- [x] AC-2: Brücke versucht das Anlegen der Reihe nach, loggt jede Ablehnung mit Kontotitel, merkt die Kennung beim ersten Erfolg
- [x] AC-3: Alle Konten lehnen ab → Hinweis „Couldn't create the Loose Ends calendar…“; anderer Fehler → „The calendar couldn't be updated.“; verschwindet nach erfolgreichem Abgleich
- [x] AC-4: Schalter an + Fälligkeit + Kalender bekannt → Zeile „Calendar · ● Loose Ends“ in Kalenderfarbe, nur Anzeige
- [x] AC-5: Bestehende Hinweise bleiben; Brücke stumm unter Unit-Tests und UI-Tests ohne `--ui-testing-calendar`
- [x] AC-6: Deutsche Texte im String-Katalog

## Dialog

### Runde 1
**Adversary:** Ich will sehen, dass die reine Reihenfolge stimmt (inkl. Randfälle: kein Standardkonto, Standard = lokal, Standard = iCloud, Standard = Exchange, mehrere iCloud-Titel, mobileMe), dass die Tests grün sind, und dass der Fehlerzustand sauber gesetzt und gelöscht wird.
**Implementierer:** `./scripts/sim.sh unit CalendarSyncTests` (eigener Lauf, `docs/artifacts/bug-203-kalender-termin/adversary-test-output.txt`): 9/9 grün, darunter alle fünf #203-Fälle (Google-Standard + iCloud → iCloud zuerst; nur lokal; nur Exchange/abonniert → leer; Standard = iCloud nur einmal; lokal vor fremdem CalDAV-Standard) und `note(for:problem:)`. Der Lauf hat das macOS-Ziel inkl. `CalendarBridge.swift` übersetzt, damit ist `EKCalendar.cgColor` auf macOS belegt.
Code reference: Shared/Services/CalendarSync.swift:84 — `sourceOrder` filtert auf `.calDAV`/`.local`, setzt iCloud + lokal + Standard + übrige CalDAV zusammen und entdoppelt über `seen.insert`. defaultSourceID nil → `fallback` leer; Standard = Exchange → schon von `usable` ausgefiltert; mehrere „iCloud“-Konten → alle, je einmal.
Code reference: Shared/Services/CalendarSync.swift:101 — `note(for:problem:)`: Schalter aus → nil, keine Fälligkeit → `.needsDueDate`, sonst Abbildung des Problems.
Code reference: LooseEnds/Calendar/CalendarBridge.swift:173 — `.calDAV, .mobileMe` → `.calDAV`, `.local`, `.exchange`, `.subscribed`, `.birthdays`, `@unknown default` → `.other` (wird nie versucht).
Code reference: LooseEnds/Calendar/CalendarBridge.swift:103 — `problem = nil` erst nach `store.commit()` und `context.save()`; Zeile 106 setzt im catch `.noWritableSource` bzw. `.syncFailed`. Zeile 132: `clearAccessProblem` löscht bei erteiltem Zugriff nur `.accessDenied`, ein Abgleichfehler bleibt bis zum nächsten Erfolg.
Code reference: LooseEnds/Calendar/CalendarBridge.swift:33 — `suppressed`: Unit-Tests immer stumm, UI-Tests stumm außer mit `--ui-testing-calendar`.
Befund Runde 1: Reihenfolge und Zustand stimmen. Offen: Hinterlässt ein abgelehntes `saveCalendar(commit: true)` Reste im `EKEventStore`, die das nächste Konto oder das spätere `store.commit()` der Termine brechen? Der behauptete Wegwerf-Lauf des Implementierers ist entfernt und nicht nachprüfbar.

### Runde 2
**Adversary:** Ich stelle die Ablehnung mit einem echten EventKit-Fehler selbst nach, nicht mit einem vorgetäuschten `throw`, und prüfe danach Kalender, Termin und Fußnote.
**Implementierer (vom Adversary selbst nachgestellt, Wegwerf-Patch, danach aus Sicherung zurückgespielt):** In `createCalendar()` wurde vor die echte Reihenfolge die lokale Quelle eines **zweiten** `EKEventStore` gesetzt; Titel und Merk-Schlüssel waren eindeutig, damit wirklich neu angelegt wird. `./scripts/sim.sh test CalendarTargetTests` im Simulator (iPhone 17, iOS 27): Kalendertitel `PROBE f1 x17 ok:Default`, also wurde der erste Versuch mit **EKError Code 17 (`sourceDoesNotAllowCalendarAddDelete`, genau der Google-Code)** abgelehnt, danach nahm das lokale Konto „Default“ an. Fußnote danach: `syncFailedNote=false noSourceNote=false`. Simulator-Kalenderdatenbank: `Zahnarzt | PROBE f1 x17 ok:Default | 2026-10-07 12:00 UTC` (= 14 Uhr) — der Termin wurde nach der Ablehnung angelegt und committet. Ein abgelehntes `saveCalendar` lässt also nichts zurück, was den Abgleich bricht.
Code reference: LooseEnds/Calendar/CalendarBridge.swift:151 — `createCalendar()`: neues `EKCalendar` je Versuch, Ablehnung wird mit `source.title` geloggt (Zeile 167), bei Erfolg Kennung gemerkt (Zeile 164), sonst `CalendarError.noWritableSource` (Zeile 170).
Danach unveränderter Code zurück, `./scripts/sim.sh test CalendarTargetTests` erneut grün (1/1, `docs/artifacts/bug-203-kalender-termin/adversary-ui-test-output.txt`).
AC-3-Hinweis: `nachher-alle-konten-lehnen-ab.png` angesehen — Schalter an, darunter „Couldn't create the Loose Ends calendar in any of your accounts.“, keine Zielzeile (target nil, richtig).
Code reference: LooseEnds/Views/TaskDetailView.swift:117 — Zeile „Calendar · ● Titel“ nur bei Schalter an, Fälligkeit und bekanntem `target`, ohne Chevron/Aktion, Punkt in `Color(cgColor: target.color)`. Zeile 302: `calendarNote` zeigt die vier Texte über `CalendarSync.note`.
AC-4: Die Zeile erscheint, sobald der Kalender bekannt ist, auch wenn der Termin dieser Aufgabe noch nicht angelegt ist (target ist global; der Startabgleich in `ContentView` setzt es bei erteiltem Zugriff). Das entspricht der Spec („Kalender bekannt“).
AC-6: `Localizable.xcstrings` enthält „Kalender“, „Der Kalender „Loose Ends“ ließ sich in keinem deiner Konten anlegen.“, „Der Kalender ließ sich nicht aktualisieren.“; die bestehenden Hinweistexte sind unverändert.
Weitere Prüfungen: kein `try?` in den drei Dateien; `sync()` hat 49 Zeilen (≤ 50); `@MainActor`-Klasse, `Target` wird nur auf dem MainActor gelesen, Übersetzung unter Swift 6 ohne Fehler.
Befund Runde 2: Kein Spec-Verstoß. Drei Randbefunde (unten), keiner bricht ein AC.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: VERIFIED

Tests: 9 Unit bestanden, 0 fehlgeschlagen, 0 übersprungen (CalendarSyncTests); UI CalendarTargetTests 1 bestanden. Checkliste 6/6.

Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: LooseEnds/Calendar/CalendarBridge.swift:69
  Description: `target` wird nur bei Erfolg gesetzt und im catch (Zeile 106) nie gelöscht. Wird der bekannte Kalender extern gelöscht und scheitert das Neuanlegen, stehen die alte Zeile „Calendar · ● Loose Ends“ und der Hinweis „Couldn't create…“ gleichzeitig da.
  Evidence: LooseEnds/Calendar/CalendarBridge.swift:69, :106
  Remediation: Im catch bei `.noWritableSource` `target = nil` setzen.

Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: LooseEnds/Calendar/CalendarBridge.swift:67
  Description: Steht `.noWritableSource`/`.syncFailed` und entzieht der Nutzer danach den Zugriff, endet ein Abgleich ohne Änderungen am guard, ohne `ensureAccess()`; die Fußnote nennt dann den alten Grund statt „Calendar access is off in Settings.“, bis eine Änderung den Abgleich auslöst.
  Evidence: LooseEnds/Calendar/CalendarBridge.swift:65-67
  Remediation: Bei `!alreadyAuthorized` und vorhandenem Problem `problem = .accessDenied` setzen, oder vertretbar so lassen.

Finding:
  ID: F003
  Severity: MEDIUM
  Category: anti_pattern
  Code reference: Shared/Services/CalendarSync.swift:84
  Description: Umfang: Produktcode +136/−31 (167), Tests +131, zusammen 298 Zeilen gegenüber den in der Spec geschätzten ~210 inkl. Tests und der ±250-Grenze. Nur Produktcode allein liegt mit 167 darunter. Funktional ohne Folgen, aber eine Prozessfrage, die der Orchestrator entscheiden muss.
  Evidence: git diff --numstat; git show --numstat HEAD
  Remediation: Zählweise (Tests ja/nein) im Abschlussbericht offenlegen.

Confirmation:
  AC: AC-1
  Code reference: Shared/Services/CalendarSync.swift:84
  Evidence: Reihenfolge iCloud, lokal, Standard, übrige CalDAV, entdoppelt; 5 Unit-Fälle grün
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: LooseEnds/Calendar/CalendarBridge.swift:151
  Evidence: Echte Ablehnung (Code 17) im Simulator, nächstes Konto nahm an, Termin angelegt, keine Fußnote
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: LooseEnds/Calendar/CalendarBridge.swift:106
  Evidence: Problem gesetzt/gelöscht (Zeilen 103/106); Screenshot nachher-alle-konten-lehnen-ab.png zeigt den Hinweis
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: LooseEnds/Views/TaskDetailView.swift:117
  Evidence: Zeile nur Anzeige mit Kalenderfarbe; CalendarTargetTests grün
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: LooseEnds/Calendar/CalendarBridge.swift:33
  Evidence: Stumm unter Unit-Tests und UI-Tests ohne Startargument; bestehende Hinweise in TaskDetailView.swift:302
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: LooseEnds/Views/TaskDetailView.swift:302
  Evidence: Drei neue deutsche Einträge in Localizable.xcstrings
  Status: CONFIRMED

## Geprüfte Dateien

- sha256:8346665d1d333de6b4dcd000da73c7f595ea1726aaaf8443e532c60067d9f3a0  LooseEnds/Calendar/CalendarBridge.swift
- sha256:56fe6d44becc4c29043cf6a18f5052e1e6a7396805ba9ba26b65f5dd42d44717  LooseEnds/Views/TaskDetailView.swift
- sha256:1100f7b6f2daf035598c04fb8374a70847bc1fedbb31d0eb4b632ce7aca94e6e  Shared/Services/CalendarSync.swift

## Prüfbasis

- base: e37bae778b2e7baed7664bce65db8d431e85066a
- blob:c487ac77a6ad2806b501e68c824d0b02cfc0385f  LooseEnds/Calendar/CalendarBridge.swift
- blob:a41aefe3e3c014e753399a26f0fc2873dee10c54  LooseEnds/Views/TaskDetailView.swift
- blob:fd521aeb3aa969e32e8db7c43e28d0a8d62c6bca  Shared/Services/CalendarSync.swift
