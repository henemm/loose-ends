# Adversary Dialog — feat-788-review-notes
Spec: docs/specs/feat-788-schnitt-1-review-notizen.md
Datum: 2026-11-01 11:24

## Checkliste
- [x] **AC-1:** Given der Nachbau mit Version 1.0 iOS, gesetzten Notizen und Anhängen, When `asc_review_notes.py lesen` läuft, Then erscheinen `appStoreState`, Notizen gesetzt/leer samt Bytezahl und je Anhang Dateiname, Größe und `assetDeliveryState`, und es gibt null Schreibaufrufe. Belegt durch `test_lesen_reports_states_and_never_writes`, `test_lesen_without_attachments_and_with_empty_notes`.
- [x] **AC-2:** Given ein Text von genau 4000 Byte, When `notizen` läuft, Then wird er gesetzt; Given 4001 Byte (auch durch Umlaute, die je 2 Byte zählen), Then Abbruch mit Ist- und Sollwert vor jedem Schreibaufruf. Belegt durch `test_limit_4000_bytes_passes`, `test_4001_bytes_aborts_before_any_write`, `test_umlauts_count_two_bytes`.
- [x] **AC-3:** Given der Text im Nachbau ist schon gleich dem Wunschtext, When `notizen` läuft, Then Ausgabe `unverändert` und null Schreibaufrufe. Belegt durch `test_same_text_is_unchanged_no_patch`.
- [x] **AC-4:** Given der Text weicht ab, When `notizen` läuft, Then genau ein PATCH mit `attributes.notes` gleich dem Wunschtext, danach `gegenprobe gleich=ja`; ein zweiter Lauf meldet `unverändert`. Belegt durch `test_different_text_exactly_one_patch_then_verified`.
- [x] **AC-5:** Given `app-review-notizen.md`, When der Text gelesen wird, Then ist es der Inhalt des ersten Codeblocks, und ein Text mit Platzhalter `<HIER_` bricht vor jedem Schreibaufruf ab. Belegt durch `test_extracts_first_code_block`, `test_placeholder_aborts`.
- [x] **AC-6:** Given beliebige Aktion und beliebiger Ausgang (Erfolg, Abbruch, Fehler), When das Protokoll gelesen wird, Then enthält es weder den Notes-Text noch Kontaktdaten. Belegt durch `test_output_never_contains_notes_text_or_contacts`.
- [x] **AC-7:** Given keine Version 1.0 iOS, kein Review-Detail oder ein vom Zustand verweigertes PATCH, When `notizen` oder `lesen` läuft, Then jeweils Exit ≠ 0 mit eigener, erklärender Meldung und ohne anderen Schreibaufruf (insbesondere kein POST zum Anlegen des Details). Belegt durch `test_missing_version_has_clear_error`, `test_missing_review_detail_has_clear_error_and_no_post`, `test_patch_refused_has_own_message`.
- [x] **AC-8:** Given `.github/workflows/asc-review-notes.yml`, When geprüft, Then ist es ein `workflow_dispatch` mit Eingabe `aktion` (`lesen`, `notizen`), nutzt `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_PRIVATE_KEY`, löscht die Schlüsseldatei per `trap` und führt die Unit-Tests vor dem Aufruf aus. Belegt durch `test_workflow_has_choice_unit_tests_and_secrets`.
- [x] **AC-9:** Given der Merge auf `main`, When der Handlauf `lesen` startet, Then zeigt das Lauf-Protokoll den echten Zustand von Version 1.0 (`appStoreState`, Notizen vorher, Anhänge); When danach `notizen` und erneut `lesen` laufen, Then zeigt das Protokoll `notizen gesetzt` mit `gegenprobe gleich=ja` und im zweiten `lesen` `notizen gesetzt bytes=<N>` mit derselben Zahl wie die Datei, ein weiteres `notizen` meldet `unverändert`. Belegt durch die Lauf-Links, die in `docs/reference/testflight.md` eingetragen werden (Abnahme ohne Gerät, siehe unten).
- [x] **AC-10:** Given `docs/reference/app-review-notizen.md`, When geprüft, Then steht dort kein `<HIER_VIDEO_LINK>` mehr, Punkt 1 spricht von der Aufnahme „attached to this submission“, der Textblock hat höchstens 4000 Byte, und der Kopf nennt den neuen Stand. `testflight.md` enthält den Handlauf (Aufruf, Aktionen, Beleg-Lauf-Links). Belegt durch Diff und den Byte-Test in AC-2.

## Dialog

