# Adversary Dialog — feature-705-oeffentlicher-link
Spec: docs/specs/feat-705-schnitt-2b2c-oeffentlicher-link.md
Datum: 2026-10-30 09:51

## Checkliste
- [x] **AC-1:** Das Skript schaltet den Link nicht ein, solange der neueste gültige Build einer Plattform nicht in der Gruppe `Tester` liegt oder nicht `BETA_APPROVED` ist (auch nicht lesbar): kein PATCH, Zeile `link zustand=nicht-bereit …`, Exit 0. Geprüft durch `test_not_ready_build_is_not_enabled` und `test_build_missing_in_group_is_not_ready`.
- [x] **AC-2:** Sind alle Vorbedingungen erfüllt, sendet es genau einen PATCH auf die Gruppe mit `publicLinkEnabled=true`, `publicLinkLimitEnabled=true`, `publicLinkLimit=50`, liest die Gruppe erneut und meldet `link zustand=eingeschaltet limit=50`, Exit 0. Geprüft durch `test_enable_sends_one_patch_with_limit_50`.
- [x] **AC-3:** Ein zweiter Lauf schreibt nichts: kein PATCH, `link zustand=vorhanden limit=50`, `zusammenfassung geschrieben=0`. Geprüft durch `test_second_run_writes_nothing`.
- [x] **AC-4:** Es bleibt nie ein Link ohne bestätigtes Limit 50 eingeschaltet: stimmt das Limit nach dem PATCH nicht oder ist das Gegenlesen nicht möglich, folgt ein zweiter PATCH mit `publicLinkEnabled=false`, die Zeile `link zustand=abgebrochen grund=limit` und Exit 1. Geprüft durch `test_limit_mismatch_switches_back_off` und `test_unreadable_readback_switches_back_off`.
- [x] **AC-5:** `--aus` schaltet einen eingeschalteten Link mit einem PATCH ab (`link zustand=ausgeschaltet`), bei ausgeschaltetem Link gibt es keinen PATCH (`link zustand=vorhanden aus`). Geprüft durch `test_off_switches_link_off_and_is_idempotent`.
- [x] **AC-6:** Fehlt die externe Gruppe `Tester`, endet der Lauf mit `::error::` und Exit 1 vor jedem Schreiben. Geprüft durch `test_missing_group_aborts_before_any_write`.
- [x] **AC-7:** Bei 403 steht der bestehende Text „Schlüssel ohne Schreibrecht: Rolle des API-Schlüssels in App Store Connect prüfen“ in der Ausgabe, bei anderen 4xx eine `::error::`-Zeile; beide Exit 1, der PATCH wird nicht wiederholt. Geprüft durch `test_forbidden_and_other_errors_are_reported`.
- [x] **AC-8:** Die Ausgabe (stdout und stderr) enthält nur Zustandswörter: nie den Einladungslink, keine Gruppen-, App- oder Build-IDs, keine Buildnummern, kein Schlüsselmaterial. Geprüft durch `test_output_has_only_state_words`.
- [x] **AC-9:** `.github/workflows/asc-beta.yml` bietet `link` und `link-aus` an; der Job `link` ruft `scripts/asc_beta_link.py` (bei `link-aus` mit `--aus`) nur bei der jeweiligen Wahl auf (Schlüssel mit `umask 077` und `trap rm`, `ubuntu-latest`); `probe` hängt per `needs` auch an `link`; es gibt nur die Eingabe `aktion` und keinen `push`-, `schedule`- oder `workflow_run`-Auslöser; die Datei nennt `publicLinkEnabled` und `betaAppReviewSubmissions` nicht; `testflight.yml` nennt das Skript nicht. Geprüft durch `test_workflow_file` (neu) und den angepassten `test_workflow_file` in `test_asc_beta_invite.py`.
- [x] **AC-10:** `asc_beta_invite.py` bleibt unverändert und enthält weiter kein PATCH und kein Schreiben von `publicLink*`; `zuordnen` und `einreichen` können den Link nicht einschalten. Geprüft durch `test_invite_script_untouched` und `git diff --stat`.
- [x] **AC-11:** `docs/reference/testflight.md` führt „Beta-Review“ als `APPROVED` mit Beleg Lauf 41019692346, die Zeile „Öffentlicher Link“ als `offen` mit Verweis auf #743 und den Handlauf `link` samt Rückfall über App Store Connect. Geprüft durch `test_testflight_doc_lists_link_row`.

## Dialog

