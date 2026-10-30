# Adversary Dialog — feature-705-oeffentlicher-link
Spec: docs/specs/feat-705-schnitt-2b2c-oeffentlicher-link.md
Datum: 2026-10-30 09:37

## Checkliste
- [x] **AC-1:** Das Skript schaltet den Link nicht ein, solange der neueste gültige Build einer Plattform nicht in der Gruppe `Tester` liegt oder nicht `BETA_APPROVED` ist (auch nicht lesbar): kein PATCH, Zeile `link zustand=nicht-bereit …`, Exit 0. Geprüft durch `test_not_ready_build_is_not_enabled` und `test_build_missing_in_group_is_not_ready`.
- [x] **AC-2:** Sind alle Vorbedingungen erfüllt, sendet es genau einen PATCH auf die Gruppe mit `publicLinkEnabled=true`, `publicLinkLimitEnabled=true`, `publicLinkLimit=50`, liest die Gruppe erneut und meldet `link zustand=eingeschaltet limit=50`, Exit 0. Geprüft durch `test_enable_sends_one_patch_with_limit_50`.
- [x] **AC-3:** Ein zweiter Lauf schreibt nichts: kein PATCH, `link zustand=vorhanden limit=50`, `zusammenfassung geschrieben=0`. Geprüft durch `test_second_run_writes_nothing`.
- [ ] **AC-4:** Es bleibt nie ein Link ohne bestätigtes Limit 50 eingeschaltet: stimmt das Limit nach dem PATCH nicht oder ist das Gegenlesen nicht möglich, folgt ein zweiter PATCH mit `publicLinkEnabled=false`, die Zeile `link zustand=abgebrochen grund=limit` und Exit 1. Geprüft durch `test_limit_mismatch_switches_back_off` und `test_unreadable_readback_switches_back_off`.
- [x] **AC-5:** `--aus` schaltet einen eingeschalteten Link mit einem PATCH ab (`link zustand=ausgeschaltet`), bei ausgeschaltetem Link gibt es keinen PATCH (`link zustand=vorhanden aus`). Geprüft durch `test_off_switches_link_off_and_is_idempotent`.
- [x] **AC-6:** Fehlt die externe Gruppe `Tester`, endet der Lauf mit `::error::` und Exit 1 vor jedem Schreiben. Geprüft durch `test_missing_group_aborts_before_any_write`.
- [x] **AC-7:** Bei 403 steht der bestehende Text „Schlüssel ohne Schreibrecht: Rolle des API-Schlüssels in App Store Connect prüfen“ in der Ausgabe, bei anderen 4xx eine `::error::`-Zeile; beide Exit 1, der PATCH wird nicht wiederholt. Geprüft durch `test_forbidden_and_other_errors_are_reported`.
- [x] **AC-8:** Die Ausgabe (stdout und stderr) enthält nur Zustandswörter: nie den Einladungslink, keine Gruppen-, App- oder Build-IDs, keine Buildnummern, kein Schlüsselmaterial. Geprüft durch `test_output_has_only_state_words`.
- [x] **AC-9:** `.github/workflows/asc-beta.yml` bietet `link` und `link-aus` an; der Job `link` ruft `scripts/asc_beta_link.py` (bei `link-aus` mit `--aus`) nur bei der jeweiligen Wahl auf (Schlüssel mit `umask 077` und `trap rm`, `ubuntu-latest`); `probe` hängt per `needs` auch an `link`; es gibt nur die Eingabe `aktion` und keinen `push`-, `schedule`- oder `workflow_run`-Auslöser; die Datei nennt `publicLinkEnabled` und `betaAppReviewSubmissions` nicht; `testflight.yml` nennt das Skript nicht. Geprüft durch `test_workflow_file` (neu) und den angepassten `test_workflow_file` in `test_asc_beta_invite.py`.
- [x] **AC-10:** `asc_beta_invite.py` bleibt unverändert und enthält weiter kein PATCH und kein Schreiben von `publicLink*`; `zuordnen` und `einreichen` können den Link nicht einschalten. Geprüft durch `test_invite_script_untouched` und `git diff --stat`.
- [x] **AC-11:** `docs/reference/testflight.md` führt „Beta-Review“ als `APPROVED` mit Beleg Lauf 41019692346, die Zeile „Öffentlicher Link“ als `offen` mit Verweis auf #743 und den Handlauf `link` samt Rückfall über App Store Connect. Geprüft durch `test_testflight_doc_lists_link_row`.

