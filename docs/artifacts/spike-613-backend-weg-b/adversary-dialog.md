# Adversary Dialog — spike-613-backend-weg-b
Spec: docs/specs/spike-613-schnitt-1-abschrift-auftraege.md
Datum: 2026-10-31 15:03

## Checkliste
- [x] **AC-1:** `TranscriptCodec` bildet `[TaskItem]` plus `now` und `calendar` rein (ohne Netz, ohne Dateizugriff, ohne Seiteneffekt auf den Store) auf einen `Transcript` Version 1 ab: `version`, `generatedAt`, `nowCount`, `now` (Listen von Aufgaben-IDs `knaeuel` (optional), `today`, `lined`, `waiting`) und `tasks` = alle nicht erledigten Aufgaben mit **ausschließlich** den Feldern `id`, `title`, `status`, `dueDate` (ISO 8601), `dueHasTime`, `contexts` (Namen), `project` (Name), `nextRank`, `isKnaeuel`. Rohtext, Notiz, Anhänge und Revisionen kommen nicht vor. Belegt durch `TranscriptCodecTests` (Test über die Feldmenge: das JSON enthält genau diese Schlüssel; erledigte Aufgaben fehlen; ein Rohtext mit auffälligem Wortlaut taucht im JSON nicht auf).
- [x] **AC-2:** `transcript.nowCount == ViewRules.nowCount(...)`, und die IDs in `now` entsprechen `ViewRules.now(...)` für dieselben Aufgaben in genau dessen Reihenfolge, mit festem `now` und festem Kalender. Der Test arbeitet mit gemischtem Bestand: heute fällig, als nächstes (mit Rang), überfällig ohne Rang, Knäuel, erledigt, geparkt. Belegt durch `TranscriptCodecTests`.
- [x] **AC-3:** JSON-Rundlauf: kodieren, dekodieren ergibt Gleiches; Datumsangaben sind ISO 8601; die Schlüssel sind stabil. Der Test vergleicht die Kodierung gegen ein festes JSON-Beispiel (Fixture), das wörtlich auch in `docs/reference/claude-abschrift-vertrag.md` steht. Belegt durch `TranscriptCodecTests`.
- [x] **AC-4:** Auftrag `capture(text)` legt über `CaptureService.save` mit Kanal `.claude` eine Aufgabe an; Ergebnis `done` mit der neuen `taskID`. Leerer oder nur aus Leerraum bestehender Text ergibt `rejected(invalid)`; es wird nichts gespeichert (Anzahl der Aufgaben vorher gleich nachher). Belegt durch `OrderExecutorTests`.
- [x] **AC-5:** Auftrag `complete(taskID, expectedStatus)`: stimmt der Status, ruft der Ausführer `TaskActions.complete` auf und meldet `done`. Eine wiederkehrende Aufgabe rollt weiter statt `done` zu werden und erhält einen `CompletionRecord`, wie beim Abhaken in der App. Belegt durch `OrderExecutorTests` (einmalige und wiederkehrende Aufgabe).
- [x] **AC-6:** Auftrag `setDue(taskID, date|nil, hasTime, expectedDueDate)` schreibt über `RevisionService.set(.dueDate, …)` eine Revision mit Autor `.user` und Grund „Claude“; `dueHasTime` wird wie in der App gesetzt (Tagesdatum = Tagesbeginn, mit Uhrzeit die Uhrzeit). `date = nil` entfernt die Fälligkeit, ebenfalls als Revision. Belegt durch `OrderExecutorTests` (Revision gezählt, Autor und Grund geprüft).
- [x] **AC-7:** Weicht der erwartete Stand (Status bzw. Fälligkeit) vom Store ab, ergibt das `rejected(stale)`; eine unbekannte `taskID` ergibt `rejected(missing)`. Bei **jeder** Ablehnung (auch `invalid`) bleibt der Store unverändert: der Test zählt Revisionen, Aufgaben und die Felder Status, Fälligkeit, `dueHasTime` vorher und nachher. Belegt durch `OrderExecutorTests`.
- [x] **AC-8:** Nachweis ohne Dienst mit zwei getrennten Stores. Store A erzeugt die Abschrift; ein `complete`-Auftrag wird **nur aus der Abschrift** gebildet (ID und Status aus dem JSON, durch JSON hindurchgereicht); Store B mit identisch angelegten Aufgaben (gleiche IDs) führt ihn aus. Danach ist die neue Abschrift von B konsistent: `nowCount` sinkt um 1, wenn die erledigte Aufgabe in „Jetzt“ stand, und sie fehlt in `tasks`. Wird derselbe Auftrag ein zweites Mal ausgeführt, ergibt das `rejected(stale)` (kein doppeltes Abhaken, wiederkehrende Aufgaben rollen nicht ein zweites Mal weiter). Belegt durch `OrderExecutorTests`. *Hinweis, kein AC:* Doppeltes Ausführen eines `capture`-Auftrags verhindert erst der Dienst, indem ein Auftrag an genau ein Gerät geht (Schnitt C3).
- [x] **AC-9:** Konventionen: kein `try?`, `Logger` statt `print`, Swift 6 strict concurrency (`Transcript`, `Order`, `OrderResult` und ihre Teile sind `Sendable`), keine in Watch oder Widget unverfügbare API (`Shared/` kompiliert auch dort). Belegt durch den Bau (`./scripts/sim.sh build`) und den vollen Unit-Lauf; die Dateiliste des PR enthält außer den sechs oben genannten Dateien (plus erzeugtem Projekt) nichts.
- [x] **AC-10:** `docs/reference/claude-abschrift-vertrag.md` beschreibt Abschrift, Auftrag und Ergebnis (Version 1) in Prosa und enthält je ein JSON-Beispiel, das **identisch** mit den Fixtures in `TranscriptCodecTests` und `OrderExecutorTests` ist. Belegt durch die Tests, die das Dokument einlesen und Fixture und Dokumentbeispiel vergleichen (Pfad relativ zum Quelltext, Test überspringt nie stumm: fehlt die Datei, schlägt er fehl).