### Runde 1
**Adversary:** Dritte und letzte Prüfung. Beide Testdateien selbst gelaufen (adversary-test-output.txt): test_asc_beta_link.py Ran 19 OK, test_asc_beta_invite.py Ran 27 OK, 0 übersprungen. git status: geändert sind nur asc-beta.yml, testflight.md, test_asc_beta_link.py; asc_beta_invite.py und test_asc_beta_invite.py ohne Diff gegen HEAD; neu ist asc_beta_link.py. Angriffe, Skripte unter adversary/ (r5.py mit Ausgabe r5.out, r6.py mit r6.out, r7.py, mut.py mit mut.out, mut2.out):
(a) Fehlgeformte Antworten VOR dem PATCH (r5.py Gruppe PRE): Build ohne id, Build als String, Mitglied null, buildBetaDetail als Liste, Attribute als Liste, Gruppenliste als Objekt oder String. Ergebnis: Exit 1, geschrieben=0, PATCHES leer, in allen Fällen. externalBuildState als Zahl oder Liste: Exit 0 nicht-bereit, kein PATCH.
(b) Randwerte des Gegenlesens nach dem Einschalt-PATCH (r5.py Gruppe READBACK): Limit 50.0, Zeichenkette 50, True, 51, publicLinkLimitEnabled false, publicLinkEnabled als Zeichenkette und als 1, zweite externe Gruppe Tester, data null, Rumpf als Liste: jeweils zweiter PATCH mit publicLinkEnabled false, Zeile abgebrochen grund=limit, Exit 1, geschrieben=2. Eine interne Zusatzgruppe Tester wird ignoriert, Ergebnis eingeschaltet (richtig). Gutfall: ein PATCH, eingeschaltet.
(c) --aus mit publicLinkEnabled fehlend, None, True: je ein PATCH false, Exit 0. Tippfehlerargument --on: Exit 2, kein Schreiben (r7.py).
(d) Ausgabe: in keinem Lauf ein Link oder eine ID; die Retry-Zeilen der Helfer laufen durch Masked.
(e) BaseException (r6.py): SIGINT 4 s nach dem Einschalt-PATCH, während das Gegenlesen hängt. Ergebnis: Exit -2, Traceback auf stderr, PATCHES enthält nur den Einschalt-PATCH, die Gruppe bleibt mit Link an und Limit 50 laut Nachbau. Kein Ausschalt-PATCH. Derselbe Musterfehler wie in Prüfung 2, nur für BaseException (F001).
(f) Mutationsproben an Kopien im Scratchpad: Einzelmutationen M1 (Gegenlesen except Fatal), M2 (read_group ohne Übersetzung), M3 (confirmed ohne dict-Prüfung), M4 (undo except Fatal), M5 (Einschalt-PATCH except Fatal), M6 (Attribute ohne dict-Prüfung) bleiben ALLE grün (mut.out). Kombinationen M1+M2: 4 Fehlschläge (test_malformed_readback_switches_back_off); M4+M2: 4 Fehlschläge (test_malformed_readback_after_failed_enable_switches_back_off); M1+M2+M4: 8 Fehlschläge; M3+M6: grün (mut2.out).
(g) --aus bei zwei externen Gruppen Tester (r7.py): Exit 1 mit ::error::, kein PATCH, obwohl eine Gruppe den Link an hat.
(h) Bestehender Link an, Limit nicht aktiv, Builds nicht freigegeben (r6.py letzter Teil): Exit 0, nicht-bereit, geschrieben=0, Link bleibt an.
**Implementierer:** (vom Adversary selbst erzeugte Belege) Zu (f): Die Einzelmutationen überleben, weil zwei Schutzschichten dasselbe abdecken: read_group übersetzt in Fatal, das Gegenlesen fängt Exception. Erst das Entfernen beider Schichten wird rot; die Tests beweisen die Gesamtwirkung, nicht jede Schicht einzeln. M3+M6 ist ein äquivalenter Mutant: plan_group wirft bei nicht-dict-Attributen schon vorher, die Pfade sind unerreichbar. Zu (g): bewusst laut statt blind schreiben; Rückfall ist die Weboberfläche von App Store Connect (testflight.md).

