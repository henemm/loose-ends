---
entity_id: feat-176-testflight-abnahme
type: feature
created: 2026-10-25
updated: 2026-10-25
status: draft
workflow: 176-testflight-abnahme
---

# Spec: #176 Abnahme vor der Einladung: feste Prüfliste für die TestFlight-Fassung

## Approval

- [ ] Approved

## Purpose

Vor der ersten Einladung externer Tester soll belegt sein, dass die TestFlight-Fassung als Nutzer funktioniert
(Hennings Regel vom 2026-09-27: benutzen, nicht nur bauen). Ein komplettes Neu-Durchspielen auf seinen Geräten hat Henning
verworfen (2026-10-25). Stattdessen entsteht eine **feste Prüfliste** (reine Doku): Jeder Schritt der Alltagsfunktionen steht
mit Bedienweg, Quelle in der User Story und Status darin. Was Henning in einem schon bestätigten Build gesehen hat, ist
„belegt“ (Ticket und Buildnummer). Nur die **Lücken** spielt Henning durch, gebündelt in EINEM Prüfblock, und erst nach seinem
wörtlichen „jetzt ist ein Test möglich“. Die Liste bleibt als Vorlage für jede weitere Einladungswelle.

Zuschnitt (Henning, 2026-10-25): Die Testgruppe in App Store Connect bleibt in **#342 Teil 3** und fällt aus #176. Der
Meilenstein „TestFlight 0.1 — Build, der Hennings Alltag trägt“ ist bereits geschlossen (geprüft mit `gh api`, Zustand
`closed`). Damit ist die offene Frage der Analyse beantwortet und der dritte Haken des Tickets entfällt; der zweite
Haken (Gruppe) wandert nach #342. Für #176 bleibt der erste Haken: „Alle Schritte mit Beleg, Abweichungen als eigene Tickets“.

Ohne Modell geht es nicht: nicht relevant, reine Dokumentation und ein Listenprüfer, kein Modellweg im Spiel (Regeln vor Modell gilt trivial).

## Source

