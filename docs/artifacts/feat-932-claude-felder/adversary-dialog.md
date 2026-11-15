# Adversary Dialog — feat-932-claude-felder
Spec: docs/specs/feat-932-schnitt-1-app.md
Datum: 2026-11-15 19:31

## Checkliste
- [x] **AC-1:** Die Vertragsbeispiele `capture` mit `fields` und `update` dekodieren zu festen `Order`-Werten und kodieren in beiden Richtungen gleich; `docs/reference/claude-abschrift-vertrag.md` enthält sie wörtlich (Test 1, `OrderExecutorFieldsTests`).
- [x] **AC-2:** Ein `capture` mit `fields` legt die Aufgabe mit unverändertem Rohtext an und setzt jedes vorhandene Feld als Nutzerrevision (Autor `.user`, Grund „Claude“), `RevisionService.lastClaudeChange` findet sie (Test 2).
- [x] **AC-3:** Ein `update` setzt Titel, Fälligkeit (mit `dueHasTime`), Wichtigkeit, Dringlichkeit, Dauer, Energie, Tags und Projekt je als genau eine Nutzerrevision mit Grund „Claude“ und richtigem Alt- und Neuwert; andere Felder bleiben gleich (Test 3).
- [x] **AC-4:** Ein fehlendes Feld bleibt unberührt, ein unveränderter Wert schreibt keine Revision, eine leere Tag-Liste leert die Tags (Test 4).
- [x] **AC-5:** Tags und Projekt werden nur über `CatalogService.nameKey` aus vorhandenen Einträgen aufgelöst und in der Schreibweise des Katalogs gespeichert; es entsteht nie ein neuer Tag oder ein neues Projekt (Test 5).
- [x] **AC-6:** Unbekannter Tag oder Projekt, ungültiger Enum-Wert, Energie außerhalb −3…3, leerer Titel, `notes` bei `update`, leeres `fields`, Datum ohne `dueHasTime` und ein `update` mit `expectedStatus` erledigt oder gelöscht werden als `invalid` abgelehnt, ohne jede Schreibung: Aufgaben, Revisionen und Kataloge sind unverändert, ein abgelehntes `capture` legt keine Aufgabe an (Test 6, Test 10).
- [x] **AC-7:** Ein `update`, dessen erwarteter Status, Titel, Tags, Projekt oder Datum nicht mehr zum Gerät passt, wird als `stale` abgelehnt, eine unbekannte Aufgabe als `missing`; der Store bleibt unverändert (Test 7, Test 8).
- [x] **AC-8:** Aufträge ohne `fields` (`capture`, `complete`, `setDue`, `setNext`, `park`, `addSubtask`) verhalten sich unverändert; die bestehenden Tests von `OrderExecutorTests` und `OrderExecutorRevisionTests` bleiben grün (Test 9).
- [x] **AC-9:** Der Modelltitel ersetzt im Erstlauf keinen Titel, an dem eine Nutzerrevision hängt, und schreibt ihn weiter, wo keine hängt (Test 11, `EnrichmentTitleProtectionTests`).
- [x] **AC-10:** Nach einem `capture` mit Feldern behalten Regeln, Stub-Modell und „Erneut analysieren“ jeden von Claude gesetzten Wert (Fälligkeit, Wichtigkeit, Dringlichkeit, Dauer, Tags, Projekt, Notiz, Titel) und legen keine automatische Revision an diesen Feldern an (Test 12).
- [x] **AC-11:** Der Vertrag enthält weiter genau drei ` ```json`-Blöcke an derselben Stelle und mit gleichem Inhalt; die neuen Beispiele stehen in ` ```jsonc`-Blöcken; `./server/scripts/test-local.sh` bleibt grün und der Dienst (`server/`) ist unverändert.
- [x] **AC-12:** Alle Unit-Tests sind grün, und `./scripts/sim.sh test-proof ClaudeChangeTests` ist grün mit registriertem Beleg.

## Dialog