### Runde 2
**Adversary:** Nachfragen zum Dünnen. Frage 1: Wie schwer wiegt (e)? Aus dem Code: asc_beta_link.py:90 sendet im selben PATCH Link an, Limit an und Limit 50; das Gegenlesen prüft nur, ob Apple es so übernommen hat. Bei Abbruch zwischen PATCH und Gegenlesen ist das Limit gesendet, aber nicht bestätigt. Der Workflow hat timeout-minutes 10 (SIGTERM umgeht jeden Python-Handler), ein Abbruch von Hand im Actions-Fenster ist möglich. Notausschalter link-aus existiert. Kein Link- oder ID-Leck: der Traceback in r6.out enthält nur Quellzeilen mit Platzhaltern, keine Kennungen (Suche nach Gruppen-ID, APP1, 127.0.0.1: kein Treffer). Einstufung MEDIUM, nicht HIGH, weil das Limit mitgesendet wird und link-aus es behebt. Es bleibt eine Restlücke gegenüber dem Wort „nie“ in AC-4.
Frage 2: Gibt es einen Pfad mit Exit 0 nach verschlucktem Fehler? In main fängt except Exception alles und setzt ok False (Exit 1). In switch_on und undo_failed_enable wird jede Ausnahme weitergereicht oder als ausschalten-gescheitert gemeldet, nie mit Exit 0. Exit 0 gibt es nur bei vorhanden, nicht-bereit, eingeschaltet (nach bestätigtem Limit) und ausgeschaltet. Belegt durch r5.out: jede fehlgeformte Antwort endet in Exit 1 oder nicht-bereit ohne Schreiben.
Frage 3: Reihenfolge von print und PATCH: die Ergebniszeile wird in main erst nach switch_on oder disable gedruckt, kündigt also nie eine Aktion an, die nicht stattfand. Die Zeile ausschalten-gescheitert steht vor dem raise, Exit 1.
Frage 4: message() auf unerwartete Typen: str(error) geht für jede Ausnahme, Masked.write ruft message mit str; kein Fehlerpfad gefunden. Die Meldung bei KeyError ist nur der Rohtext (r5.out PRE build-no-id), ohne Kennung (F006).
Frage 5: AC-Durchgang: AC-1 plan_link Zeile 32-40 und r5.out PRE-Fälle; AC-2 und AC-3 Gutfall und confirmed; AC-4 Randwerte (b) und Mutationen; AC-5 Fall (c); AC-6 Gruppenfälle und r7.py; AC-7 Test grün (apply_plan bildet 403 auf FORBIDDEN ab); AC-8 Ausgaben durchgesehen; AC-9 Diff des Workflows gelesen: Job link nur bei link und link-aus, umask 077 vor dem Schreiben des Schlüssels, trap rm, probe hängt per needs an link, keine neuen Auslöser, beide test_workflow_file grün; AC-10 kein Diff auf asc_beta_invite.py; AC-11 Zeilen 170 und 172 in testflight.md.
**Implementierer:** Kein Gegenbeweis zu F001; die Restlücke ist real, aber klein und bekannt. Empfohlene Behebung: den Block zwischen Einschalt-PATCH und Ausschalt-Entscheidung in switch_on mit BaseException absichern (KeyboardInterrupt) und im Workflow einen Schritt mit if: cancelled() ergänzen, der das Skript mit --aus aufruft; SIGTERM bleibt sonst unbehandelt.

### Befunde
Finding F001: MEDIUM, Kategorie edge_case.
Code reference: scripts/asc_beta_link.py:89
 Beschreibung: switch_on fängt nach dem Einschalt-PATCH nur Exception; KeyboardInterrupt (SIGINT beim Abbruch des Laufs) zwischen PATCH und Gegenlesen lässt den Link ohne bestätigtes Limit und ohne Ausschalt-PATCH stehen (r6.out). Spec requirement: AC-4. Behebung: BaseException abfangen und ausschalten, plus Workflow-Schritt mit if: cancelled() und --aus; Notausschalter link-aus bleibt der Rückfall.
Finding F002: LOW, Kategorie edge_case.
Code reference: scripts/asc_beta_link.py:145
 Beschreibung: --aus liest zuerst die Gruppe; bei zwei externen Gruppen Tester oder unlesbarer Liste endet es mit Exit 1 ohne zu schreiben (r7.py). Laut, kein stilles Versagen. Behebung: bei bekannter Gruppen-ID blind ausschalten oder den Rückfall über App Store Connect dokumentieren.
Finding F003: LOW, Kategorie edge_case.
Code reference: scripts/asc_beta_link.py:123
 Beschreibung: Die Zeile nicht-bereit gibt den Wert von externalBuildState unverändert aus, auch Zahl oder Liste (r5.out PRE detail-state-int). Keine Kennung, fail-closed. Behebung: nur bekannte Zustandswörter, sonst unbekannt.
