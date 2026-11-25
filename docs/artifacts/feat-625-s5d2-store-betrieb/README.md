# Belege #625 S5d-2 (Store-Betrieb 1.0.2)

Spec: `docs/specs/feat-625-schnitt-5d-2-store-betrieb.md`.

## RED (Phase 5, 2026-11-24, 17:58–18:00 Uhr MEZ)

- `test_belege.py` prüft das Belegformat (AC-10, AC-11, AC-12, AC-13 Diffliste). Aufruf aus dem Repo-Wurzelordner:
  `python3 -m unittest docs/artifacts/feat-625-s5d2-store-betrieb/test_belege.py -v`.
  RED-Ausgabe: `test-red-output.txt` (7 von 10 rot: Belege ac01–ac10 fehlen, Betriebsnotiz fehlt; grün bleiben die
  Wächter kein DELETE/doppelter POST, keine Geheimnisse, Diffliste ohne App-Code).
- Ausgangszustand bei Apple (nur GET): `red-store-version-lesen.txt` (iOS und Mac nur 1.0 und 1.0.1 `READY_FOR_SALE`,
  keine 1.0.2) und `red-store-submit-pruefen.txt` (`nicht bereit: ios,mac`, Ausgang 1). Das ist der Schalter für AC-2 und AC-9.

## Belegformat (für Phase 6)

Je Schritt genau eine Datei `acNN-<kurzname>.md` (NN = 01 … 10) mit einer Zeile `Zeit: <ISO-8601 mit Zone>`.
Schreibende Schritte (AC-2, 3, 4, 6, 7, 8) enthalten die Abschnitte „lesen vorher“ und „Gegenprobe“.
`ac10-*.md` hat genau eine Zeile `Zustand: a` (mit `Wort: …` und `WAITING_FOR_REVIEW`) oder `Zustand: b` (mit `bereit`).
Laufausgaben ohne Skript-Echo ablegen (nur die Zeilen des Skripts), nie Token, Schlüssel oder Konto-Kennungen.

## Hinweis Werkzeug-Tests (AC-13)

`python3 -m unittest discover -s scripts -p 'test_*.py'` dauert lange (allein `test_asc_store_submit.py` > 90 s);
im Hintergrund mit großem Zeitlimit laufen lassen. Einzeln geprüft am 2026-11-24 grün: `test_asc_store_version`,
`test_asc_version_texts`, `test_asc_store_images`, `test_asc_review_notes`, `test_asc_store_submit` (per discover).

## Stand Phase 6 (2026-11-24, 22:15 Uhr MEZ)

Belegt: AC-1 bis AC-9 (`ac01` … `ac09`; Etikett app-weit veröffentlicht, Anhang an iOS und Mac, Tür offen seit
22:08 Uhr MEZ, Notizen gesetzt, Vorprüfung `bereit` für iOS und Mac). Offen: AC-10, Einreichen nur nach Hennings
getipptem Wort (Zustand a), sonst Zustand b. Ein Commit ist bis zum Adversary-Verdict gesperrt (`bash_gate`); die Belege
liegen ungesichert im Arbeitsbaum dieses Worktrees.