## Dialog

### Runde 1
**Adversary:** Fix F001 (Fälligkeit immer verglichen): Wo bricht das? (a) AC-8: Store A liefert dueDate aus dem JSON, Store B hat dieselbe Fälligkeit; der Auftrag trägt `expectedDueDate: entry.dueDate`, gleiche ISO-Sekunden, also kein stale. Zweiter Lauf: bei einmaliger Aufgabe ist der Status `done` und `completable` ist nicht erfüllt... der Auftrag trägt `expectedStatus: active`, Store hat `done`, also `status != expected` und stale. Bei wiederkehrender Aufgabe ist die Fälligkeit weitergerollt, also stale. (b) Sekundenbruchteile: `same` vergleicht `ISO8601Format()` beider Seiten (Code reference: Shared/Services/OrderExecutor.swift:111-113), die Abschrift kodiert mit `.iso8601` (Code reference: Shared/Services/TranscriptCodec.swift:74), beide schneiden auf ganze Sekunden. Test `expectedDueFromTranscriptMatches` setzt 0.375 s und läuft grün. (c) Aufgabe ohne Fälligkeit: Abschrift hat dueDate nil, Auftrag expectedDueDate nil, gleich, also ausführbar (Test `completeOneOff`). (d) Order-Fixture: sie wird nur kodiert/dekodiert, nicht ausgeführt, also unberührt. Fix F002: `completable` (Code reference: Shared/Services/OrderExecutor.swift:91) schließt done/removed aus, Test `completeExpectingClosedIsInvalid`. Alle `.unprocessed/.unverified/.active/.parked` bleiben ausführbar, entspricht `tasks` der Abschrift (alles außer done/removed, Code reference: Shared/Services/TranscriptCodec.swift:52).
**Implementierer:** Stimmt; Läufe nach dem letzten Codeänderungszeitpunkt (OrderExecutor 14:03:58, Tests 14:04:08, Vertrag 14:04:17; voller Lauf 15:02, Einzelläufe 15:03): UNIT_EXIT=0, Suites "Orders from Claude" und "Transcript for Claude" passed, 1159 gesamt, 1146 bestanden, 0 fehlgeschlagen, 13 übersprungen (vom Aufrufer genannt, nicht neu gefahren).

### Runde 2
**Adversary:** F004 Rollback: `commit` ruft bei Speicherfehler `context.rollback()` und wirft weiter (Code reference: Shared/Services/OrderExecutor.swift:94-101). Ungetestet, aber ein Fehlerpfad ohne Spec-AC (AC-7 nennt Ablehnungen, keinen Speicherfehler); nicht blockierend. Kein `try?`, kein `print` in beiden Dateien (grep leer), Logger genutzt: AC-9. `CaptureChannel.claude` ist Rohwert-Enum ohne Schemafeld (Code reference: Shared/Models/Enums.swift:19). Rohe Bereiche: setDue mit `date == nil` und `hasTime == true` ergibt `dueHasTime=false` (Zeile 85), sauber; FieldCodec setzt bei nil ebenfalls false. F003: setDue mit demselben Zeitpunkt aber anderem `hasTime` gibt von `RevisionService.set` nil zurück (guard current != encoded), `revision?.reason` ist ein No-op, `dueHasTime` wird aber still gesetzt (Code reference: Shared/Services/OrderExecutor.swift:81-85). AC-6 fordert die Revision für die Fälligkeit; dort ändert sich das Datum nicht, die Revision wäre eine Datumsrevision ohne Datumsänderung. Keine AC verlangt das Gegenteil, das Verhalten ist im Vertrag als Grenze dokumentiert. LOW, kein AC verletzt. Weiter: setDue auf done/removed-Aufgabe ist erlaubt, die Spec schweigt (AC-7 nennt nur Status bei complete); LOW, nicht AC-verletzend. Rundung: negative Datumsangaben (vor 1970) irrelevant.
**Implementierer:** Beide LOW-Punkte bleiben bekannte Grenzen von Version 1.

