# Adversary Dialog — fix-837-asc-fehlercode
Spec: docs/specs/fix-837-asc-fehlercode.md
Datum: 2026-11-06 (Durchlauf 2)

## Checkliste
- [x] **AC-1:** Given eine 4xx-Antwort mit gültigem `errors[].code`, When `send_json` scheitert, Then steht der Code in der Fatal-Meldung hinter dem unveränderten Präfix. Belegt durch `test_rejected_write_names_apple_error_code`.
- [x] **AC-2:** Given `title`/`detail` oder Codes außerhalb `[A-Z0-9_.]+`, When die Meldung entsteht, Then erscheinen sie nie; höchstens fünf Codes. Belegt durch `test_error_code_filter_and_limit`, `test_409_message_keeps_code`.
- [x] **AC-3:** Given ein nicht lesbarer oder fremd geformter Rumpf, When `send_json` scheitert, Then ist die Meldung wie bisher. Belegt durch `test_unreadable_error_body_keeps_old_message`.
- [x] **AC-4:** Given 403 oder 409 an `asc_app_info.send`, Then bleibt der 403-Text unverändert und der 409-Text nennt zusätzlich den Code. Belegt durch `test_403_message_unchanged`, `test_409_message_keeps_code`.
- [ ] **AC-5:** Given der Merge auf `main`, When `asc-app-info aktion=untertitel` erneut läuft, Then nennt das Protokoll Apples Fehlercode des 409 (oder der Lauf gelingt), und der Abschlussbericht benennt daraus die Ursache (#842 oder anders). Belegt durch den Lauf-Link. (nachgelagert, CI-Lauf nach Merge; kein Befund)

## Dialog

### Runde 1
**Adversary:** Vorgeschichte F001 (Zahl-Code -> TypeError) nachgestellt. Eigene Proben gegen `error_codes` mit direkt gebauten Rümpfen: Zahl 409, bool, Liste, Objekt, None, `errors` als Objekt/String/null, Top-Level Liste/String/null, Elemente str/None/verschachtelt, "A\n" (fullmatch-Zeilenende), "A\nB" (Log-Injektion), Kleinbuchstaben, Unicode-Ziffer "A٣", leerer String, ungültiges UTF-8 (\xff), leerer Rumpf, NaN, OSError beim read, Rumpf über 8 KB (abgeschnitten, damit ungültiges JSON), 4000-fach verschachtelte Listen auch mit recursionlimit 200. Ergebnis: jede Störung ergibt [], nie eine Ausnahme; gültiger Code kommt durch; sieben Codes ergeben fünf. Der Filter `isinstance(code, str)` und `re.fullmatch` verhindert Zeilenumbrüche und Nicht-ASCII-Ziffern.
Code reference: scripts/asc_what_to_test.py:29
**Implementierer:** F001 ist behoben: `error_codes` prüft `isinstance(e.get("code"), str)` vor dem Muster; `test_numeric_error_code_keeps_old_message` deckt Zahl-Code ab (Meldung wie bisher, kein TypeError in stderr).
Code reference: scripts/test_asc_what_to_test.py:177

Prüfung `send_json`: Präfix `ASC answered HTTP {code} for {method} {path}` unverändert, Anhang ` (codes: …)` nur bei nicht leerer Liste; 5xx/408/429-Wiederholungen lesen den Rumpf nicht (nur im Fatal-Zweig).
Code reference: scripts/asc_what_to_test.py:50
Tests AC-1..AC-3 grün (15 Tests in test_asc_what_to_test.py).
Code reference: scripts/test_asc_what_to_test.py:144

### Runde 2
**Adversary:** `asc_app_info.send` mit gestelltem `send_json`-Fatal geprüft: 409 ohne Codes -> Festtext ohne Anhang; 409 mit Codes -> Festtext plus ` (codes: A.B, C)`; 403 mit Codes im Text -> 403-Festtext ohne Codes (Zweig steht vor 409); 422 -> unverändert durchgereicht. Prüfung `"HTTP 409" in str(error)`: Codes enthalten keine Leerzeichen, können "HTTP 403" nicht vortäuschen. Andere Aufrufer von `send_json` (asc_beta_invite, asc_beta_setup, asc_review_notes, asc_what_to_test) werten nur "HTTP 403"/"HTTP 404"/"HTTP 409" per `in` aus; das Präfix ist unverändert, der Anhang stört nicht (beta_invite maskiert IDs per Regex, Codes bleiben unberührt). RAW_SECRET/detail erscheint nie (Test grün, 16 Tests in test_asc_app_info.py).
Code reference: scripts/asc_app_info.py:95
**Implementierer:** Tests `test_409_message_keeps_code` und `test_403_message_unchanged` belegen AC-4 über den echten Subprozess gegen den Fake-Server.
Code reference: scripts/test_asc_app_info.py:247

Restrisiken (kein Befund): Rumpf über 8 KB wird abgeschnitten und ergibt ungültiges JSON, also die alte Meldung (spezifikationskonform). Duplikate werden nicht entfernt (A, A), nur kosmetisch. Die CI-Python-Version erzeugt auch bei verschachteltem Rumpf keine RecursionError (mit Limit 200 geprüft).

Confirmation AC-1: Code reference scripts/asc_what_to_test.py:52 — Status CONFIRMED (Anhang an Fatal-Meldung).
Confirmation AC-2: Code reference scripts/asc_what_to_test.py:34 — Muster und Slice [:5], nie title/detail — CONFIRMED.
Confirmation AC-3: Code reference scripts/test_asc_what_to_test.py:167 — CONFIRMED.
Confirmation AC-4: Code reference scripts/test_asc_app_info.py:257 — CONFIRMED.

## Herkunft der Vorbedingungen

Kein Sprachprofil konfiguriert (`precondition_origins.default_lang`). Betroffene Felder sind keine Modellfelder, sondern der Fehlercode-Anhang der Fatal-Meldung.

| Feld | Produktions-Schreibstellen | Bedingung davor | Test für diesen Weg |
|---|---|---|---|
| Fatal-Meldung `(codes: …)` | 1 (scripts/asc_what_to_test.py:52) | Antwort ist 4xx außer 408/429, Rumpf ist JSON mit `errors[].code` als String nach `[A-Z0-9_.]+` | test_rejected_write_names_apple_error_code, test_numeric_error_code_keeps_old_message |
| 409-Festtext `(codes: …)` | 1 (scripts/asc_app_info.py:95) | Fatal-Text enthält "HTTP 409" und ` (codes: ` | test_409_message_keeps_code |

F001 (Zahl-Code, TypeError): behoben und durch Test belegt.

## Verdict
VERDICT: VERIFIED
Tests: 31 passed (15 + 16), 0 failed, 0 übersprungen
Edge cases: alle geprüft, keine gebrochen
Regressions: none found
Checklist: AC-1..AC-4 proven; AC-5 nachgelagert (CI-Lauf nach Merge)

## Geprüfte Dateien

- sha256:4bd6730dab1c1445193c0e6d77d81e50ed69056cadf7ec33084b4024a68400bb  scripts/asc_app_info.py
- sha256:972c04c77c8f76decd2e148da8b0e613519421f258737835537371ff7058b742  scripts/asc_what_to_test.py
- sha256:5184906043a44b796f1c00ff381527591aacf984715cc3e83172dcc28b8e0648  scripts/test_asc_app_info.py
- sha256:d3a3cce5df5a87e3b19df3e79a256fd54ca67c256329c025b8c15ad290cee7d4  scripts/test_asc_what_to_test.py

## Prüfbasis

- base: d5b8c961eee06b98f6ac17993c4bf0f19c2417f5
- blob:167ac5c60af91bb822fc05b02e4d43cc4899d241  scripts/asc_app_info.py
- blob:5fba19958ffa375cf668dc4bb51cc8f32551a67a  scripts/asc_what_to_test.py
- blob:dea34e81b1c65ec67816c368d3a4f074da81561f  scripts/test_asc_app_info.py
- blob:7bbd3da36bcc7c08722385c33c48fbc6296ff0fb  scripts/test_asc_what_to_test.py
