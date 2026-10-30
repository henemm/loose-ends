# Adversary Dialog — fix-747-probe-link-maskieren
Spec: docs/specs/fast/fix-747-probe-link-maskieren.md
Datum: 2026-10-30 14:34

## Checkliste
- [x] Mit eingeschaltetem Link taucht die URL in stdout und stderr nirgends auf; `url=gesetzt` steht in der Gruppenzeile.
- [x] Mit ausgeschaltetem Link steht `url=-`.
- [x] Keine andere Zeile/kein anderes Feld geändert; Probe nur lesend (GET), Exit-Codes unverändert.
- [x] Kein anderer Druckweg für den Link (Fehlerzeilen, Exceptions, Traceback, Debug); Randfälle leer/Leerzeichen/Link aus mit Wert.

## Dialog

### Runde 1
**Adversary:** Diff gelesen: nur `url`-Zeile in report_groups geändert (Zeilen 103-106). Alle print-Stellen der Probe und von asc_wait_build.py durchsucht: Fehlerzeilen drucken nur Statuscode, Pfad (ohne Query) und Exception-Typname, nie Antwortkörper; Fatal-Meldungen enthalten keine Gruppenwerte. Betroffen sind nur die Gruppenattribute aus /betaGroups, und die gehen ausschließlich durch report_groups. Tests: 14 bestanden, 0 fehlgeschlagen (adversary-test-output.txt). Der Test prüft GROUP_LINK gegen stdout+stderr und `url=-` bei Link aus.
Code reference: scripts/asc_beta_probe.py:104
Code reference: scripts/test_asc_beta_probe.py:232
**Implementierer:** Link wird nur als `gesetzt`/`-` gedruckt; GET-only unverändert (Request ohne Daten, Zeile 27).

### Runde 2
**Adversary:** Gegenprobe mit Fake-Link direkt auf report_groups: Link an + Wert -> `url=gesetzt`; Link an + Leerzeichen / "" / None -> `url=-`; Link aus + Wert -> `url=-`; Wert als Liste oder Dict mit Link -> `url=gesetzt`, Link nie im Ausdruck (alle 7 Fälle: Link enthalten = False). Andere Felder der Zeile (name, intern, link=, feedback=) unverändert gegenüber Diff; Exit-Codes in main unberührt (Zeilen 176-181). Restrisiko: Der Gruppenname wird gedruckt; steht dort ein Link, wäre das ein anderes Thema, nicht Spec.
Code reference: scripts/asc_beta_probe.py:94
Code reference: scripts/test_asc_beta_probe.py:245
**Implementierer:** Keine Änderung nötig.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict
VERDICT: VERIFIED

## Geprüfte Dateien

- sha256:84480bb80de7b794480d3a1008bc4ea7d9bcb0613b5816a625910033c8135472  scripts/asc_beta_probe.py
- sha256:d9fc60067d4fc726c800c8d839560e5a22aa0ebccb526c46c789bf23364ec35d  scripts/test_asc_beta_probe.py

## Prüfbasis

- base: 556bb5badb6ce9bb1421dd9da5f55fbfee9e2c37
- blob:15c11a5a4836ff8139b8eb77bc84f6a2975f09ce  scripts/asc_beta_probe.py
- blob:5af4a3c736e0ad186f0a2d73182e3e80744398bb  scripts/test_asc_beta_probe.py