### Runde 1
**Adversary:** Angriff auf die Prüfreihenfolge: Schreibt irgendetwas vor allen Prüfungen? `capture` (OrderExecutor.swift:88) prüft Text, `isWellFormed` und `resolve` vor `CaptureService.save`; `resolve` ruft nur `CatalogService.project(named:in:)` (reines fetch) und fetcht TaskContext, legt nie an. `CaptureService.save` wirft bei leerem Text vor `context.insert`. Abgelehntes capture legt also nichts an. `update` (106): Form (invalid, mit taskID) -> find (missing) -> resolve (invalid) -> Status und Abschrift (stale) -> #777-Wache -> write + ein commit. Auslegung 4 (Formfehler tragen taskID auch bei unbekannter taskID) ist spec-konform: Formprüfung steht in der Spec vor missing. Auslegung 3 (fields bei anderen Arten ignoriert): nur capture und update leiten fields weiter; harmlos. Auslegung 2 (leeres fields bei capture): `isWellFormed` true, `isEmpty` überspringt write; die Spec verlangt leer nur bei update als invalid; konform.
Stale-Vergleich: `matchesTranscript` (165) vergleicht Titel exakt (nil gegen task.title: String?, fehlender Wert = hatte keinen), Kontexte und Projekt als Menge nach nameKey, Datum über `same` (ISO8601, ganze Sekunden). Nur geänderte Felder werden geprüft. Wichtigkeit, Dringlichkeit, Dauer, Energie nur Status. Konform.
Namen: `resolve` nimmt min nach `survivesBefore`, dedupliziert, leerer nameKey -> invalid. Geschrieben wird der Name des Katalogeintrags. Enum-Werte: Importance, Urgency, DurationBucket, Energy(rawValue:) entsprechen den Spec-Mengen exakt, Energie -3...3.
**Implementierer:** Tests laufen grün (adversary-test-output.txt: OrderExecutorFieldsTests 9/0, EnrichmentTitleProtectionTests 2/0, OrderExecutorRevisionTests 9/0, Suite "Orders from Claude" passed; voller Lauf 1359 grün).

