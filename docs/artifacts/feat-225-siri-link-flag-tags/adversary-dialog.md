# Adversary Dialog — feat-225-siri-link-flag-tags
Spec: docs/specs/intents/feat-225-siri-link-flag-tags.md
Datum: 2026-10-06 19:48

## Checkliste
- [x] **AC-1 Ein Link:** Given `urls` enthält nach Entdoppeln genau einen Link / When `resolve` und `apply` laufen / Then trägt `task.sourceURL` diesen Link, und es entsteht keine Revision dafür.
- [x] **AC-2 Mehrere Links werden vor dem Speichern abgelehnt:** Given `urls` enthält mehr als einen verschiedenen Link / When `resolve` läuft / Then wirft es `multipleLinks(count)` mit der Anzahl der verschiedenen Links, vor `CaptureService.save`, und es entsteht keine Aufgabe. Gleiche URLs zählen vorher einmal.
- [x] **AC-3 Keine Links:** Given `urls` ist leer / Then bleibt `sourceURL` leer und nichts wird abgelehnt.
- [x] **AC-4 Markierung:** Given `isFlagged == true` / When `apply` läuft / Then ist `importance == .high`, `importanceSourceRaw == "user"`, `importanceConfidence == nil`, und es entsteht genau eine Revision (`.importance`, Autor `.user`, Grund „Siri“, `oldValue` = vorheriger Rohwert oder `nil`, `newValue == "high"`, `seenAt` gesetzt).
- [x] **AC-5 Nicht markiert:** Given `isFlagged == false` oder `nil` / When `apply` läuft / Then bleibt die Wichtigkeit unverändert und es entsteht keine Revision (#220).
- [x] **AC-6 Tags nur vorhandene Kontexte:** Given jedes Tag trifft nach der Namensregel (getrimmt, Groß/Klein- und Akzent-unabhängig) einen vorhandenen Kontext / When `apply` läuft / Then trägt die Aufgabe genau diese Kontexte, `contextsSourceRaw == "user"`, `contextsConfidence == nil`, und es entsteht genau eine Revision (`.contexts`, Autor `.user`, Grund „Siri“, `newValue` = JSON-Liste der echten Kontextnamen, `seenAt` gesetzt).
- [x] **AC-7 Unbekanntes Tag lehnt alles ab:** Given mindestens ein Tag trifft keinen Kontext / When `resolve` läuft / Then wirft es `unknownTag(name)` mit dem Originalnamen dieses Tags, vor dem Speichern, ohne Teilergebnis: weder Link noch Markierung noch Kontexte werden gesetzt, es entsteht keine Aufgabe.
- [x] **AC-8 Dubletten und Faltung:** Given ein Tag faltet sich auf mehrere Kontexte / Then gilt der Überlebende nach `survivesBefore`. Given zwei Tags falten sich auf denselben Kontext / Then trägt die Aufgabe ihn einmal.
- [x] **AC-9 Leere Tags:** Given `tags` ist leer / Then bleibt `contexts` unverändert, keine Revision.
- [x] **AC-10 Schutz vor Überschreiben:** Given Markierung und Tags sind angewendet / When „Neu analysieren“ (`.reanalysis`) schreibt oder der erste Durchlauf nach dem Erfassen läuft / Then bleiben Wichtigkeit und Kontexte erhalten (belegt durch `siriValuesSurviveReanalysis` und `siriValuesSurviveFirstPass`).
- [x] **AC-11 `resolve` schreibt nichts:** Given beliebige Eingabe / When `resolve` läuft, auch bei Fehler / Then ist der `ModelContext` unverändert (keine eingefügten oder geänderten Objekte).
- [x] **AC-12 `CaptureService.save` unberührt:** Signatur und Rumpf von `CaptureService.save` sind nach dem Ticket unverändert (im Diff prüfbar).
- [x] **AC-13 Eine Namensregel:** `nameKey` ist die einzige Implementierung der Namensfaltung; `SiriFields` enthält keine Kopie davon.

## Dialog

### Runde 1
**Adversary:** Behauptungen und Beweise gesammelt. Testlauf `./scripts/sim.sh unit SiriFieldsTests` (Ausgabe: docs/artifacts/feat-225-siri-link-flag-tags/adversary-test-output.txt): 16 Testfaelle (15 Funktionen, `notFlaggedWritesNothing` parametrisiert) bestanden, 0 fehlgeschlagen, 0 uebersprungen, "Test Succeeded".

Confirmation:
  AC: AC-1
  Code reference: Shared/Services/SiriFields.swift:62
  Evidence: Genau ein Link setzt `task.sourceURL`; kein `record`-Aufruf im Link-Zweig. Test singleLinkBecomesSourceURL prueft `revisions.isEmpty`.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: Shared/Services/SiriFields.swift:36
  Evidence: Entdoppeln per `contains` (Reihenfolge erhalten), Zeile 37 wirft `multipleLinks(links.count)`. `resolve` laeuft vor `CaptureService.save`; Test prueft `multipleLinks(2)` bei [A,B,A], `hasChanges == false`, keine TaskItem.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: Shared/Services/SiriFields.swift:62
  Evidence: `links.first` ist nil, `if let` ueberspringt; Test noLinksSetsNothing.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: Shared/Services/SiriFields.swift:63
  Evidence: importance .high, SourceRaw "user", Confidence nil, genau eine Revision ueber `record` (Zeile 82: author .user, reason "Siri", seenAt = now); oldValue = vorheriger `importanceRaw`. Tests flaggedSetsHighImportanceAsUser und flaggedRevisionKeepsPreviousValue.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: Shared/Services/SiriFields.swift:39
  Evidence: `flagged: fields.isFlagged == true` macht false und nil zu false; Zeile 63 schreibt dann nichts. Parametrisierter Test deckt beide.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: Shared/Services/CatalogService.swift:81
  Evidence: `nameKey` (trim, case- und diakritikunabhaengig) wird in Shared/Services/SiriFields.swift:48-49 benutzt; Kontextnamen der echten Kontexte in Revision (Shared/Services/SiriFields.swift:76). Test tagsMatchIgnoringCaseAndAccents ("garten ", "BURO" -> Garten, Buero) und tagsAreWrittenAsUserWithRevision.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: Shared/Services/SiriFields.swift:51
  Evidence: `unknownTag(tag)` mit Originalstring, in `resolve` vor allem Schreiben; Ergebnis nur ueber Rueckgabe, kein Teilergebnis. Test unknownTagIsRejectedWithItsName (hasChanges false, keine TaskItem).
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: Shared/Services/CatalogService.swift:70
  Evidence: `survivesBefore` jetzt intern (Diff: nur private entfernt, Rumpf unveraendert); Shared/Services/SiriFields.swift:50 nimmt `.first` der damit sortierten Treffer; Shared/Services/SiriFields.swift:53 entdoppelt per id. Tests duplicateContextsPickTheSurvivor (isSystemDefault schlaegt sortOrder) und tagsFoldingToTheSameContextGiveOne.
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: Shared/Services/SiriFields.swift:44
  Evidence: `guard !tags.isEmpty` liefert []; Shared/Services/SiriFields.swift:70 `if !resolved.contexts.isEmpty` schreibt weder Kontexte noch Revision. Test emptyTagsSetNothing.
  Status: CONFIRMED

Confirmation:
  AC: AC-10
  Code reference: Shared/Services/SiriFields.swift:82
  Evidence: Schutz haengt an Revision mit author .user (`EnrichmentWriter.userHasTouched`, EnrichmentWriter.swift:122-124, genutzt in mayWrite :113); Test siriValuesSurviveReanalysis. Mutationsgedanke: mit author .ai waere userHasTouched false und der Reanalysis-Test rot. Erster Durchlauf: siriValuesSurviveFirstPass mit Stub-Enricher (.low) und frueherem Eintrag mit anderem Kontext, bestanden.
  Status: CONFIRMED

Confirmation:
  AC: AC-11
  Code reference: Shared/Services/SiriFields.swift:34
  Evidence: `resolve` enthaelt nur `fetch` und lokale Variablen, kein insert/Mutation. Tests pruefen `hasChanges == false` und leere TaskItem-Liste nach Fehler (multipleLinks, unknownTag). Schwaeche: Erfolgsfall ohne hasChanges-Pruefung, aber der Code hat keinen Schreibpfad.
  Status: CONFIRMED

Confirmation:
  AC: AC-12
  Code reference: Shared/Services/CatalogService.swift:70
  Evidence: Diff-Statistik gegen origin/main fuer Shared/Services/CaptureService.swift ist leer. CatalogService-Diff: genau zwei Zeilen, nur `private` entfernt (survivesBefore :70, nameKey :81).
  Status: CONFIRMED

Confirmation:
  AC: AC-13
  Code reference: Shared/Services/SiriFields.swift:48
  Evidence: SiriFields ruft `CatalogService.nameKey` und `CatalogService.survivesBefore`; keine eigene `folding`/`trimmingCharacters`-Logik in der Datei (alle 87 Zeilen gelesen).
  Status: CONFIRMED

**Implementierer:** (nicht anwesend, Adversary allein)

### Runde 2
**Adversary:** Nachbohren mit Wegwerf-Probetest (LooseEndsTests/ZProbeTests.swift, danach geloescht, Arbeitsbaum sauber). Ergebnisse:
- Tag nur aus Leerzeichen ("  ") und leerer String: `unknownTag` mit dem Originalstring (nameKey "" trifft keinen Kontext). Deterministisch, kein Absturz.
- URLs "https://a.com/x" und "https://a.com/x/": zaehlen als zwei verschiedene Links, `multipleLinks(2)`. Entspricht "gleiche URL" im Wortlaut der Spec.
- apply auf Aufgabe mit bereits vorhandenem Kontext (Buero): Kontexte werden durch Siri-Tag ersetzt, Revision oldValue = kodierte alte Namen. Entspricht der Spec.
- Reihenfolge bei mehreren unbekannten Tags: `tags.sorted()` (Shared/Services/SiriFields.swift:47), also stets der alphabetisch erste unbekannte Name; Set-Reihenfolge spielt keine Rolle.
- Swift 6: `SiriFields` ist `Sendable` (URL, Bool?, Set<String>). `Resolved` haelt @Model-Objekte und ist bewusst nicht Sendable; Aufruf laeuft laut Spec synchron auf dem MainActor; Build und Tests gruen.
- Mutationsgedanke fuer AC-10 siehe Runde 1; die Tests sind an der Revision mit .user verankert (nicht per Mutation ausgefuehrt, nur aus dem Code abgeleitet).

Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: Shared/Services/SiriFields.swift:47
  Description: Leeres oder nur aus Leerraum bestehendes Tag fuehrt zu `unknownTag("  ")`; der Fehlertext zeigt dann leere Anfuehrungszeichen. Kein Test dafuer.
  Spec requirement: AC-7 — unbekanntes Tag wird mit Originalnamen abgelehnt
  Conflict: Kein Konflikt; Verhalten spec-konform, nur unschoen fuer den Nutzer.
  Remediation: Optional in #25 leere Tags vor dem Aufruf ausfiltern oder einen Test ergaenzen.

Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: Shared/Services/SiriFields.swift:36
  Description: Entdoppeln vergleicht `URL` exakt; Varianten wie Schraegstrich am Ende zaehlen als verschiedene Links und loesen `multipleLinks` aus.
  Spec requirement: AC-2 — gleiche URLs zaehlen einmal
  Conflict: Kein Verstoss (Spec sagt "gleiche URL"); moegliche Ablehnung an sich gleicher Ziele.
  Remediation: Hinnehmen oder in #25 bewusst entscheiden; kein Test belegt das Verhalten.

**Implementierer:** (nicht anwesend)

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: VERIFIED
Tests: 16 Testfaelle bestanden, 0 fehlgeschlagen, 0 uebersprungen
Edge cases: geprueft, 2 LOW-Hinweise (F001, F002), nichts gebrochen
Regressions: keine gefunden (CatalogService nur Sichtbarkeit; CaptureService unveraendert)
Checklist: 13/13 points proven

## Geprüfte Dateien

- sha256:74dbd2bba95bb124dbf56bc82883379586878862efd07dbdde9a5d791835f6ac  Shared/Services/CatalogService.swift
- sha256:223181cfbd4de98489ec8d4834031a785356e7de48776ec0937b41da301ed95c  Shared/Services/SiriFields.swift

## Prüfbasis

- base: aa00942d60f31ab5f153c58e963529a1686ff4b1
- blob:2f94a527a650b625a6534cdc582e189977692a26  Shared/Services/CatalogService.swift
- blob:709fa6b55ea0b86de8977736693a6c6c180a2f7d  Shared/Services/SiriFields.swift