- **File:** `docs/reference/abnahme-testflight.md` (neu)
- **Identifier:** Tabelle „Prüfliste“ (eine Zeile je Schritt); Vorbild für Aufbau und Quellen: `docs/project/01-user-story.md`
  (Erfolgskriterien, Funktional), `docs/reference/funktionsuebersicht.md`, Ticketschritte aus #176.

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| #175, #183 | Vorarbeit | CloudKit Production und TestFlight-Lauf sind erledigt; die Entscheidung vom 2026-10-03 („#176 startet erst danach“) ist erfüllt |
| #342 Teil 3 | Ticket | Übernimmt die Testgruppe in App Store Connect; `testflight.md` verweist ausdrücklich dorthin |
| #371 | Epic | Einladung externer Tester; die Liste ist deren Voraussetzung |
| #607, #584, #601, #605 | Tickets (gemergt, offen) | Rückmeldungen aus TestFlight ohne Bestätigung; werden die Lückenschritte |
| `docs/reference/abnahme-und-arbeitsweise.md` | Doku | Regel „`Refs #N` statt `Closes #N`, wenn eine Rückmeldung verlangt wird“ (#544) |
| `scripts/test_tags_wording.py` u. a. `scripts/test_*.py` | Muster | Skripttests mit `unittest`, nur Standardbibliothek, Aufruf `python3 scripts/test_….py` |

## Scope

### Affected Files
| File | Change Type | Description |
|------|-------------|-------------|
| scripts/test_abnahme_liste.py | CREATE | Prüft die Liste maschinell (TDD RED: scheitert, solange die Liste fehlt) |
| docs/reference/abnahme-testflight.md | CREATE | Prüfliste: Schritt, Bedienweg, Quelle/Kriterium, Status, Beleg-Verweis, Buildnummer |
| docs/artifacts/176-abnahme/ | CREATE | Belege (Bildschirmfotos/Protokolle) aus Hennings Prüfblock; entsteht mit dem ersten Beleg |
| docs/reference/testflight.md | MODIFY | Verweis auf die Liste; Gruppe `Familie` ausdrücklich unter #342 Teil 3 |
| docs/reference/abnahme-und-arbeitsweise.md | MODIFY | Liste als Schritt vor jeder Einladung nennen |

### Estimated Changes
- Files: 5 (davon 1 Verzeichnis), nur Doku und ein Skripttest, kein Produktcode
- LoC: +175/-0 (ca. 85 `test_abnahme_liste.py`, ca. 70 Liste, ca. 12 `testflight.md`, ca. 8 `abnahme-und-arbeitsweise.md`); Belege zählen nicht

## Implementation Details

### 1. Aufbau der Liste (`docs/reference/abnahme-testflight.md`)

Kopf: Zweck in drei Sätzen, Geltungsbereich („gilt für die Builds der Spalte `Build`; ältere Belege werden bei Zweifel als Lücke geführt“), die Geräteregel
(unten), Statusbedeutung. Danach EINE Markdown-Tabelle „Prüfliste“ mit genau diesen Spalten, in dieser Reihenfolge:

`Nr | Schritt | Bedienweg | Quelle | Status | Beleg | Build`

- **Nr:** `S01`, `S02` … fortlaufend, eindeutig.
- **Quelle:** Kriterium aus `01-user-story.md` oder Zeile aus `funktionsuebersicht.md` (Kurztext), damit jeder Haken auf die Story zurückführt.
- **Status** (genau einer): `belegt`, `Lücke`, `wartet auf Hennings Wort`.
  - `belegt`: Henning hat den Schritt in einem Build bestätigt. Spalte **Beleg** nennt das Ticket (`#534`), Spalte **Build** die Buildnummer.
  - `Lücke`: kein bestätigter Beleg für den aktuellen Stand. Beleg und Build stehen auf `–`.
  - `wartet auf Hennings Wort`: Gerätepunkt der Lücke, der im Prüfblock liegt und erst nach seinem wörtlichen
    „jetzt ist ein Test möglich“ läuft. Beleg und Build `–`, bis seine Rückmeldung da ist; danach wird die Zeile `belegt` mit Ticket/Build.
- **Beleg-Dateien:** Ein Bildschirmfoto oder Protokoll steht als Pfad in Backticks in der Spalte Beleg (`docs/artifacts/176-abnahme/<datei>`), neben dem Ticket.

**Schritte** (Ticket #176 plus die im Ticket fehlenden iPad, Mac, Ortserinnerung): Erfassung per Text; Erfassung per Sprache (iPhone); Veredelung
(Titel, Datum aus Regel, Kontexte und Dauer bei Wiedererkennung, Dauer-Regel); Ansichten und Startseite; Erledigt (mit Rücknahme) und Parken; Mitteilung
„Heute fällig“; Kalender-Schalter; Watch-Diktat und Komplikation; Widget; Control Center; Teilen-Menü; iPad (Seitenleiste, Startseite); Mac aus TestFlight
(macOS wählen: Fenster, Listentasten, Mikrofonrecht); Ortserinnerung (Ankommen); sowie die Lückenschritte **S-Lücke #607** (Modelltitel hängt keinen
Satz einer erledigten Aufgabe an), **#584** (Icon-Zahl = Zahl über „Jetzt“, Build 96), **#601** (Schreibzeile auf Startseite, Return legt an, Build 101),
**#605** (Löschen mit Unteraufgaben).

**Belegt-Kandidaten, geprüft gegen Tickets und Memory** (nur diese Zuordnungen sind vorgesehen; jede wird bei der Umsetzung mit `gh issue view` gegen den
Ticketverlauf bestätigt, ohne bestätigten Beleg wird die Zeile `Lücke`; Buildnummern werden nie erfunden):

| Schritt | Ticket | Build | Quelle der Bestätigung |
|---------|--------|-------|------------------------|
| Modellaufruf und Veredelung mit Zeitgrenze | #534 | 107 | Henning „passt“, 2026-10-23 |
| Sprache: nur Mikrofonrecht | #293 | 112 | Henning bestätigt, 2026-10-24 |
| Dauer-Regel | #673 | 115 | Henning bestätigt, 2026-10-25 |
| Ortserinnerung (Ankommen, Erledigt) | #240 | 61 | Henning „alles wie erwartet“, 2026-10-15 |
| Watch-Rücksprung nach Diktat | #409 | 64 | Henning „Funktioniert“, 2026-10-15 |
| Watch-Komplikation | #355 (S3a) | 57 | Henning „grundsätzlich funktioniert es“, 2026-10-14 |
| Mac: Fenstergröße, Listentasten | #480 | 106 | Henning, 2026-10-23 |
| Teilen und Mitteilungen (Schnittstellen) | #580 | 114 | Henning „passt“, 2026-10-25 |

Die vier Lückenschritte (#607, #584, #601, #605) sind `Lücke`/`wartet auf Hennings Wort`, weil alle gemergt, aber unbestätigt sind (Stand Ticketliste: offen).

### 2. Der eine Prüfblock

Alle Lückenschritte und alle `wartet auf Hennings Wort`-Zeilen werden zu **einem** Prüfblock gebündelt: ein deutscher TestFlight-„Was testen“-Text
(Schritt, Bedienweg, was er sehen muss; Bedienwege aus den Tests übernehmen, Memory zu #480). Der Block steht als Abschnitt am Ende der Liste. Auslösung:
Ich frage per AskUserQuestion, was läuft und wie lange; erst nach Hennings wörtlichem „jetzt ist ein Test möglich“ wird ein Build mit diesem Text gestartet
und er benachrichtigt. Vorher ist alles gebaut und startklar (Regel „Bereit, bevor ich Henning rufe“).

### 3. Geräteregel (zwingend)

Kein Schritt dieser Spec und kein Schritt der Liste startet, installiert, misst oder liest etwas auf Hennings Geräten (iPhone, iPad, Watch, Mac als Zielgerät),
auch nichts Lesendes. Gerätepunkte stehen als „wartet auf Hennings Wort ‚jetzt ist ein Test möglich‘“. Die Umsetzung nutzt nur Dateien, `gh` und
Skripttests auf dem Rechner. Eine Ankündigung ist keine Frage; eine frühere Freigabe gilt nicht weiter.

### 4. Belege

Belege werden nie von Hand gesetzt: Ein Status wechselt nur auf `belegt`, wenn Ticket und Build aus einer echten Rückmeldung oder einem echten Lauf stammen.
Von Henning gelieferte Bildschirmfotos öffne und beschreibe ich (ein Satz je Bild in der Zeile oder daneben), bevor ein Haken fällt. Abweichungen, die der
Prüfblock zeigt, werden je eigenes GitHub-Ticket (nicht Teil von #176).

### 5. Der Listenprüfer (`scripts/test_abnahme_liste.py`)

`unittest`, nur Standardbibliothek, Aufruf `python3 scripts/test_abnahme_liste.py`. Liest `docs/reference/abnahme-testflight.md`, parst die Tabelle
„Prüfliste“ (Kopfzeile muss genau die sieben Spalten haben) und prüft je Zeile. Fehlt die Datei oder die Tabelle, schlagen alle Tests mit klarer
Meldung fehl (RED vor der Umsetzung). Die Prüfung läuft gegen Zeilen als Funktion `check_rows(rows, root)`, damit Negativfälle mit künstlichen
Zeilen getestet werden können, ohne die echte Liste zu verfälschen.

### 6. Änderungen an den bestehenden Dokumenten

- `docs/reference/testflight.md`, Abschnitt 6: ein Absatz „Prüfliste vor der Einladung“ mit Verweis auf `abnahme-testflight.md`, dazu der Satz, dass die
  Gruppe (`Familie`, interne Tests) und die externen Gruppen **unter #342 Teil 3** angelegt werden, nicht unter #176.
- `docs/reference/abnahme-und-arbeitsweise.md`: im Abschnitt „Abnahme in drei Stufen“ unter Stufe 3 ein Absatz: Vor jeder Einladungswelle wird
  `abnahme-testflight.md` auf den Build bezogen durchgegangen; Lücken kommen in einen Prüfblock; `Refs #176` statt `Closes #176`.

### Alternativen, nicht gewählt

- **Komplett neu durchspielen** (alle Schritte frisch auf dem Gerät): gründlicher, kostet aber eine volle Gerätesitzung für Dinge, die Henning in Builds 57
  bis 115 schon bestätigt hat. Von Henning verworfen (2026-10-25). Der Preis: „belegt durch Ticket“ ist schwächer als ein frischer Beleg; Gegenmittel sind die
  Buildnummer je Zeile und die Regel, dass ältere Belege bei Zweifel als `Lücke` geführt werden.
- **Gruppe per App-Store-Connect-Skript hier mitbauen:** `POST /v1/betaGroups` mit `isInternalGroup` ist möglich (Apple, App Store Connect API, Beta Groups), die
  Build-Zuordnung per Relationship-Endpoint ist nicht belegt gefunden, und lokal gibt es keinen ASC-Zugriff. Doppelung mit #342 Teil 3, darum dort.
- **Wiederkehrender Release-Schritt statt Einmalabnahme:** Die Liste ist so gebaut, dass sie dazu taugt (Buildnummer je Zeile, Prüfblock je Welle). Eine
  feste Einbindung in den Release-Ablauf (z. B. CI-Hinweis vor `v*`-Tags) ist eine Folgeidee und wird unter #342 vermerkt, nicht hier gebaut.

Keine ADR wird gekippt.

## Test Plan

### Automated Tests (TDD RED)

Alle in `scripts/test_abnahme_liste.py`. Zuerst geschrieben; ohne `docs/reference/abnahme-testflight.md` schlagen sie fehl.

- [ ] `test_list_exists_and_has_seven_columns`: GIVEN die Datei WHEN die Tabelle „Prüfliste“ geparst wird THEN Kopf = `Nr, Schritt, Bedienweg, Quelle, Status, Beleg, Build`, mindestens 12 Zeilen.
- [ ] `test_numbers_are_unique`: GIVEN alle Zeilen THEN die Nr-Werte sind eindeutig und passen auf `^S\d{2}$`.
- [ ] `test_status_is_allowed`: GIVEN jede Zeile THEN Status ∈ {`belegt`, `Lücke`, `wartet auf Hennings Wort`}.
- [ ] `test_belegt_names_ticket_and_build`: GIVEN jede Zeile mit `belegt` THEN Beleg enthält `#<Zahl>` und Build ist eine ganze Zahl > 0.
- [ ] `test_gap_and_waiting_have_no_proof`: GIVEN jede Zeile mit `Lücke` oder `wartet auf Hennings Wort` THEN Beleg = `–` und Build = `–` (kein Beleg-Haken ohne Rückmeldung).
- [ ] `test_proof_files_exist`: GIVEN jeder in Backticks stehende Pfad unter `docs/artifacts/176-abnahme/` in der Spalte Beleg THEN die Datei existiert im Repo.
- [ ] `test_required_gap_steps_present`: GIVEN die Liste THEN #607, #584, #601 und #605 kommen je in einer Zeile vor, und keine davon ist `belegt`.
- [ ] `test_required_coverage`: GIVEN die Liste THEN iPad, Mac und Ortserinnerung kommen je in mindestens einer Zeile vor (Schritt oder Bedienweg).
- [ ] `test_every_row_has_source`: GIVEN jede Zeile THEN die Spalten Schritt, Bedienweg und Quelle sind nicht leer.
- [ ] `test_pruefblock_lists_all_gaps`: GIVEN der Abschnitt „Prüfblock“ THEN er kommt genau einmal vor und nennt die Nr jeder Zeile mit `Lücke` oder `wartet auf Hennings Wort`.
- [ ] `test_checker_rejects_bad_rows`: GIVEN künstliche Zeilen (Status „fertig“; `belegt` ohne Build; `Lücke` mit Build 5; Beleg-Pfad, der nicht existiert) WHEN `check_rows` THEN je eine Fehlermeldung, die Nr und Grund nennt.

### Manuelle Tests

Keine. Der Prüfblock auf Hennings Geräten ist kein Test dieser Spec, sondern die Abnahme der Lücken; er läuft erst nach seinem wörtlichen Wort.

## Acceptance Criteria

- **AC-1:** `docs/reference/abnahme-testflight.md` existiert mit genau einer Tabelle „Prüfliste“ der sieben Spalten `Nr, Schritt, Bedienweg, Quelle, Status, Beleg, Build` und mindestens 12 Zeilen. Belegt durch `python3 scripts/test_abnahme_liste.py` (`test_list_exists_and_has_seven_columns`).
- **AC-2:** Jede Zeile hat einen Status aus {`belegt`, `Lücke`, `wartet auf Hennings Wort`}, eine eindeutige Nr `S01`… und nicht leere Spalten Schritt, Bedienweg, Quelle. Belegt durch `test_numbers_are_unique`, `test_status_is_allowed`, `test_every_row_has_source`.
- **AC-3:** Jede Zeile mit Status `belegt` nennt ein Ticket (`#<Zahl>`) und eine Buildnummer > 0; jede Zeile mit `Lücke` oder `wartet auf Hennings Wort` hat `–` in Beleg und Build. Belegt durch `test_belegt_names_ticket_and_build`, `test_gap_and_waiting_have_no_proof`.
- **AC-4:** Jede Buildnummer einer `belegt`-Zeile stammt aus der Tabelle „Belegt-Kandidaten“ dieser Spec (107, 112, 115, 61, 64, 57, 106, 114) und ist am Ticketverlauf per `gh issue view` bestätigt; ohne bestätigten Beleg steht die Zeile auf `Lücke`. Belegt durch Diff-Durchsicht im Abschlussbericht (je Zeile Ticket, Build, Fundstelle).
- **AC-5:** Die vier Rückmeldungen #607, #584, #601, #605 stehen je in einer Zeile mit Status `Lücke` oder `wartet auf Hennings Wort`; iPad, Mac (TestFlight macOS) und Ortserinnerung sind je mit mindestens einer Zeile vertreten. Belegt durch `test_required_gap_steps_present`, `test_required_coverage`.
- **AC-6:** Alle Lückenschritte stehen gebündelt in genau einem Abschnitt „Prüfblock“ der Liste, mit deutschem „Was testen“-Text (Schritt, bei dem er tippt, was er sehen muss). Belegt durch `test_pruefblock_lists_all_gaps`.
- **AC-7:** Jeder in Backticks genannte Beleg-Pfad unter `docs/artifacts/176-abnahme/` zeigt auf eine vorhandene Datei, und der Listenprüfer weist künstliche fehlerhafte Zeilen (falscher Status, `belegt` ohne Build, `Lücke` mit Build, fehlender Pfad) mit Nr und Grund zurück. Belegt durch `test_proof_files_exist`, `test_checker_rejects_bad_rows`.
- **AC-8:** `docs/reference/testflight.md` verweist auf `docs/reference/abnahme-testflight.md` und nennt die Testgruppe ausdrücklich unter „#342 Teil 3“. Belegt durch Diff (`grep -n "abnahme-testflight" docs/reference/testflight.md` und `grep -n "#342" docs/reference/testflight.md` je mindestens ein Treffer).
- **AC-9:** `docs/reference/abnahme-und-arbeitsweise.md` nennt die Liste als Schritt vor jeder Einladung und die Regel `Refs #176` statt `Closes #176`. Belegt durch Diff (`grep -n "abnahme-testflight"` mindestens ein Treffer und `grep -n "Refs #176"` ein Treffer).
- **AC-10:** Die Liste enthält die Geräteregel (kein Schritt startet etwas auf Hennings Geräten; Gerätepunkte „wartet auf Hennings Wort ‚jetzt ist ein Test möglich‘“), und während der Umsetzung läuft kein `devicectl`, kein `sim.sh device*`, `launch-measure` oder `lab` und kein TestFlight-Lauf. Belegt durch Diff (Abschnitt vorhanden) und Abschlussbericht (Befehlsliste ohne Gerätebefehle).
- **AC-11:** Der Diff berührt höchstens 5 Dateien (die fünf des Scope), keine Datei außerhalb von `docs/` und `scripts/test_abnahme_liste.py`, kein Pfad der Geräteliste, und liegt bei höchstens ±250 LoC (ohne Belege). Belegt durch `git diff --stat` im Abschlussbericht, mit dem Satz „Kein Pfad der Geräteliste berührt.“
- **AC-12:** Der PR trägt `Refs #176`, nicht `Closes #176`; das Ticket bleibt offen bis zu Hennings Rückmeldung zum Prüfblock, danach folgt der Beleg-Eintrag (Ticket/Build) und der Abschlusskommentar mit der Notiz, dass der zweite Haken nach #342 Teil 3 wanderte und der dritte (Meilenstein) schon erledigt war. Belegt durch PR-Text und Ticketverlauf.

Kein Pfad der Geräteliste berührt.

## Definition of Done

- [ ] `scripts/test_abnahme_liste.py` war vor der Liste rot (Datei fehlt) und ist mit der Liste grün (11 Tests).
- [ ] Alle vorhandenen Skripttests (`python3 scripts/test_*.py`) bleiben grün.
- [ ] Jede `belegt`-Zeile ist mit Ticket und Build am Ticketverlauf bestätigt, nichts davon von Hand erfunden.
- [ ] Der Prüfblock liegt fertig und startklar, wird aber nicht ausgelöst; Henning bekommt eine Frage per AskUserQuestion, was läuft und wie lange.
- [ ] Nach seinem „jetzt ist ein Test möglich“ und seiner Rückmeldung: Zeilen auf `belegt` mit Ticket/Build, Bildschirmfotos von mir geöffnet und beschrieben, Abweichungen als eigene Tickets, #176 geschlossen.
- [ ] Der Diff berührt nur die fünf Dateien des Scopes.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — reine Prüfliste und Skripttest, kippt keine ADR und ändert keine Architektur des Produkts.

## Changelog

- 2026-10-25: Initial spec created
