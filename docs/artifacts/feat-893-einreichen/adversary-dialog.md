# Adversary Dialog — feat-893-einreichen
Spec: docs/specs/feat-893-schnitt-a-pruefen.md
Datum: 2026-11-09 21:53

## Checkliste
- [x] **AC-1:** Given beide Plattformen vollständig bereit, When `pruefen` läuft, Then meldet die Ausgabe je Plattform „bereit“, die Gesamtzeile `zusammenfassung bereit=ios,mac nicht-bereit=keine` und der Ausgang ist 0. Belegt durch `test_ready_on_both_platforms_exit_zero`.
- [x] **AC-2:** Given eine Plattform hat keine, mehrere oder eine bearbeitbare Version mit anderer Nummer als die andere Plattform, When `pruefen` läuft, Then ist sie nicht bereit mit nennendem Grund (Zahl und Zustände bzw. beide Nummern) und der Ausgang ist 1. Belegt durch `test_version_rules`.
- [x] **AC-3:** Given kein Bau, ein Bau nicht im Zustand `VALID`, ein abgelaufener Bau oder eine Vorabversion ungleich der Zielversion, When `pruefen` läuft, Then ist die Plattform nicht bereit mit je eigenem Grund. Belegt durch `test_build_rules`.
- [x] **AC-4:** Given `de-DE` oder `en-US` fehlt, oder `description`, `keywords`, `supportUrl` oder `whatsNew` ist leer oder nur Leerraum, When `pruefen` läuft, Then ist die Plattform nicht bereit mit Locale und Feldname (nie Wortlaut); ein fehlender `promotionalText` allein macht sie nicht unbereit. Belegt durch `test_text_rules`.
- [x] **AC-5:** Given eine Locale ohne Bild (weder Bildsatz mit Bildern noch Bibliotheksplatzierung) oder eine Version ohne Review-Detail, When `pruefen` läuft, Then ist die Plattform nicht bereit mit Grund; Bildsätze allein oder Platzierungen allein genügen. Belegt durch `test_image_and_review_detail_rules`.
- [x] **AC-6:** Given Einreichungen der Plattform in WAITING_FOR_REVIEW, IN_REVIEW, UNRESOLVED_ISSUES, CANCELING, COMPLETING oder einem unbekannten oder fehlenden Zustand, When `pruefen` läuft, Then ist die Plattform nicht bereit („belegt“ mit Zustandswort); COMPLETE und Einreichungen der anderen Plattform werden ignoriert. Belegt durch `test_submission_states`.
- [x] **AC-7:** Given genau eine Einreichung in READY_FOR_REVIEW, When `pruefen` läuft, Then bleibt die Plattform bereit und die Ausgabe nennt sie „wiederverwendbar“; bei mehr als einer ist die Plattform nicht bereit („mehrdeutig“). Belegt durch `test_ready_for_review_is_reusable_but_two_are_not`.
- [x] **AC-8:** Given beide Plattformen haben Gründe, When `pruefen` läuft, Then werden beide vollständig ausgewertet und alle Gründe beider Plattformen stehen im Protokoll; die Gesamtzeile nennt beide als nicht bereit und der Ausgang ist 1. Belegt durch `test_both_platforms_fully_evaluated`.
- [x] **AC-9:** Given jeder Lauf von `pruefen`, When die Anfragen am Nachbau geprüft werden, Then kam nie ein POST, PATCH oder DELETE an, und ein Nachbau, der jede Nicht-GET-Anfrage mit 405 scheitern lässt, ändert das Ergebnis nicht. Belegt durch `test_never_sends_non_get`.
- [x] **AC-10:** Given Lesefehler (403, 500) mit Geheimwert in Apples Rohantwort, Kennungen im Nachbau und Store-Wortlaut, When `pruefen` läuft, Then enthält die Ausgabe weder Kennungen noch Rohantwort noch Wortlaut; der Lesefehler wird zum Grund `nicht lesbar HTTP <status>` der Plattform und die andere Plattform wird weiter ausgewertet. Belegt durch `test_output_has_no_ids_raw_answers_or_wording`.
- [x] **AC-11:** Given keine, eine unbekannte oder die Aktion `einreichen`, When das Skript startet, Then endet es mit Ausgang 1 und `::error::Aufruf: asc_store_submit.py pruefen` ohne Anfrage gegen Apple. Belegt durch `test_bad_usage_makes_no_call`.
- [x] **AC-12:** Given die Workflow-Datei, When sie geprüft wird, Then bietet `aktion` nur `pruefen`, `concurrency` nutzt die eigene Gruppe `asc-store-submit` ohne Abbruch laufender Läufe, die Python-Tests laufen als erster Schritt, der Handlaufschritt hängt an `workflow_dispatch`, und der Schlüssel wird nie ausgegeben. Belegt durch `test_workflow_offers_only_pruefen_and_hides_the_key`.
- [x] **AC-13:** Given die Änderung, When der Diff und die Tests geprüft werden, Then sind `scripts/asc_store_version.py` und `scripts/test_asc_store_version.py` unverändert und dessen Tests (einschließlich „nie einreichen“) grün, die Zeile in `CLAUDE.md` steht nach der Zeile zu `asc-store-version.yml`, und der Diff berührt nur `scripts/`, `.github/workflows/`, `CLAUDE.md` und `docs/`; die Abnahme endet nach Stufe 2 mit dem Satz „Kein Pfad der Geräteliste berührt.“ Belegt durch `test_store_version_script_untouched`, die Dateiliste des Diffs gegen die Geräteliste und die Läufe von `python3 scripts/test_asc_store_submit.py`, `python3 scripts/test_asc_store_version.py` und `python3 scripts/test_asc_version_texts.py`.