### Runde 1
**Adversary:** Ich nehme an, die Umsetzung ist kaputt, und prüfe zuerst die Tests selbst. Laufen die 16 neuen Tests grün? Brechen die vier bestehenden asc-Testdateien? Prüft das Skript die Bytegrenze vor jedem Netzaufruf, oder nur die Zeichenzahl? Gibt es einen POST? Werden 403 und 409 wiederholt? Wird bei mehreren Versionen mit Zahl abgebrochen? Landen HTTP-Fehlerkörper oder Notes-Text im Log?
**Implementierer:** Beweis aus eigenem Lauf. `python3 scripts/test_asc_review_notes.py`: 16 Tests, OK (docs/artifacts/feat-788-review-notes/adversary-test-output.txt). Bestehende Tests einzeln: test_asc_beta_setup 18 OK, test_asc_what_to_test 11 OK, test_asc_wait_build 21 OK, test_asc_beta_probe 14 OK, keine Regression.
Code reference: scripts/asc_review_notes.py:48 misst `len(text.encode("utf-8"))` in Byte, Abbruch mit Ist- und Sollwert (Zeile 50) und Platzhalter (Zeile 51-52); `wanted_notes()` läuft in `main` (Zeile 136) vor `read_config()` und damit vor jedem Netzaufruf. Es gibt keinen POST im Skript, einzige Schreibstelle ist `send_json(..., "PATCH", ...)` in Zeile 120, nur nach Ungleichheit (Zeile 115). 403/409 werden in Zeile 122-123 in die eigene Meldung übersetzt, `send_json` (scripts/asc_what_to_test.py:40) wiederholt nur 5xx/408/429. Mehrere Versionen: scripts/asc_review_notes.py:62-63 bricht mit Zahl ab. Fehlendes `appStoreState`: Zeile 64 liefert `?`. Ausgabezeilen wörtlich: Zeile 65, 94, 99, 105-108, 116, 125, 128, 144 stimmen mit der Spec überein. Fehlerkörper werden nie gelesen (scripts/asc_wait_build.py:76 meldet nur Code und Pfad), Notes-Text erscheint nur als Bytezahl.
Code reference: scripts/test_asc_review_notes.py:246 (409-Fall) und :278 (403 und 409, genau ein Versuch).

