# Stand #862, Phase 6b (Adversary), 2026-11-21 09:46

Übergabe für die nächste Sitzung (`/50-implement #862`, danach Step 8 fortsetzen).

## Erledigt
- Fix committet und gepusht: bb05d4d auf `fix/862-menubar-panel` (PR #970), App-Code `LooseEnds/Mac/MenuBarCapture.swift`
  (`dismiss()` statt `closeMenuBarPanel`), Test-Hilfe `LooseEndsUITests/MacUITestSupport.swift` (kein Zweitklick).
- GREEN freigegeben (auto-green), Artefakt `test-green-output.txt` registriert.
- CI-Lauf 44877016605 (Versuch 1) komplett grün; Mac Gallery Job 136763847707 grün, beide neuen Tests grün
  (`adversary-test-output.txt`, Klick-Anhänge `ci-44877016605-reopen-*-click.txt`, Zeitachse `ci-44877016605-reopen-return-timeline.txt`).
- Adversary Runde 1 im Protokoll `adversary-dialog.md`: AC-1…AC-5, AC-7 belegt, AC-6 offen (erst 1 von 3 Läufen).
  F001 (6,6 s bis Panel) im Implementierer-Teil von Runde 1 beantwortet: Werkzeug-Wartezeit nach Klick, gleich lang wie
  beim ersten Öffnen; Panel beim ersten Abfragen da.

## Nachtrag 10:31
- Versuch 2 (Job 136792484526): Galerie 18/18 grün, Klicktests 11/11 grün, Tastatur-Stufe nach 40 min Jobzeit von
  GitHub abgebrochen („The operation was canceled.“, 10,9 min in der Stufe; auf main 9,1–10,3 min, Job 31–36 min von 40).
  Kein Testfehler, Zeitlimit des Jobs. Eigenes Issue #974 (P0, Backlog); zählt nicht als grüner Lauf für AC-6, im
  Protokoll Runde 2 offen benennen.
- Versuch 3 (Job 136803368648) läuft seit 10:31. Danach Versuch 4.

## Nachtrag 11:20 — Versuch 3 ROT, AC-2-Weg wackelt (Defekt, BROKEN)
- Versuch 3 (Job 136803368648, 09:34–10:08Z): `testMenuBarReopensAfterOpenAppWithOneClick` rot, „One click on the symbol
  opened no panel (reopen-open-app)“, 15,68 s nach dem Klick kein Panel. Alle anderen 17 Galerie-Tests, 11 Klick- und
  18 Tastatur-Tests grün. Artefakt MacGalleryResults 14702453698 (Versuch 3), Versuch 1 = 14697298506.
- Belege hier: `ci-44877016605-a3-reopen-open-app-timeline.txt` (Zeitachse), `…-a3-…-click.txt` (Hierarchie: kein Dialog,
  nur MenuBar + StatusItem), `…-a3-…-video-1s.png` (Bilder je Sekunde), `…-a3-…-video-click.png` (5 Bilder/s, letzte 2 s).
- Befund Video: nach ⌘W ist Finder vorn, Hauptfenster weg. Klick aufs Symbol ab 375,45 (Synthesize), Symbol gedrückt
  ~1 s, **Panel erscheint bei ~376,3** (Finder bleibt vorn). Video endet bei 376,8. Ab 381,97 meldet XCUITest kein
  `menuBarOpenApp` mehr, Hierarchie ohne Dialog → das Panel öffnet und **schließt sich innerhalb von ≤ 5 s wieder**.
- Vergleich grüner Versuch 1, gleicher Test: identische Schrittfolge, auch dort „Check for interrupting elements“ →
  `Activate com.henning.looseends` unmittelbar vor dem Synthesize (182,50/182,51), Panel dort beim ersten Abfragen da.
  Unterschied also Timing, nicht die Schrittfolge.
- Hypothesen für die Analyse (noch nicht belegt): (a) XCUITests Activate (asynchron) kommt nach dem Öffnen an; Wechsel
  Finder → Loose Ends lässt das MenuBarExtra-Fenster schließen (Fokuswechsel = Schließen). (b) `applyDockPolicy` aus dem
  `willClose`-Beobachter des ⌘W-Fensters (async) wechselt `.regular → .accessory` erst nach dem Öffnen und schließt das
  Panel. (c) Das `dismiss()` vor `showMain` hinterlässt eine Sitzung, die erst später endet. Prüfweg: App-Log (`Logger`)
  mit Zeitstempeln für Policy-Wechsel und Panel-Fenster `didBecomeKey/willClose` in der CI, oder Test mit Wartezeit
  zwischen ⌘W und Klick als Gegenprobe (b).
- Folge: Workflow zurück nach phase6_implement (BROKEN), Ursache klären, Fix, dann wieder drei grüne Läufe (AC-6).

## Offen
1. Ursache des Wackelns im AC-2-Weg klären (siehe Nachtrag 11:20), Fix, neuer Dialog.
2. AC-6: danach drei grüne Mac-Galerie-Läufe. Job-ID je Versuch:
   `gh api repos/henemm/loose-ends/actions/runs/44877016605/attempts/<n>/jobs` (Name „Mac Gallery (macOS)“).
   Je Versuch: Testzeilen der Mac-Klassen prüfen (kein ✘/##[error]), Klickdauer der beiden neuen Tests aus dem
   Artefakt `MacGalleryResults` (xcresulttool export attachments) notieren.
2. Adversary Runde 2 (implementation-validator) mit den drei Laufnummern und den Nachfragen aus Runde 1; Verdict.
3. `add-artifact adversary_dialog`, `adversary_dialog.py stamp`, `qa_gate.py … --checklist … --infra --no-visual
   "Mac-UI nur in der CI, Belege als Anhänge"`, dann `workflow.py phase phase7_validate`.
4. Uncommittete Belegdateien in diesem Ordner (Commit erst nach VERIFIED möglich, Gate).

Hinweis: Commit nach `origin/main`-Vorsprung nur per Merge von `origin/main` (kein Rebase + Force-Push, wurde abgelehnt).

## Nachtrag 2026-11-21 (Sitzung nach /clear) — Nachstellung mit Zeitstempeln
- Recherche: Apple-Foren 836113 (NSStatusItem auf macOS 27, kein Mechanismus für Klick außerhalb, Schließen hängt am
  Key-Status) und 836619 (strengeres Aktivierungsmodell seit macOS 27, `setActivationPolicy`-Wechsel schiebt Fenster nach
  hinten). Keine Quelle zu genau diesem Symptom.
- Wegwerfzweig `diag/862-panel-schliesst` (nie mergen): Logger-Zeilen `#862 …` (Kategorie `Mac862`) für Key/Close/Aktiv/
  Richtlinie, drei Diagnose-Tests mit 8-s-Beobachtung (ohne Pause, mit 3 s Pause nach ⌘W, Return-Weg), eigener Workflow
  `diag-862.yml` mit `-test-iterations 8`, `ci.yml` dort gelöscht. Draft-PR nur für den Lauf, danach schließen.
- Ziel: Hypothese (a) XCUITest-Aktivierung vs. (b) verspätete Richtlinienumschaltung durch `applyDockPolicy` aus dem
  didBecomeKey des Panels vs. (c) anderes mit Daten trennen.
- Draft-PR #975, Lauf 44894098322 (Diag 862), gestartet 11:23. Diagnose-Agent umging beim Schreiben einmal unwissentlich das Edit-Gate (Skript); Zweig ist Wegwerf, drei Swift-6-Warnungen dort bleiben stehen.

## Nachtrag — Diagnoselauf 44894298887 (24/24 grün, Fehler nicht ausgelöst)
- Alle drei Varianten je 8-mal grün; Panel in jeder 8-s-Beobachtung durchgehend offen.
- App-Log (Kategorie Mac862) widerlegt (b): Die Richtlinie springt beim ⌘W sofort auf `.accessory` (≈0,15 s nach
  willClose), lange vor dem Klick; nach dem Öffnen des Panels kein Wechsel mehr. (c) ohne Spur.
- Muster bei jedem Symbolklick: XCUITest aktiviert Loose Ends („Check for interrupting elements → Activate“), dann beim
  Klick aktiviert macOS **Finder**, Loose Ends `didResignActive`, erst ~30 ms danach wird das Panel Key. Das Panel lebt
  also ohne aktive App. Kippt die Reihenfolge (Aktivierungswechsel NACH dem Öffnen), liegt nahe, dass es sich wie bei
  einem Klick außerhalb schließt. Im roten Versuch 3 lagen Activate und Klick nur 20 ms auseinander.
- Nächster Schritt: Mechanismus erzwingen — nach offenem Panel aus dem Testprozess Loose Ends bzw. Finder per
  NSRunningApplication aktivieren und beobachten, ob das Panel schließt.

## Nachtrag — Diagnoselauf 44895791624 (12/12, Hypothese (a) widerlegt)
- Späte Aktivierung bei offenem Panel aus dem Testprozess (`NSRunningApplication.activate`): Finder ×4, Loose Ends ×4
  (nach ⌘W), Loose Ends ×4 (frischer Start). Das Panel blieb in allen 12 Fällen 8 s offen. Ein Aktivierungswechsel nach
  dem Öffnen schließt das Panel also NICHT.
- Damit widerlegt: (a) späte Aktivierung, (b) verspätete Richtlinie (Lauf 44894298887). Insgesamt 36 Diagnosedurchgänge,
  0 Fehler. Der rote Versuch 3 (1 von 3 vollen Galerie-Läufen) bleibt unerklärt und nicht nachgestellt.
- Unterschied Diagnose ↔ voller Galerie-Job: dort laufen vorher 16 andere Galerie-Tests (Last, viele App-Starts,
  Bildschirmaufnahme), hier nur die Diagnosetests. Nächste Kandidaten: (d) Test-Reihenfolge/Vorzustand im vollen Job,
  (e) Systemlast in der Runner-VM (Klick-Synthese 5,5 s).
- Nächster Schritt: Diagnosezweig mit vollem `-only-testing:LooseEndsUITests/MacGalleryTests`, `-test-iterations 3`
  plus Logger, um den Fehler im Originalumfeld auszulösen; App-Log liegt dann vor.
- Wegwerfzweig `diag/862-panel-schliesst` (Draft-PR #975), Stand 1454f6e, Worktree `agent-ae2e71207ddfc59d7`.

## Nachtrag 2026-11-21 (nächste Sitzung) — Fehler im Originalumfeld auslösen
- Diagnosezweig 451b68e (per API geschrieben): `diag-862.yml` läuft jetzt die volle `MacGalleryTests` ohne die sechs
  Diagnose-Tests, `-test-iterations 3`, Logger an, Jobgrenze 150 min. Lauf 44896798319.
- Parallel: Mac-Gallery-Job von Lauf 44877016605 als Versuch 4 neu gestartet (weitere Stichprobe der echten Konfiguration).
- Auswertung: rot? → App-Log `diag-app.log` (Kategorie Mac862) um den roten Test herum lesen. Alles grün → Flake-Rate
  sinkt, Entscheidung über Wiederholungsschutz bzw. Ursache (d)/(e) im Dialog.
- Ergebnis 12:39: Diagnoselauf 44896798319 volle Galerie ×3 = 54/54 grün (AC-2-Test 3× grün). Versuch 4 von
  44877016605 (Job 136824282177) ROT, wieder nur `testMenuBarReopensAfterOpenAppWithOneClick`, 15,77 s ohne Panel;
  Klick 1795259489.52, Synthese 489.58–495.16, erste Abfrage 496.17 schon ohne Panel. Video endet 491.0 (nutzlos).
  Stand echte Konfiguration: 2 von 4 Läufen rot (Versuche 3, 4), immer derselbe Test.
- Nächster Diagnoselauf 44900453906 (Zweig 433cb2f): Galerie ×8, App loggt bei jedem willClose/didResignKey außerhalb
  des Hauptfensters den Aufrufstapel (40 Rahmen) und `NSApp.currentEvent` → zeigt, WER das Panel schließt.
  Auswertung: Artefakt Diag862 → `diag-app.log`, Zeilen `#862 stack willClose` zur Zeit des roten Klicks.
- 13:0x PO fragte nach Verhältnismäßigkeit: Lauf ×8 abgebrochen, neu mit -test-iterations 4 (Zweig 766912f, Grenze 90 min). Bleibt er grün: Fehler nicht weiter jagen, sondern Abwägung (eigenes Issue, Fix ausliefern) im Dialog.
- 14:1x Diagnoselauf 44903008083 (×4 mit Stapel-Protokoll) 72/72 grün. Bilanz: Diagnosebau (mit Beobachtern/Logger)
  0 Fehler in 7 vollen Galerie-Durchläufen + 36 gezielten; echter Fix-Bau 2 von 4 rot. Bei 50 % wären 0/7 nur 0,8 %
  wahrscheinlich → Verdacht: die Diagnose-Beobachter verändern das Verhalten (oder das Umfeld des ci.yml-Jobs).
- Gegenprobe gestartet: Diagnosezweig 9ceb093 mit App-Code exakt wie bb05d4d (kein Logger), sonst gleich, ×4.
  Rot → Beobachter maskieren den Fehler (Spur: Benachrichtigungs-Beobachter/Timing). Grün → Unterschied liegt im Job-Umfeld.
- 15:2x Gegenprobe 44907370807 (App-Code = bb05d4d, ohne Logger, ×4): 72/72 grün. Logger maskiert also nicht.
  Bilanz AC-2-Test: Diagnose-Job 11/11 grün (davon 4 mit echtem Code), ci.yml-Galerie 2/4 rot (Versuch 3, 4; Versuch 4
  lief zeitgleich mit einem grünen Diagnoselauf). Ursache weiter unbekannt; Umfeld-Unterschied ci.yml ↔ diag-862.yml
  nicht greifbar (gleicher Befehl). Suche beendet (PO: Verhältnismäßigkeit). Entscheidung PO: ausliefern + Rest als
  eigenes Issue, oder weitersuchen.

## PO-Entscheidung 2026-11-21 ~15:30: „Jetzt ausliefern“
- Rest als #978 angelegt (Board: Backlog, P1, M), Befund und DoD dort.
- Nächste Schritte (nach /clear mit `/50-implement #862`):
  1. developer-agent: `testMenuBarReopensAfterOpenAppWithOneClick` beginnt mit
     `throw XCTSkip("#978: panel closes again now and then after Open Loose Ends + ⌘W; cause open")` (Test bleibt im Code).
  2. Spec `docs/specs/fix-862-menubar-panel.md`: nur Known Limitations + Changelog (ohne Rücksprung änderbar): AC-2 durch
     Lauf 44877016605 V1 belegt (rot→grün), seltenes Schließen (2 von 15 Läufen) → #978, Test bis dahin ausgesetzt (PO 2026-11-21).
  3. Commit + Push, dann drei grüne Läufe Mac Gallery (AC-6), Adversary Runde 2, stamp, qa_gate, phase7.
  4. Diagnosezweig `diag/862-panel-schliesst` + Draft-PR #975 erst nach #978 schließen (Werkzeug für #978) — im Issue vermerkt.