## Dialog

### Runde 1
**Adversary:** Nachpruefung nach den Haertungen F001/F002/F003/F005. Belege selbst erzeugt.
- Tests: `python3 -W ignore scripts/test_asc_beta_link.py -v` = 17 Tests OK; `scripts/test_asc_beta_invite.py -v` = 27 Tests OK (Ausgabe in adversary-test-output.txt). Umfang: Aenderungen nur an asc-beta.yml, testflight.md, test_asc_beta_link.py (+ neu asc_beta_link.py); `scripts/asc_beta_invite.py` und `test_asc_beta_invite.py` ohne Diff gegen HEAD.
- Mutationsproben an Kopien (Wegwerfordner im Scratchpad, Produktionscode unberuehrt), Tests dagegen: m1 (Zurueckschalten nach Limit-Abweichung entfernt) = 4 Tests rot; m2 (Argumentpruefung entfernt) = 3 Faelle rot; m3 (nicht lesbares Gegenlesen zaehlt als bestaetigt) = 2 rot; m4 (--aus patcht nur bei ausdruecklich True) = 3 rot (true-String, None, fehlt); m5 (undo_failed_enable entfernt) = 1 rot. Alle Mutanten werden getoetet, die Tests beweisen also die zugehoerigen ACs.
- Angriff --aus (Skript adversary/r2.py): publicLinkEnabled True, "true", 1, 0, None, "false", fehlt = je ein PATCH `{publicLinkEnabled: False}`, `link zustand=ausgeschaltet`; nur ausdruecklich False = `vorhanden aus`, 0 Schreibaufrufe. Ein Zustand mit Link an fuehrt nie zu "vorhanden aus".
- Argumente: `--aus=1`, `-aus`, leere Zeichenkette, `--aus --aus`, `--aus ` (Leerzeichen), `--aus x`, `--AUS` = Exit 2, `zusammenfassung geschrieben=0`, 0 Anfragen an den Nachbau.
- Zurueckschalten scheitert (r2.py): 403 = Text zum Schluessel, 422 = `HTTP 422 for PATCH /v1/betaGroups/...`, 500/503 = 5 Wiederholungen, dann `ausschalten-gescheitert`; immer Exit 1, kein `abgebrochen`, `zusammenfassung geschrieben=1` (nur der erste PATCH zaehlt), weder Link noch IDs in der Ausgabe. Einschalt-PATCH 403 mit Link bereits an (r4.py): `ausschalten-gescheitert`, Exit 1; 500 mit angewendetem PATCH und unlesbarem Gegenlesen: Ausschalt-PATCH wird versucht (unlesbar = an). Lecktest: weder LINK, G-7c41-1 noch Buildnummern 4711/4712 in irgendeiner Ausgabe.
- Finding F001 (neu, siehe unten): ein Gegenlesen mit unerwarteter Antwortform wirft keine Fatal, sondern TypeError/KeyError/AttributeError (adversary/r3.py). Die Ausnahme wird nicht in switch_on gefangen (nur Fatal), es folgt KEIN Ausschalt-PATCH, der Link bleibt an. Ausgabe nur `::error::'str' object has no attribute 'get'`, Exit 1, `geschrieben=1`.
**Implementierer:** (vom Adversary selbst eingetragen) Belege oben reproduzierbar mit `cd docs/artifacts/feature-705-oeffentlicher-link/adversary && python3 -W ignore r2.py` bzw. `r3.py`, `r4.py`. F001 ist reproduziert: bei Antwortform `data: ["x"]`, Gruppe ohne `id` oder `attributes` als Liste nach dem Einschalten bleibt genau ein PATCH (an) stehen.