### Runde 2
**Adversary:** Jetzt Randfälle und Sicherheit: Codeblock mit Sprachangabe, CRLF, nur ein Zaun, leerer Block; Apple normalisiert eventuell den Zeilenumbruch am Ende; Workflow-Injektion; Schlüsseldatei; Rechte; Scope; Dokumentstand.
**Implementierer:** Wegwerf-Probe per `python3 -c` (keine Dateien angelegt): CRLF mit zwei Blöcken ergibt nur den ersten Block ('A\nB', Leerzeilen entfernt). Eine Datei mit nur einem Zaun, mit ```` ```text ```` als einzigem Zaun, und ein leerer Block führen zu `Fatal` (sicherer Abbruch, nichts geschrieben).
Code reference: scripts/asc_review_notes.py:28 erkennt nur einen blanken Zaun (`line.rstrip() == "```"`), spec-wörtlich; Sprachangabe wird nicht erkannt, siehe F002.
Code reference: .github/workflows/asc-review-notes.yml:27 reicht die Eingabe per env (`AKTION`) durch, :37 nutzt `"$AKTION"`, keine `inputs`-Interpolation im Shell-Text; :34 `trap ... EXIT` löscht die Schlüsseldatei, :35 `umask 077`; :16-17 `permissions: contents: read`; :30-31 Unit-Tests vor :32-37 Aufruf; Eingabe `aktion` als `choice` (:8-14) mit Standard `lesen`; :22 timeout 10 Minuten. Die Schlüsselzeile folgt dem Muster von asc-store-probe.yml (Zeile 22-24).
Code reference: scripts/test_asc_review_notes.py:246 enthält Fehlerfälle; die Datei liegt bereits im RED-Commit fe9eac6.
AC-10 gemessen: Der erste Codeblock von docs/reference/app-review-notizen.md hat 2514 Byte (Grenze 4000), kein `<HIER_`, Punkt 1 lautet „Screen recording of a physical iPhone 16 Pro, attached to this submission.“, der Kopf nennt Stand 2026-11-01, Setzen per Handlauf `notizen` und Schnitt 2 für die Aufnahme. docs/reference/testflight.md hat den Abschnitt „App Review: Notizen für Version 1.0 (#788)“ mit Aufruf, beiden Aktionen und Beleg-Tabelle (alle `offen`, Links leer, erst nach Merge).
Code reference: docs/reference/app-review-notizen.md:1 und docs/reference/testflight.md:239.
Scope: git status zeigt nur die fünf genannten Dateien (plus Artefakte und `.claude/`), kein App-Code, kein project.yml.
AC-9: vor dem Merge nicht belegbar, bleibt offen. Das ist der einzige offene Punkt.

Findings (beide ohne Blockade):
- F001 LOW edge_case, scripts/asc_review_notes.py:115 vergleicht strikt `==`. Normalisiert Apple einen Zeilenumbruch am Ende, meldet der erste Lauf nach dem PATCH die Gegenprobe als Abbruch (Zeile 126-127) und jeder Folgelauf PATCHt erneut. Entspricht der Spec („Gleich“), kann erst im echten Lauf (AC-9) auftreten. Abhilfe: falls AC-9 es zeigt, nur am Ende `rstrip("\n")` auf beiden Seiten vergleichen.
- F002 LOW edge_case, scripts/asc_review_notes.py:28 erkennt keinen Zaun mit Sprachangabe. Folge ist ein sicherer Abbruch („keinen Codeblock“), kein Schaden; die Datei nutzt einen blanken Zaun. Spec-konform.

### Runde 3
**Adversary:** AC-9 war vor dem Merge offen. Ist es jetzt mit echten Läufen gegen App Store Connect belegt, oder nur behauptet? Stimmt die Bytezahl bei Apple mit der Datei überein, und schreibt ein zweiter `notizen`-Lauf wirklich nichts?
**Implementierer:** Nach dem Merge von PR #790 (d37d582) vier Handläufe auf `main`, Protokollzeilen wörtlich:
1. `lesen`, Lauf 41305445974: `version 1.0 IOS appStoreState=REJECTED`, `notizen gesetzt bytes=417`, `anhang keine`, `zusammenfassung geschrieben=0`.
2. `notizen`, Lauf 41305507863: `notizen gesetzt bytes=2514`, `gegenprobe gleich=ja`, `zusammenfassung geschrieben=1`.
3. `lesen`, Lauf 41305554506: `notizen gesetzt bytes=2514` (gleich dem ersten Codeblock der Datei, 2514 Byte), `anhang keine`, `zusammenfassung geschrieben=0`.
4. `notizen`, Lauf 41305602758: `notizen unverändert bytes=2514`, `zusammenfassung geschrieben=0`.
F001 (Zeilenumbruch am Ende) ist damit widerlegt: Apple gibt den Text unverändert zurück, die Gegenprobe ist gleich, der zweite Lauf schreibt nicht. Die Läufe sind in docs/reference/testflight.md verlinkt.
Code reference: scripts/asc_review_notes.py:115 (Gleichheitsvergleich, im echten Lauf 4 bestätigt).

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

**VERIFIED**

AC-1 bis AC-10 bewiesen: 16 neue und 469 Python-Tests insgesamt grün, CI von PR #790 grün, AC-9 durch vier echte Läufe gegen App Store Connect (Runde 3). F001 im echten Lauf widerlegt, F002 LOW und spec-konform.

## Geprüfte Dateien

- sha256:472fb9affa401c9e15e86025f34c4595d95d0e05807bb4b7110e17d5821233c7  .github/workflows/asc-review-notes.yml
- sha256:1d5581ad738dfd0f6fb2454f21a5c45e9fd067cca77ae8797724a052f0670f43  docs/reference/app-review-notizen.md
- sha256:b7b6d847cb70e0139dfa1e310454862d772f61b7749ff0345a8d91cd6a9d0711  scripts/asc_review_notes.py
- sha256:9b5546b46e4b52b062dc510eb34ff8c834253f88dd4d2c3bad023c30db485608  scripts/test_asc_review_notes.py

## Prüfbasis

- base: 6bb98b225f3d418f6cf52fc602ece09cda6f1816
- blob:9cd7cdadae62ceb01da659104836094eb762175f  .github/workflows/asc-review-notes.yml
- blob:284edbcc2fa7de9a57fdb6e49db692c3df77c0e8  docs/reference/app-review-notizen.md
- blob:18d6f9e6dd3752d3e7b72c5518bb4cf20be21b11  scripts/asc_review_notes.py
- blob:cfcd65400a49aec96d41fca671f429c523b7b3b4  scripts/test_asc_review_notes.py

## Geprüfte Dateien

- sha256:472fb9affa401c9e15e86025f34c4595d95d0e05807bb4b7110e17d5821233c7  .github/workflows/asc-review-notes.yml
- sha256:1d5581ad738dfd0f6fb2454f21a5c45e9fd067cca77ae8797724a052f0670f43  docs/reference/app-review-notizen.md
- sha256:b7b6d847cb70e0139dfa1e310454862d772f61b7749ff0345a8d91cd6a9d0711  scripts/asc_review_notes.py
- sha256:9b5546b46e4b52b062dc510eb34ff8c834253f88dd4d2c3bad023c30db485608  scripts/test_asc_review_notes.py

## Prüfbasis

- base: d37d582c2a60f6b01124d2c948ad50ba2faf0959
- blob:9cd7cdadae62ceb01da659104836094eb762175f  .github/workflows/asc-review-notes.yml
- blob:284edbcc2fa7de9a57fdb6e49db692c3df77c0e8  docs/reference/app-review-notizen.md
- blob:18d6f9e6dd3752d3e7b72c5518bb4cf20be21b11  scripts/asc_review_notes.py
- blob:cfcd65400a49aec96d41fca671f429c523b7b3b4  scripts/test_asc_review_notes.py
