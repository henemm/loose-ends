# Adversary Dialog — 176-testflight-abnahme
Spec: docs/specs/feat-176-testflight-abnahme.md
Datum: 2026-10-26 06:25

## Checkliste
- [x] **AC-1:** `docs/reference/abnahme-testflight.md` existiert mit genau einer Tabelle „Prüfliste“ der sieben Spalten `Nr, Schritt, Bedienweg, Quelle, Status, Beleg, Build` und mindestens 12 Zeilen. Belegt durch `python3 scripts/test_abnahme_liste.py` (`test_list_exists_and_has_seven_columns`).
- [x] **AC-2:** Jede Zeile hat einen Status aus {`belegt`, `Lücke`, `wartet auf Hennings Wort`}, eine eindeutige Nr `S01`… und nicht leere Spalten Schritt, Bedienweg, Quelle. Belegt durch `test_numbers_are_unique`, `test_status_is_allowed`, `test_every_row_has_source`.
- [x] **AC-3:** Jede Zeile mit Status `belegt` nennt ein Ticket (`#<Zahl>`) und eine Buildnummer > 0; jede Zeile mit `Lücke` oder `wartet auf Hennings Wort` hat `–` in Beleg und Build. Belegt durch `test_belegt_names_ticket_and_build`, `test_gap_and_waiting_have_no_proof`.
- [x] **AC-4:** Jede Buildnummer einer `belegt`-Zeile stammt aus der Tabelle „Belegt-Kandidaten“ dieser Spec (107, 112, 115, 61, 64, 57, 106, 114) und ist am Ticketverlauf per `gh issue view` bestätigt; ohne bestätigten Beleg steht die Zeile auf `Lücke`. Belegt durch Diff-Durchsicht im Abschlussbericht (je Zeile Ticket, Build, Fundstelle).
- [x] **AC-5:** Die vier Rückmeldungen #607, #584, #601, #605 stehen je in einer Zeile mit Status `Lücke` oder `wartet auf Hennings Wort`; iPad, Mac (TestFlight macOS) und Ortserinnerung sind je mit mindestens einer Zeile vertreten. Belegt durch `test_required_gap_steps_present`, `test_required_coverage`.
- [x] **AC-6:** Alle Lückenschritte stehen gebündelt in genau einem Abschnitt „Prüfblock“ der Liste, mit deutschem „Was testen“-Text (Schritt, bei dem er tippt, was er sehen muss). Belegt durch `test_pruefblock_lists_all_gaps`.
- [x] **AC-7:** Jeder in Backticks genannte Beleg-Pfad unter `docs/artifacts/176-abnahme/` zeigt auf eine vorhandene Datei, und der Listenprüfer weist künstliche fehlerhafte Zeilen (falscher Status, `belegt` ohne Build, `Lücke` mit Build, fehlender Pfad) mit Nr und Grund zurück. Belegt durch `test_proof_files_exist`, `test_checker_rejects_bad_rows`.
- [x] **AC-8:** `docs/reference/testflight.md` verweist auf `docs/reference/abnahme-testflight.md` und nennt die Testgruppe ausdrücklich unter „#342 Teil 3“. Belegt durch Diff (`grep -n "abnahme-testflight" docs/reference/testflight.md` und `grep -n "#342" docs/reference/testflight.md` je mindestens ein Treffer).
- [x] **AC-9:** `docs/reference/abnahme-und-arbeitsweise.md` nennt die Liste als Schritt vor jeder Einladung und die Regel `Refs #176` statt `Closes #176`. Belegt durch Diff (`grep -n "abnahme-testflight"` mindestens ein Treffer und `grep -n "Refs #176"` ein Treffer).
- [x] **AC-10:** Die Liste enthält die Geräteregel (kein Schritt startet etwas auf Hennings Geräten; Gerätepunkte „wartet auf Hennings Wort ‚jetzt ist ein Test möglich‘“), und während der Umsetzung läuft kein `devicectl`, kein `sim.sh device*`, `launch-measure` oder `lab` und kein TestFlight-Lauf. Belegt durch Diff (Abschnitt vorhanden) und Abschlussbericht (Befehlsliste ohne Gerätebefehle).
- [x] **AC-11:** Der Diff berührt höchstens 5 Dateien (die fünf des Scope), keine Datei außerhalb von `docs/` und `scripts/test_abnahme_liste.py`, kein Pfad der Geräteliste, und liegt bei höchstens ±250 LoC (ohne Belege). Belegt durch `git diff --stat` im Abschlussbericht, mit dem Satz „Kein Pfad der Geräteliste berührt.“
- [x] **AC-12:** Der PR trägt `Refs #176`, nicht `Closes #176`; das Ticket bleibt offen bis zu Hennings Rückmeldung zum Prüfblock, danach folgt der Beleg-Eintrag (Ticket/Build) und der Abschlusskommentar mit der Notiz, dass der zweite Haken nach #342 Teil 3 wanderte und der dritte (Meilenstein) schon erledigt war. Belegt durch PR-Text und Ticketverlauf.

