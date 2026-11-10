# Adversary Dialog — feat-893-c-gruende
Spec: docs/specs/feat-893-schnitt-c-gruende.md
Datum: 2026-11-10 13:31

## Checkliste
- [x] **AC-1:** Given 409 oder 422 von Apple mit `meta.associatedErrors` als Objekt, When `einreichen` läuft, Then nennt die Meldung je Eintrag Pfad und Code (`gründe: <pfad>=<code>`). Belegt durch `test_reasons_from_associated_errors_object_form`.
- [x] **AC-2:** Given `associatedErrors` als Liste, When `einreichen` läuft, Then nennt die Meldung Pfad (aus `source.pointer`, sonst `?`) und Code. Belegt durch `test_reasons_from_associated_errors_list_form`.
- [x] **AC-3:** Given eine unbekannte Form von `meta`, When `einreichen` läuft, Then nennt die Meldung nur die Schlüsselnamen von `meta`, nie Werte. Belegt durch `test_unknown_form_shows_meta_key_names_only`.
- [x] **AC-4:** Given fehlendes, kaputtes oder nicht lesbares `meta` bzw. kein JSON, When `einreichen` läuft, Then bleibt die Meldung wie vor Schnitt C, es gibt keine Ausnahme, Ausgang 1. Belegt durch `test_broken_or_missing_meta_changes_nothing`.
- [x] **AC-5:** Given Kennungen, Wortlaut, Sonderzeichen oder mehr als 8 Einträge in den Gründen, When die Meldung entsteht, Then stehen Kennungen als `<id>`, unzulässige Codes als `?`, höchstens 8 Paare, nie `title`, `detail`, Rohantwort oder Geheimwert. Belegt durch `test_reasons_sanitize_ids_wording_and_limit`.
- [x] **AC-6:** Given 4xx mit Gründen, When `einreichen` läuft, Then bleibt es bei genau einem Schreibaufruf des betroffenen Schritts, Ausgang 1, kein weiterer Schreibaufruf und kein anderer Schreibweg als die drei aus Schnitt B. Belegt durch `test_reasons_keep_single_write_and_exit_one`.
- [x] **AC-7:** Given die Tests aus Schnitt A und B, When der Skripttest läuft, Then bleiben alle grün (AC-8 und AC-10 aus Schnitt B gelten weiter). Belegt durch den Lauf von `python3 scripts/test_asc_store_submit.py`.

## Dialog

### Runde 1
**Adversary:** Skripttest gelaufen (32 Tests, OK, siehe adversary-test-output.txt). Eigene Eingaben direkt gegen `associated_reasons`/`mask`/`error_body`: kaputte Formen (None in errors, errors als Dict, associatedErrors als Liste mit Nicht-Objekten, source als Zahl, code als Liste/None, Schlüssel 5000 Zeichen, Nicht-UTF8-Rumpf, `[1]`, `null`) liefern nie eine Ausnahme, nur `''` oder `?`-Paare. UUID im Pfad -> `<id>`. Pfad `/v1/x/<id>;/v1/zz/SECRET` -> `?` (Semikolon nicht in Whitelist). Pfad `/v1/apps/<id>secretletters` wird von `mask` zu `/v1/apps/…` (Lookahead verlangt Trenner nach `<id>`), kein Umgehen. Pfad `/v1/apps/abcdef/y` wird von `mask` zu `/v1/apps/…/y`. 5xx/Netzzweige: Diff zeigt sie unveraendert; `asc_what_to_test.py` und `asc_beta_invite.py` ohne Diff.
**Implementierer:** n/a (Adversary-Lauf).

Finding F001 (siehe unten): Codes laufen nicht durch den Kennungsfilter.