## Dialog

### Runde 1
**Adversary:** Tests gelaufen: test_asc_store_submit 13 OK, test_asc_store_version 16 OK, test_asc_version_texts 29 OK (adversary-test-output.txt). Eigene Sonden gegen SubmitFakeASC: (a) Bildsatz-Lesefehler 500 bei Platzierungen=4 -> bereit, bei Platzierungen=0 -> `bilder nicht lesbar HTTP 500` je Locale, kein Status-Leck; (b) Platzierungen 403 bei Bildsätzen>0 -> bereit, bei 0 -> `nicht lesbar HTTP 403`; (c) reviewSubmissions 500 -> beide Plattformen `einreichungen nicht lesbar HTTP 500`, Ausgang 1, Rest weiter ausgewertet; (d) kein POST/PATCH/DELETE im Code (nur get_data/get_one/count). Ausgabe enthält nur Zustandswörter und Zeichenzahlen. Watched.last wird in guarded() und vor der Platzierungsabfrage zurückgesetzt, Durchsickern in andere Teilprüfung nicht herstellbar. Code reference: scripts/asc_store_submit.py:50 (guarded), :119 (Reset), :141 (fail-closed: Zustand fehlt/unbekannt -> belegt).
**Implementierer:** Auffälligkeiten 1-3 sind bewusst; Status kommt nur aus der Wiederholungszeile, wenn die Fatal-Meldung keinen nennt.

### Runde 2
**Adversary:** Nachgefasst. Befund F001 (LOW): Einreichungen werden mit limit=50 ohne Folgeseite gelesen; bei >50 Zeilen könnte eine belegende Einreichung unsichtbar bleiben (Code reference: scripts/asc_store_submit.py:132); real unwahrscheinlich, Apple-Antwort zeigt erst der Handlauf. Befund F002 (LOW): Regel „eine Quelle bebildert, Lesefehler der anderen zählt nicht" (scripts/asc_store_submit.py:126) ist ungetestet (Code reference: scripts/test_asc_store_submit.py:195); meine Sonde (a)/(b) belegt das Verhalten, es ist spezifikationskonform (AC-5: Bildsätze allein oder Platzierungen allein genügen). Zeile ohne `platform` wird der Plattform zugerechnet (streng, fail-closed, :141) - korrekt. Workflow: Aktion nur `pruefen`, eigene concurrency-Gruppe ohne Abbruch, Tests als erster Schritt, Handlauf nur bei workflow_dispatch, Schlüsseldatei per trap entfernt (Code reference: .github/workflows/asc-store-submit.yml:28). CLAUDE.md-Zeile direkt nach asc-store-version.yml (Code reference: CLAUDE.md:113). asc_store_version.py und dessen Test unverändert (git status zeigt sie nicht).
**Implementierer:** F001/F002 akzeptiert als Nachbesserung für Schnitt B bzw. ohne Blockade.

## Bestätigungen
Confirmation: AC-1 .. AC-8
Code reference: scripts/asc_store_submit.py:155
Evidence: Gründe je Plattform gesammelt, Ausgang nur 0 wenn beide bereit; Tests test_* grün.
Status: CONFIRMED
Confirmation: AC-9, AC-10, AC-11
Code reference: scripts/asc_store_submit.py:221
Evidence: nur GET, Ausgabe ohne Kennungen/Rohantwort/Wortlaut, falscher Aufruf Ausgang 1 vor jeder Anfrage.
Status: CONFIRMED
Confirmation: AC-12
Code reference: .github/workflows/asc-store-submit.yml:28
Evidence: nur Option pruefen, eigene Gruppe.
Status: CONFIRMED
Confirmation: AC-13
Code reference: CLAUDE.md:113
Evidence: Zeile an richtiger Stelle, Diff nur scripts/.github/CLAUDE.md/docs.
Status: CONFIRMED
Confirmation: Testdatei
Code reference: scripts/test_asc_store_submit.py:136
Evidence: 13 Tests grün.
Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict
**VERIFIED**

## Geprüfte Dateien

- sha256:237b03b28c9874683cad5bf9ef2f902e4c573d69c67f225de52aba749e32091a  .github/workflows/asc-store-submit.yml
- sha256:74c6f2527b49f95fb333fe26a50db94ae911bc4a59e5d5be44b57aaaff2233a9  CLAUDE.md
- sha256:0830b47281fa8fe0ef5993e96a1f33b21675c02e4a80da21e889ac8e84434798  scripts/asc_store_submit.py
- sha256:9ea4f2c72fb2bc8f2a00d63abbc8baae68cce67dc75146a8516af37aebf4854a  scripts/test_asc_store_submit.py

## Prüfbasis

- base: 01823297969441ca86ffe3d23803db078fe7ae95
- blob:67a1caf20faac2d29bd65ead476eb845fe4a2751  .github/workflows/asc-store-submit.yml
- blob:3c3a1b7f4bef5749bb5596b40f2c9b91ccfca809  CLAUDE.md
- blob:ef0539ee971b5f1a59082639934e51b4bf80fb4e  scripts/asc_store_submit.py
- blob:c2a1dd0567a80ab052ec797d527dbc83f0fb2680  scripts/test_asc_store_submit.py
