# Adversary Dialog — feat-1000-s3b-toenung
Spec: docs/specs/feat-1000-schnitt-3b-toenung-und-katalog.md
Datum: 2026-11-27 08:44

## Checkliste
- [x] **AC-1:** Eine Aufgabe, deren Merkmal (Etikett, Dauer, Datum am Rand) eine Regel gesetzt hat und die noch nicht geöffnet wurde, zeigt dieses Merkmal in Grau wie jedes andere; Akzent erscheint in der Zeile nur am Knopf „Neues Datum“, Rot nur bei Zeitdruck. Beleg: Code-Pfad `TaskRow` ohne `.tint` außer im Knopf, Screenshot.
- [x] **AC-2:** Keine Zeile trägt mehr den Funken „Changed by AI“ (`aiMarker_<id>`). Beleg: Code-Pfad, Suche ohne Treffer.
- [x] **AC-3:** Die neun Katalogschlüssel fehlen im Katalog und im gebauten Bündel; alle übrigen Schlüssel und der Katalogwächter bleiben grün. Beleg: `CatalogWithoutNewTests` grün, `test_catalog_languages.py` grün.
- [x] **AC-4:** `Paper.wideNoteInsets` existiert nicht mehr; Build grün. Beleg: Suche ohne Treffer, Build.
- [x] **AC-5:** Design-Briefing (Screen 3/4), Funktionsübersicht und CLAUDE.md beschreiben die Zeile ohne KI-Tönung und die Ansichten ohne „Neu“. Beleg: Diff der Doku.

## Dialog

### Runde 1
**Adversary:** Beweis je AC einfordern; ich glaube nichts, was nicht im Code oder Lauf steht.

Confirmation:
  AC: AC-1
  Code reference: LooseEnds/Views/TaskRow.swift:74
  Evidence: Rand-Stil ist nur noch `mark.pressing ? .red : .secondary`; Merkmale (Zeile 185) `.foregroundStyle(.secondary)`, `Trait` ohne `tinted`/`style` (Zeile ~208). Einziges `.tint` der Datei ist Zeile 98, im Knopf "New date" (newDateButton). Rot bleibt bei Zeitdruck (pressing). Screenshot nachher: "Phone" grau, "Today" rot; vorher Petrol.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: LooseEnds/Views/TaskRow.swift:148
  Evidence: Der Funke-Block fehlt, Titel-Text endet bei `.lineLimit(2)`. grep `aiMarker|wideNoteInsets|Changed by AI` in allen *.swift ohne Treffer ausser dem Test CatalogWithoutNewTests (Liste der entfernten Schluessel). Italic fuer Rohtext/.unverified unveraendert.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: Shared/Models/ViewRules.swift:334
  Evidence: Diff von Localizable.xcstrings entfernt genau die neun Eintraege (9 Zeilen). Suche nach allen neun Woertern in LooseEnds, Shared, Watch, Widgets, Share, WatchWidgets, UITests (Literal, Interpolation, LocalizedStringKey): keine Verwendung; nur Kommentare (EnrichmentCoordinator:75, SubtaskListsTests) und der Test. `scripts/test_catalog_languages.py` selbst gelaufen: 9 Tests OK. Voller Unit-Lauf (test-green-output.txt): Test Succeeded, 0 Fehler. ViewRules-Aenderung nur Kommentar.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: LooseEnds/Views/Paper.swift:10
  Evidence: wideNoteInsets samt Kommentar entfernt, kein Treffer in Swift-Quellen; Build im Unit-/Simulatorlauf gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: Shared/Models/TaskItem.swift:182
  Evidence: Kommentar ohne Liste/"New". Doku-Diff: Design-Briefing (KI-Marker durchgestrichen, Neu/Passt entfernt), Funktionsuebersicht (Ansichten ohne Neu), CLAUDE.md (Farbbudget ohne AI tint; S3b-Vermerk). `hasUnseenAutomaticRevisions` bleibt unveraendert (laut Spec).
  Status: CONFIRMED

**Implementierer:** (nicht beteiligt, Isolation)

### Runde 2
**Adversary:** Nachbohren (Early-Agreement-Skepsis):
- Wird ein noch gerufener Schluessel geloescht? Suche in allen Targets inkl. UITests und .strings: keine Nutzung. "New" als Wort steht nur in Kommentaren; "New date" und "Now" bleiben (Test keptKeysStay).
- Bleibt Knopf "Neues Datum" Akzent? Ja, TaskRow.swift:98 `.tint` unveraendert, Spur grau.
- Bleibt Rot? `mark.pressing ? .red` (TaskRow.swift:74); Bild zeigt "Today" rot.
- Tote Referenzen: `unseen`/`unseenAI` komplett entfernt (grep 'unseen' in TaskRow ohne Treffer); `FieldSource.isAutomatic` weiter von anderen genutzt, kein Compilerfehler (Lauf gruen).
- Rangfolge/Anzahl Merkmale: `prefix(3)` unveraendert.
- Rest-Beobachtung (LOW, nicht Spec-Verstoss): Parametrisierte Testfaelle (keyIsGone, 9 Argumente) erscheinen nicht als Einzelzeilen im Log; der Gesamtlauf ist aber 0 rot, und die Schluessel sind per Datei-Diff/grep belegt.
- Mac/iPad-Zeilen: gleicher TaskRow-Code; Mac-Gallery-Fotos nur CI, nicht lokal pruefbar.
Keine Findings.

**Implementierer:** (nicht beteiligt)

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

═══════════════════════════════════════
VERDICT: VERIFIED
═══════════════════════════════════════
Tests: voller Unit-Lauf Test Succeeded, 0 failed, 13 uebersprungen (Messstrecken/Sprache, einzeln im Log benannt); Katalogwaechter 9/9 OK
Edge cases: All checked, none broken
Regressions: None found
Checklist: 5/5 points proven

## Geprüfte Dateien

- sha256:a140bde091390df0d4cbd1aef5f3d962cff36a4d4934993cf95f531deccfa1b6  LooseEnds/Views/Paper.swift
- sha256:700cd8d9e5fbab48ec74681a2590687b43e33efa9369c8d922f3d30efa2fda00  LooseEnds/Views/TaskRow.swift
- sha256:81f72c4aa7cc2ff68501788ea1b96cb1857d35f65ef08263fc32d81468bd4e14  Shared/Models/TaskItem.swift
- sha256:08ca0400fb91d93b8a8b0b362eab71a52c76422ca669999c4a340ce58819c973  Shared/Models/ViewRules.swift

## Prüfbasis

- base: 2324460753146d5acc6713838f31ec4a126d15c3
- blob:4e763978bfb8828f455a9c97716488590778e9e2  LooseEnds/Views/Paper.swift
- blob:164d7544fdc26ef21eb0f671a53298f72ee96b50  LooseEnds/Views/TaskRow.swift
- blob:028883c17398572655fb26056fce3b52be4326b5  Shared/Models/TaskItem.swift
- blob:11b03fa131592b0244593facb5b8352367d37db2  Shared/Models/ViewRules.swift