## Dialog

### Runde 1
**Adversary:** Mutationstests auf Kopien der Liste: belegt ohne Build, Build 0, Lücke mit Beleg, Prüfblock ohne S13/S21, doppelte Nr, fehlender Beleg-Pfad, falscher Status, 6 Spalten wurden gefangen. Nicht gefangen: Prüfblock-Nr per Substring (S01/S22 durch Einleitungssatz). Nachfragen: S16 belegt mehr als bestätigt (nur Fenstergröße), S02/S12/S18 Belege nur indirekt, S08 „Tipp öffnet die Aufgabe“ nicht bestätigt.
**Implementierer:**
Code reference: docs/reference/abnahme-testflight.md:1
 S16 auf Fenstergröße gekürzt, S23 Listentasten als Lücke mit Bullet im Prüfblock, S02/S12 Beleg-Spalte präzisiert, S08 bereinigt.
Code reference: scripts/test_abnahme_liste.py:1
 Prüfblock-Nr nur aus Bullets (`> - Sxx:`). Negativtest S01/S22 rot.

### Runde 2
**Adversary:** Bullet S01 bzw. S23 entfernt: je FAILED (failures=1); unverändert 11 Tests OK. Belege erneut gegen #480, #355, #240, PR #666, PR #447 geprüft: S16 und S23 jetzt ehrlich, S18 und S12 tragfähig, S02 die dünnste Zeile (Buildnummer 112 laut Koordinator, Verhalten von Henning bestätigt), nach Spec zulässig. AC-8/9 per grep, AC-10 Geräteregel im Listenkopf, AC-11 nur docs/ und scripts/test_abnahme_liste.py. AC-12 erst mit dem PR prüfbar, nicht blockierend.
**Implementierer:**
Code reference: docs/reference/testflight.md:148
 Gruppen unter #342 Teil 3
Code reference: docs/reference/abnahme-und-arbeitsweise.md:62
 Liste vor jeder Einladungswelle, :64 `Refs #176`. Keine Geräte-, sim.sh- oder TestFlight-Befehle benutzt.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: VERIFIED

## Geprüfte Dateien

- sha256:353390ca47e824d3f444050481b223f8bb218203cdb8959d83604000de86945d  docs/reference/abnahme-testflight.md
- sha256:7ee109f6499e13bf81829cf07dcdb7060b5e7321f6a2e23dec85635f8a678327  docs/reference/abnahme-und-arbeitsweise.md
- sha256:e1688a13f29d06d5b4dc6ed98364ed446e8174c416a985ccf45d4a52df81f1b7  docs/reference/testflight.md
- sha256:519980c61601431161a2fe2f912e99ac7763ddd8b11f02e9d1290faa4be49bb7  scripts/test_abnahme_liste.py

## Prüfbasis

- base: eb61b1b24504a220d08480ef3a09c706fd164e79
- blob:7a463e97f74be50fc9560052882f3cc98f98c69c  docs/reference/abnahme-testflight.md
- blob:97b992586f538dfbad5a813b87560a3d17b78b54  docs/reference/abnahme-und-arbeitsweise.md
- blob:afcc7259c6d2c12ce7025d1b99c0bad2e848916a  docs/reference/testflight.md
- blob:9b62fcf053e094af3cacbedfa7b1e1b77fb4b1f8  scripts/test_abnahme_liste.py