### Runde 2
**Adversary:** Gezielte Angriffe auf die Abweichungen. (a) Zeichensatz Code `[A-Za-z0-9_.]{1,80}`: `tok_live_secretword` und `ABCD1234EFGH` und `1234567890` erscheinen unveraendert als Code in der Meldung (`/v1/apps/<id>/x=ABCD1234EFGH`, `secretlettersonly=1234567890`); `mask` greift nur nach `/v1/<art>/` und `?name=`. Die ID-Regex wird nur auf Pfade angewandt (`reason_path`), nicht auf `reason_code`. (b) Pfad ohne `/v1/`-Praefix wie `secretlettersonly` oder JWT-aehnlich `eyJhbGciOiJIUzI1NiJ9.payload.sig` bleibt stehen, solange keine 4-stellige Ziffernfolge drin ist (Whitelist, laut Spec so gewollt). (c) `meta:`-Schluesselnamen: `tok123456789` bleibt stehen (kein ID-Filter, spec-konform, nur Whitelist). (d) `<id>`-Ausnahme in `mask`: nur literales `<id>` mit folgendem Trenner `[/\s=,;]` oder Ende; ein Angreifer kann damit nur den Platzhalter selbst erzeugen, keine echte Kennung durchschleusen, weil echte Aufrufpfade nie `<id>` enthalten. Kein Sicherheitsloch durch `mask`/`Watched.write` (ersetzt super().write durch dieselbe Regel + Ausnahme). Schreibaufrufe: `send_once` weiter genau ein urlopen, 4xx bleibt Fatal; Test 667 gruen. Fazit: die Abweichungen oeffnen kein Loch fuer Kennungen in Pfaden oder Aufrufpfad; das Restrisiko liegt in der Breite von Code und Schluesselnamen (Server-Text bis 80 Zeichen ohne Kennungsfilter).
**Implementierer:** n/a.

### Runde 3
**Adversary:** Nach der Nachbesserung F001 erneut mit meinen Gegenbeispielen gegen `reason_code` (scripts/asc_store_submit.py:335) und `associated_reasons`: `ABCD1234EFGH` -> `<id>`, `1234567890` -> `<id>`, `a<id>b` bleibt, Meta-Schluessel `tok123456789` -> `meta: <id>, ok`. `tok_live_secretword` (keine Ziffernfolge, kein Kennungsmuster) bleibt als Code stehen; das ist ein Wort, keine Kennung, und spec-konform. `mask` auf der fertigen Meldung: kein Leck; Pfade der Form `/v1/apps/<id>x` werden (Lookahead verlangt Trenner nach `<id>`) zu `/v1/apps/…` und verschlucken dabei die folgenden Paare bis zum naechsten Leerzeichen (Ueber-Maskierung, nur bei Gruenden, deren Pfad selbst mit `/v1/<art>/` beginnt) = F002, kosmetisch, kein Leck. Meta-Ausgabe `meta: <id>, ok` bleibt von `mask` unberuehrt. Skripttest neu: 32 Tests, OK, exit 0 (adversary-test-output.txt neu geschrieben).
**Implementierer:** F001 behoben.

## Confirmations und Findings

Confirmation:
  AC: AC-1
  Code reference: scripts/asc_store_submit.py:362
  Evidence: Objektform ergibt `pfad=code`; Probe und test_reasons_from_associated_errors_object_form gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: scripts/asc_store_submit.py:346
  Evidence: Listenform nutzt source.pointer/parameter sonst `?` (reason_pairs); Test list_form gruen, source als Zahl ergibt `?`.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: scripts/asc_store_submit.py:362
  Evidence: ohne Paare nur Schluesselnamen (`; meta: ok, tok123456789`), nie Werte.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: scripts/asc_store_submit.py:315
  Evidence: error_body und associated_reasons fangen alle Stoerungen (Probe: Nicht-UTF8, `[1]`, `null`, errors als Dict), nie Ausnahme.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: scripts/test_asc_store_submit.py:649
  Evidence: Kennungen in Pfaden -> `<id>`, Codes ausserhalb Zeichensatz `?`, max 8 Paare, title/detail nie gelesen; Test gruen. Einschraenkung siehe F001.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: scripts/test_asc_store_submit.py:667
  Evidence: send_once (scripts/asc_store_submit.py:384) ruft urlopen einmal, Fehlerzweig wirft Fatal; Test gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: scripts/test_asc_store_submit.py:593
  Evidence: python3 scripts/test_asc_store_submit.py: Ran 32 tests, OK (docs/artifacts/feat-893-c-gruende/adversary-test-output.txt).
  Status: CONFIRMED