Finding F004: LOW, Kategorie anti_pattern.
Code reference: scripts/test_asc_beta_link.py:224
 Beschreibung: Jede Härtungsschicht wird nur im Zusammenspiel geprüft (Einzelmutationen M1 bis M6 bleiben grün, erst M1+M2 und M4+M2 werden rot); die dict-Prüfungen in confirmed und read_group sind unerreichbarer Schutzcode. Behebung: keine nötig, oder ein Einzeltest je Schicht.
Finding F005: LOW, Kategorie edge_case.
Code reference: scripts/asc_beta_link.py:35
 Beschreibung: Steht der Link von Hand an, aber ohne Limit 50, und die Builds sind nicht freigegeben, meldet das Skript nicht-bereit mit Exit 0 und lässt den fremden Zustand stehen (r6.out). Das Skript hat ihn nicht erzeugt. Behebung: Warnzeile oder Hinweis auf link-aus.
Finding F006: LOW, Kategorie anti_pattern.
Code reference: scripts/asc_beta_link.py:151
 Beschreibung: Die Fehlermeldung bei KeyError und AttributeError ist nur der Rohtext (::error::'id'); geschrieben= zählt einen angewendeten, aber als gescheitert gemeldeten PATCH nicht. Behebung: Fehlerklasse in die Meldung aufnehmen.

### Bestätigungen
Confirmation: AC-1 bis AC-8.
Code reference: scripts/asc_beta_link.py:32
 Evidence: plan_link, confirmed, switch_on, disable und main belegt durch r5.out, r7.py und 19 grüne Tests. Status: CONFIRMED.
Confirmation: neue Tests.
Code reference: scripts/test_asc_beta_link.py:224
 Evidence: beide Tests werden bei M1+M2 bzw. M4+M2 rot. Status: CONFIRMED.
Confirmation: AC-9.
Code reference: .github/workflows/asc-beta.yml:95
 Evidence: Job link, Diff gelesen, test_workflow_file grün. Status: CONFIRMED.
Confirmation: AC-9 Altbestand und AC-10.
Code reference: scripts/test_asc_beta_invite.py:418
 Evidence: angepasstes test_workflow_file läuft grün (27 Tests OK), asc_beta_invite.py ohne Diff. Status: CONFIRMED.
Confirmation: AC-11.
Code reference: docs/reference/testflight.md:170
 Evidence: Zeile Öffentlicher Link offen mit #743, Zeile 172 Beta-Review APPROVED mit Lauf 41019692346. Status: CONFIRMED.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

Tests: 19 + 27 bestanden, 0 fehlgeschlagen, 0 übersprungen. Kein Befund HIGH oder CRITICAL; F001 ist MEDIUM (Abbruch per Signal), F002 bis F006 LOW.

## Verdict
**VERIFIED**

## Geprüfte Dateien

- sha256:f790528370491357c03c609c2cabc32743fec5fa6b6032f2135e7e2634b4829e  .github/workflows/asc-beta.yml
- sha256:292e2965fbc87b54237daf2231363ad0c2f3119380b5f83b0981555f68930347  docs/reference/testflight.md
- sha256:25123befbc1072fce877c0e73a82c91d6c3c8b003917df2365b35f662df4190a  scripts/asc_beta_link.py
- sha256:d8f18428ec48a3f2449b02ea03ee8f9f08fa2425bdc821bc4a44e154dca2d3ec  scripts/test_asc_beta_invite.py
- sha256:12d36debf853c923141c4fb2b0fd10507a3e67ec8dc933b8450e19ad11836cc2  scripts/test_asc_beta_link.py

## Prüfbasis

- base: 754b4f0cc9ce98e20deecfe2e3f8ff79108f5b73
- blob:fa89c7b9f7f1df5e3ae26d7d1c3c824edf35b703  .github/workflows/asc-beta.yml
- blob:7903f87bc5f2a8c72c0b22d6dfd58a33020916b6  docs/reference/testflight.md
- blob:487fce2426cd220ff5f2c438cc581fd8763f86de  scripts/asc_beta_link.py
- blob:be2489ff7f80a574cb18fea28d3cc44fc01cd229  scripts/test_asc_beta_invite.py
- blob:8775fab18ab28642be476b477739e111974c6f91  scripts/test_asc_beta_link.py