## Befunde

Finding:
  ID: F003
  Severity: LOW
  Category: edge_case
  Code reference: Shared/Services/OrderExecutor.swift:81
  Description: setDue mit gleichem Zeitpunkt aber gewechseltem hasTime ändert dueHasTime ohne Revision.
  Spec requirement: AC-6 — Revision beim Setzen; die Spec verlangt keine Revision für eine reine hasTime-Änderung.
  Conflict: Kein Verstoß gegen eine AC; nur "Revisions, not undo" im Geist. Dokumentiert als Grenze.
  Remediation: Später force-Revision, wenn sich nur hasTime ändert.

Finding:
  ID: F005
  Severity: LOW
  Category: edge_case
  Code reference: Shared/Services/OrderExecutor.swift:75
  Description: setDue prüft den Status der Aufgabe nicht; eine erledigte oder entfernte Aufgabe bekommt eine Fälligkeit.
  Spec requirement: AC-7 — nennt Status-Abweichung nur für complete; Spec schweigt für setDue.
  Conflict: Kein AC-Verstoß; Claude sieht nur offene Aufgaben in der Abschrift.
  Remediation: Optional expectedStatus auch bei setDue prüfen.

Confirmation:
  AC: AC-1
  Code reference: Shared/Services/TranscriptCodec.swift:21
  Evidence: Entry hat genau die neun Felder, keine Rohtext/Notiz; Filter done/removed in Zeile 52.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: Shared/Services/TranscriptCodec.swift:41
  Evidence: nowCount und IDs direkt aus ViewRules.now, gleiche Reihenfolge.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: Shared/Services/TranscriptCodec.swift:72
  Evidence: iso8601, sortedKeys; Fixture-Vergleich beidseitig, Suite grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: Shared/Services/OrderExecutor.swift:52
  Evidence: CaptureService.save mit .claude; emptyText wird invalid; Tests captureSaves, captureBlankIsInvalid.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: Shared/Services/OrderExecutor.swift:62
  Evidence: TaskActions.complete nach Status- und Fälligkeitsprüfung; Tests completeOneOff, completeRepeating.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: Shared/Services/OrderExecutor.swift:75
  Evidence: RevisionService.set, reason "Claude", Autor .user, Tagesbeginn ohne Uhrzeit, nil entfernt; drei Tests.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: Shared/Services/OrderExecutor.swift:66
  Evidence: alle Prüfungen vor dem ersten Schreiben; Snapshot-Tests für invalid, stale, missing.
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: Shared/Services/OrderExecutor.swift:67
  Evidence: Test twoStoresThroughTheTranscript (einmalig und wiederkehrend): nowCount sinkt, zweiter Lauf stale, keine zweite CompletionRecord. Sekundenbruchteile durch same() abgedeckt.
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: Shared/Models/Enums.swift:19
  Evidence: Sendable-Typen, Logger, kein try?/print; sim.sh build Erfolg, voller Lauf UNIT_EXIT=0, 0 fehlgeschlagen.
  Status: CONFIRMED

Confirmation:
  AC: AC-10
  Code reference: Shared/Services/OrderExecutor.swift:8
  Evidence: documentCarriesFixtures und Transcript-Gegenstück vergleichen Dokument und Fixtures; Suiten grün, Dokument 14:04:17 vor den Läufen.
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: VERIFIED
Tests: 1146 bestanden, 0 fehlgeschlagen, 13 übersprungen (aus xcresult-Angabe des Aufrufers; UNIT_EXIT=0)
Edge cases: F001, F002, F004 behoben; F003, F005 LOW, keine AC verletzt
Checklist: 10/10 proven

## Geprüfte Dateien

- sha256:64b37b113c8c4d459cda032bea30cd9da79983832b69a426401f0522b84af319  Shared/Models/Enums.swift
- sha256:39d15ed826148c8778b480e9643bcbf81606b792074f64df65fe5c3befa60684  Shared/Services/OrderExecutor.swift
- sha256:8e6898f6f9193dbcda9bb13b3b37e6d46a4b8ed6d2af3ef36f43fc2decdc80b8  Shared/Services/TranscriptCodec.swift

## Prüfbasis

- base: 629109852386de5d6873900fc1fce858c8aadd58
- blob:0f44ce479bb1eb9a7c293ae193f9dfb2cd5b1848  Shared/Models/Enums.swift
- blob:9da192f0bcb2928466236c2d5d57d9890f06c53a  Shared/Services/OrderExecutor.swift
- blob:9ee5ccfc0057a00dbaa52b8c71527e5d36aaa4eb  Shared/Services/TranscriptCodec.swift