Finding:
  ID: F001
  Severity: MEDIUM (BEHOBEN, Runde 3 bestaetigt)
  Category: security
  Code reference: scripts/asc_store_submit.py:335
  Description: reason_code gibt jeden String aus `[A-Za-z0-9_.]{1,80}` unveraendert aus; die Kennungsregel `ID` wird nur in reason_path angewandt. Probe: `code="ABCD1234EFGH"`, `"1234567890"`, `"tok_live_secretword"` stehen wortgleich in der Meldung; `mask` blendet sie nicht aus. Gleiches gilt fuer Schluesselnamen in `meta:` (`tok123456789`, associated_reasons, Zeile 362).
  Spec requirement: AC-5 / Abschnitt 3 — nie Kennung, Schluessel oder Token in der Meldung.
  Conflict: Die Spec erlaubt den weiten Zeichensatz fuer Codes ausdruecklich, damit ist das spec-konform; es bleibt aber ein Pfad, auf dem ein Server-String (Kennung, Token) bis 80 Zeichen ins CI-Protokoll gelangt. Realistisch ist das bei Apples Fehlercodes unwahrscheinlich (Codes sind feste Woerter wie `ENTITY_ERROR.ATTRIBUTE.REQUIRED`).
  Remediation: `ID.sub("<id>", code)` auch in reason_code (und in den Schluesselnamen) vor der Ausgabe; alternativ Codes auf Grossbuchstaben-Form `[A-Z0-9_.]` beschraenken wie die Hauptcodes.

Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: scripts/asc_store_submit.py:42
  Description: `mask` schluckt bei `/v1/apps/<id>secretletters=a` das Stueck samt dem folgenden Trenner-Kontext nicht sauber: Ausgabe `/v1/apps/… ?=d` (Nachbarpaar verschmilzt, Komma verloren). Rein kosmetisch, kein Leck.
  Spec requirement: Abschnitt 3 (mask)
  Conflict: Lesbarkeit der Gruende leidet in dem Randfall.
  Remediation: keine noetig, oder `[^/\s?,;]+` im Pfadstueck.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`). Keine Verdachtszeilen; Schnitt C schreibt keine Felder, nur die Fehlermeldung.

## Verdict

Geaenderte Dateien: scripts/asc_store_submit.py (Code reference: scripts/asc_store_submit.py:335), scripts/test_asc_store_submit.py (Code reference: scripts/test_asc_store_submit.py:593).

VERDICT: VERIFIED
Tests: 32 bestanden, 0 fehlgeschlagen, 0 uebersprungen. F001 behoben und belegt. Notiz F002 (LOW, kosmetisch): mask ueber-maskiert Gruende mit Pfad `/v1/<art>/…`, kein Leck. Checklist: 7/7 proven.

## Geprüfte Dateien

- sha256:b4c746337789e799f91420f571822e7d8ce23dfa7548830809837037caf6da86  scripts/asc_store_submit.py
- sha256:e20d572f4a62e3d40df7cb28ea078f09a4926d86df020c39bcead34c2c490d53  scripts/test_asc_store_submit.py

## Prüfbasis

- base: ee7f14a30e96d56e20feb38118e769899bd298d4
- blob:9173df60b72ce83aa2a27332acf9234b1107623d  scripts/asc_store_submit.py
- blob:6c2289b492f8ec10832e312177b73e95462dbbd4  scripts/test_asc_store_submit.py