### Runde 2
**Adversary:** Nachfragen zu Duennem und Randfaellen.
- Nachfrage 1: Kann eine Ausnahme im Gegenlesen auch den Zurueckschalte-Weg umgehen, wenn der Ausschalt-PATCH selbst scheitert? Antwort: nein, dort faengt `except Exception` in switch_on (Zeile 87) und `except Fatal` (Zeile 98) und meldet laut. Nur der Gegenlese-Pfad (Zeile 90-93) ist auf Fatal beschraenkt.
- Nachfrage 2: Haelt `undo_failed_enable` bei nicht-Fatal im Lesen? Belegt: Zeile 87 faengt alles und meldet `ausschalten-gescheitert`; Ursprungsfehler bleibt `::error::`. In Ordnung.
- Nachfrage 3: Wird die Zusammenfassung in allen Fehlerpfaden geschrieben? Ja: Argumentfehler (Zeile 132), jeder Ausnahmepfad (Zeile 144-147). Ausnahme nur bei BaseException (KeyboardInterrupt, SIGTERM zwischen Einschalt-PATCH und Gegenlesen, Runner-Abbruch): dann kein Zurueckschalten, nicht abdeckbar im Skript; Restrisiko ueber `aktion=link-aus` als Notausschalter, im Doku genannt.
- Nachfrage 4: JSON-Fehler, Netzfehler, Zeitueberschreitung im Gegenlesen: get_json gibt None zurueck, get_data wirft Fatal, switch_on schaltet aus (Mutant m3 belegt, dass der Test das erzwingt). In Ordnung.
- Nachfrage 5: Dubletten `Tester` nach dem PATCH: plan_group wirft Fatal, wird gefangen, Ausschalten. In Ordnung.
- Nachfrage 6: Reihenfolge der Ausgabezeilen: `ausschalten-gescheitert`, dann `::error::`, dann `zusammenfassung`. Stimmig; Plattformzeilen `kein-gueltiger-build` vor dem Ergebnis.
- Schaerfster Randfall bleibt F001: Die Spec fordert in AC-4 "Gegenlesen nicht moeglich" als Ausloeser des zweiten PATCH; ein nicht auswertbares Gegenlesen faellt unter diesen Wortlaut. Die Haertungsstelle ist eine Zeile (`except Exception` statt `except Fatal` in Zeile 92), ohne Testnachweis heute: kein Test deckt eine fehlgeformte Gegenleseantwort ab (alle Tests nutzen 500 per break_reads_after_patch).
**Implementierer:** Eingetragen vom Adversary: F001 offen. Alles andere reproduziert und in Ordnung.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

Finding:
  ID: F001
  Severity: HIGH
  Category: edge_case
  Code reference: scripts/asc_beta_link.py:92
  Description: switch_on faengt beim Gegenlesen nur Fatal. Liefert die Gruppenabfrage nach dem Einschalten eine unerwartete Form (Element kein Objekt, Gruppe ohne id, attributes als Liste), wirft plan_group/read_group einen AttributeError/KeyError. Der steigt bis main, Exit 1, aber der Link bleibt mit unbestaetigtem Limit an (nur ein PATCH, Beleg adversary/r3.py).
  Spec requirement: AC-4 — nie ein Link ohne bestaetigtes Limit 50; Gegenlesen nicht moeglich folgt der zweite PATCH.
  Conflict: Ein nicht auswertbares Gegenlesen schaltet nicht zurueck.
  Remediation: Zeile 92 `except Exception:` (wie im Zurueckschalt-Zweig), dazu ein Test mit fehlgeformter Gegenleseantwort (`data: ["x"]`).

Confirmation:
  AC: AC-1 bis AC-8
  Code reference: scripts/asc_beta_link.py:30
  Evidence: plan_link/enable/switch_on/disable/main; 17 Tests gruen, fuenf Mutanten getoetet, Argument- und Leckproben ohne Befund.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: scripts/test_asc_beta_link.py:229
  Evidence: test_off_with_odd_enabled_value_still_patches wird von Mutant m4 getoetet; --aus patcht bei jedem Wert ausser ausdruecklich False.
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: .github/workflows/asc-beta.yml:98
  Evidence: Job link bei link/link-aus, Zeile 113 ohne, Zeile 120 mit --aus; keine verbotenen Woerter; test_workflow_file gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-11
  Code reference: docs/reference/testflight.md:170
  Evidence: Zeile Oeffentlicher Link `offen` mit #743, Beta-Review APPROVED mit Lauf 41019692346 (Zeile 172).
  Status: CONFIRMED

Confirmation:
  AC: AC-10
  Code reference: scripts/test_asc_beta_invite.py:418
  Evidence: asc_beta_invite.py und test_asc_beta_invite.py ohne Diff gegen HEAD; 27 Tests gruen; test_invite_script_untouched gruen.
  Status: CONFIRMED

**BROKEN**