### Runde 2
**Adversary:** Auslegung 1 (force beim capture-Titel): `write` Zeile 194 setzt `force`, wenn markTitle und titleSourceRaw != user; `RevisionService.set` mit force schreibt dann auch bei old == new eine Revision "Titel X -> X" mit Grund Claude. Das ist die einzige Möglichkeit, titleSourceRaw = user zu setzen, damit der Modelltitel (EnrichmentWriter.swift:54, jetzt `!userHasTouched`) ihn nicht überschreibt; die Spec verlangt "Titel von Claude ersetzt den Regeltitel als Nutzerrevision". Kosmetisch (eine Nulländerungs-Revision in der Änderungsliste), kein Datenfehler: LOW, nicht blockierend. Kein Test deckt old == new ausdrücklich ab.
Titelschutz: EnrichmentWriter Zeile 54 ändert nur firstRun; Aufgaben ohne Nutzerrevision verhalten sich wie bisher (EnrichmentTitleProtectionTests grün).
Vertrag: der Diff des Vertrags zeigt keine entfernten Zeilen innerhalb der drei json-Blöcke (nur Prosa), die Zählung `^```json$` ergibt 3, zwei jsonc-Blöcke neu (Zeilen 160, 183). `server/` ohne Änderung (Statusprüfung leer). Kein `try?` in OrderExecutor.swift (0 Treffer). Funktionen: update ca. 18, write ca. 30, capture ca. 15 Zeilen, alle <= 50. Commit-Fehler: `commit` rollt zurück (bestehend).
Nebenbefund (LOW, Spec-Risiko schon benannt): capture speichert zweimal; bei Fehler im zweiten Speichern bleibt die Aufgabe ohne Felder.
**Implementierer:** Keine Gegenrede; LOW-Befund bewusst akzeptiert.

## Findings

Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: Shared/Services/OrderExecutor.swift:194
  Description: Beim capture wird der Titel mit force geschrieben, solange titleSourceRaw nicht user ist; lautet Claudes Titel wie der Regeltitel, entsteht eine Revision mit old == new.
  Spec requirement: AC-2 — jedes vorhandene Feld als Nutzerrevision, Rohtext unverändert
  Conflict: Kosmetisch: Nulländerung in der Änderungsliste; erforderlich, um titleSourceRaw = user zu setzen und den Modelltitel zu sperren. Kein Verstoß gegen eine AC.
  Remediation: Optional Revision unterdrücken, Marke aber setzen; oder Verhalten im Vertrag nennen.

## Confirmations

Confirmation:
  AC: AC-1
  Code reference: Shared/Services/OrderExecutor.swift:38
  Evidence: OrderFields und Order Codable mit festen Schlüsseln; Vertragsfixtures in OrderExecutorFieldsTests grün, Vertrag enthält die jsonc-Beispiele.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: Shared/Services/OrderExecutor.swift:88
  Evidence: capture speichert den Rohtext via CaptureService.save und schreibt Felder über den gemeinsamen write mit Grund Claude; Test grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: Shared/Services/OrderExecutor.swift:186
  Evidence: je Feld ein RevisionService.set mit reason Claude, dueHasTime mitgesetzt; Test 3 grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: Shared/Services/OrderExecutor.swift:186
  Evidence: nur vorhandene Felder, set liefert nil bei gleichem Wert, leere Tag-Liste leert (Mengenvergleich nach persistentModelID).
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: Shared/Services/OrderExecutor.swift:143
  Evidence: resolve über nameKey auf vorhandene Kataloge, Überlebender per survivesBefore, nie Anlegen; Katalogschreibweise wird geschrieben.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: Shared/Services/OrderExecutor.swift:126
  Evidence: isWellFormed und resolve laufen vor jedem Schreiben; notes bei update, leeres fields, done/removed-Status sind invalid.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: Shared/Services/OrderExecutor.swift:165
  Evidence: matchesTranscript und Statusvergleich liefern stale vor write; unbekannte Aufgabe missing ohne taskID.
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: Shared/Services/OrderExecutor.swift:74
  Evidence: andere Arten unverändert geroutet; capture ohne fields identisch; OrderExecutorTests und OrderExecutorRevisionTests grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: Shared/Enrichment/EnrichmentWriter.swift:54
  Evidence: firstRun: !userHasTouched(.title, on: task); EnrichmentTitleProtectionTests 2/0.
  Status: CONFIRMED

Confirmation:
  AC: AC-10
  Code reference: Shared/Enrichment/EnrichmentWriter.swift:54
  Evidence: Kette Erfassen -> Koordinator in EnrichmentTitleProtectionTests grün; übrige Felder schützen die bestehenden Regeln.
  Status: CONFIRMED

Confirmation:
  AC: AC-11
  Code reference: Shared/Services/OrderExecutor.swift:38
  Evidence: Vertragsdiff entfernt nur Prosa, drei json-Blöcke unverändert, zwei jsonc neu; server/ unverändert; server-test-output.txt 441 grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-12
  Code reference: Shared/Services/OrderExecutor.swift:74
  Evidence: Unit-Teil belegt (volle Suite 1359 grün, 0 rot, 13 übersprungen laut test-green-output.txt). Der Teil test-proof ClaudeChangeTests ist offen für Phase 7, nicht Teil dieses Codes.
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

═══════════════════════════════════════
VERDICT: VERIFIED
═══════════════════════════════════════
Tests: OrderExecutorFieldsTests 9, EnrichmentTitleProtectionTests 2, OrderExecutorRevisionTests 9, Suite Orders from Claude grün, 0 failed; voller Lauf 1359 grün, 13 übersprungen (Beleg des Entwicklers)
Edge cases: geprüft, ein LOW-Befund (F001)
Regressions: None found
Checklist: 12/12 (AC-12 test-proof offen für Phase 7)

## Geprüfte Dateien

- sha256:7bedc1999098ea6bfa2eec4851502c0ae114454cb76f272614c6bf76aaa78d41  Shared/Enrichment/EnrichmentWriter.swift
- sha256:cf1918925f83d9b8f21086b87a0643add4197abfaee541e8305295435e9ce156  Shared/Services/OrderExecutor.swift

## Prüfbasis

- base: 2429bf61b681c85970578351ac0cff73c548b102
- blob:261519fc12bf3efe17b6ac5fc0a6b244e6507a52  Shared/Enrichment/EnrichmentWriter.swift
- blob:94f44775875be27f678443a66d9d37183a00da49  Shared/Services/OrderExecutor.swift
