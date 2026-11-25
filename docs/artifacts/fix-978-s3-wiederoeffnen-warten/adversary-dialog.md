# Adversary Dialog — fix-978-s3-wiederoeffnen-warten
Spec: docs/specs/fix-978-s3-wiederoeffnen-warten.md
Datum: 2026-11-24 22:51

## Checkliste
- [x] **AC-1:** Given `assertSymbolOpensPanelWithOneClick` / When der Diff geprüft wird / Then läuft der Klick im Return- und im ⌘W-Arm über eine `XCUICoordinate` mit Wurzel `XCUIApplication(bundleIdentifier: <vorderste App>).menuBars.element(boundBy: 0)`, nur bei nicht leerem Rahmen mit Ursprung y = 0, mit Offset gleich Mitte von `statusItem.frame` minus Ursprung der Menüleiste. Belegt durch Diff und `scripts/test_mac_reopen_settle.py`.
- [x] **AC-2:** Given der Anhang `mac-gallery-<label>-click` / When er geschrieben wird / Then nennt `how:` genau einen der Texte `user: frontmost menu bar <bundle id>`, `user: statusItem.click() fallback (frontmost com.henning.looseends)` oder `user: statusItem.click() fallback (frontmost <id>, no menu bar frame)`, eine Zeile nennt die Klickdauer in Sekunden, und die letzte Zeile bleibt `after: … s, panel open|not open`. Belegt durch Diff, Skript-Test und einen geöffneten Anhang.
- [x] **AC-3:** Given der ⌘W-Arm `testMenuBarReopensAfterOpenAppWithOneClick` / When der Diff geprüft wird / Then enthält er weder `XCTExpectFailure` noch `continueAfterFailure = true`, die Haltezeit von 3 s bleibt, und bei fremder vorderster App mit Rückfall ist der Test rot mit `how` in der Meldung; ist Loose Ends vorn, ist der Rückfall zulässig. Belegt durch `grep`, `TestOpenAppArmIsHard` und `scripts/test_mac_reopen_settle.py`.
- [x] **AC-4:** Given der Kontrollarm `testMenuBarReopensAfterReturnWithControlClick` und `LooseEnds/Mac/MenuBarCapture.swift` / When der Diff geprüft wird / Then sind beide unverändert (Kontrollarm weiter mit `LE_PANEL_CONTROL_ARM` und `XCTSkip` geschützt, App-Code 0 LoC). Belegt durch `git diff --stat`.
- [x] **AC-5:** Given Anhänge mit den drei neuen `how`-Texten / When `scripts/mac_panel_repeat_summary.py` sie liest / Then ergeben sie die Kategorien `menubar-root`, `fallback-looseends`, `fallback-noframe` (nicht `unbekannt` oder `statusitem`), und als Beleg zählt nur `menubar-root`. Belegt durch `scripts/test_mac_panel_repeat_summary.py`.
- [ ] **AC-6:** Given der Probelauf `mac-panel-repeat.yml` mit 1–2 Iterationen ohne Kontrollarm / When er endet / Then ist im ⌘W-Arm `how` = `frontmost menu bar <id>`, die Klickdauer < 1 s, im Klickprotokoll des xcresult steht kein „Activate com.henning.looseends“ und im Panel-Protokoll liegt `key` → Maus hoch unter 0,3 s; sonst gilt A′ als widerlegt, Rückfallplan D, Workflow zurück in die Analyse. Belegt durch die Artefakte, geöffnet und beschrieben.
- [ ] **AC-7:** Given Wiederholungsläufe `mac-panel-repeat.yml` auf dem PR-Zweig mit zusammen mindestens 100 Iterationen je Arm (Teilläufe erlaubt) / When sie enden / Then gibt es 0 Fälle in beiden Nutzerarmen, und jeder gezählte Klick im ⌘W-Arm ist `menubar-root` (Rückfälle werden benannt und getrennt ausgewiesen). Belegt durch `MacPanelRepeatSummary`, geöffnet und beschrieben.
- [ ] **AC-8:** Given der Pflicht-Check „Mac Gallery (macOS)“ / When er auf dem Stand dreimal läuft / Then ist er jedes Mal beim ersten Versuch grün, und je Bündel sind `how` und Klickdauer abgelesen; ein Abbruch durch das Zeitlimit #974 zählt nicht und wird neu gestartet. Belegt durch drei Läufe, Ergebnisbündel geöffnet.

## Dialog

### Runde 1
**Adversary:** Diff gelesen (LooseEndsUITests/MacGalleryTests.swift, scripts/mac_panel_repeat_summary.py), Skripttests und Typprüfung gelaufen (Ausgabe: docs/artifacts/fix-978-s3-wiederoeffnen-warten/adversary-test-output.txt). Angriffspunkte: (a) `bar.exists ? bar.frame : .zero` – Swift-Semantik; (b) ob die Rückfall-Regel den Kontrollarm ausnimmt; (c) ob jeder how-Text genau einer Kategorie zugeordnet wird; (d) nil/none; (e) AC-4.

Confirmation:
  AC: AC-1
  Code reference: LooseEndsUITests/MacGalleryTests.swift:560
  Evidence: Wurzel `XCUIApplication(bundleIdentifier: id).menuBars.element(boundBy: 0)`, Rahmen nur bei `bar.exists` gelesen (Zugriff auf `.frame` eines nicht existenten Elements wird so vermieden; ternärer Ausdruck typt als CGRect, `.zero.isEmpty` ist true, Typprüfung mit swiftc -typecheck -swift-version 6 ohne Fehler), Rückfall bei leerem Rahmen oder `minY != 0`, Offset = `statusItem.frame.mid - barFrame.min`, `bar.coordinate(withNormalizedOffset: .zero).withOffset(offset).click()`, genau ein Klick. test_mac_reopen_settle.py grün (20 Tests).
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: LooseEndsUITests/MacGalleryTests.swift:600
  Evidence: Die drei how-Texte stehen im Helfer (Zeilen 560-583), Anhang enthält `how:`, `click duration: … s` und als letzte Zeile `after: … s, panel open|not open`. Vierte Variante `(frontmost none, no menu bar frame)` ist Spezialfall von `<id>` = none und fällt in dieselbe Kategorie. Ein geöffneter Anhang aus einem echten Lauf liegt NICHT vor (nur CI).
  Status: CONFIRMED (Quelltext und Skripttest; Anhang-Teil des Belegs offen bis CI)

Confirmation:
  AC: AC-3
  Code reference: LooseEndsUITests/MacGalleryTests.swift:619
  Evidence: `if click == nil, frontmost != "com.henning.looseends", how.contains("fallback") { XCTFail(... how ...) }`; `grep XCTExpectFailure|continueAfterFailure` in der Datei liefert nur Zeile 17 (`continueAfterFailure = false`), kein XCTExpectFailure; Haltezeit 3 s (Zeile ~604) bleibt; TestOpenAppArmIsHard grün (test_menubar_panel_log.py, 12 Tests).
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: LooseEndsUITests/MacGalleryTests.swift:486
  Evidence: `git diff origin/main HEAD --stat -- LooseEnds/Mac/MenuBarCapture.swift` und `git diff origin/main --stat` (Arbeitsbaum) leer. Kontrollarm unverändert gegenüber origin/main (kein Treffer für ControlClick/LE_PANEL/XCTSkip im Diff), weiter mit `LE_PANEL_CONTROL_ARM` und `XCTSkip` geschützt. Er übergibt `click: Self.coordinateClick`, daher greift die harte Rückfall-Regel (`click == nil`) nicht für ihn: Kontrollarm ausgenommen.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: scripts/mac_panel_repeat_summary.py:29
  Evidence: Alle drei Texte (mit Präfix `how: user: `) liefern per `how_of` menubar-root / fallback-looseends / fallback-noframe; Reihenfolge in `_HOW` ist eindeutig, weil der Looseends-Fallback-Text `fallback (frontmost com.henning.looseends)` die Klammer sofort schließt und damit nie `no menu bar frame` enthält. test_mac_panel_repeat_summary.py grün (31 Tests). Bericht weist die Kategorien in fester Reihenfolge aus (Zeile 174-178).
  Status: CONFIRMED

Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: scripts/mac_panel_repeat_summary.py:29
  Description: `how_of` ist reiner Substring-Abgleich. Ein hypothetischer Text `fallback (frontmost com.henning.looseends, no menu bar frame)` (im Code nicht erzeugbar, da Loose Ends vorn vorher abzweigt) würde als fallback-noframe gezählt, `frontmost menu bar <id>` hat Vorrang vor allem. Keine Fehlzuordnung im tatsächlich erzeugten Textraum gefunden.
  Spec requirement: AC-5 — jeder Text genau eine Kategorie
  Conflict: nur theoretisch
  Remediation: keine nötig.

**Implementierer:** (nicht beteiligt; Kontext-Isolation)

### Runde 2
**Adversary:** Zweiter Angriff auf Lücken, die grüne Skripttests nicht abdecken.

Finding:
  ID: F002
  Severity: MEDIUM
  Category: edge_case
  Code reference: LooseEndsUITests/MacGalleryTests.swift:566
  Description: Im ⌘W-Arm ruft der Test vor ⌘W `app.activate()` auf. Ist Loose Ends danach (als .accessory-App ohne Fenster) weiter die vorderste App, nimmt `frontmostRootClick` den Zweig `id == "com.henning.looseends"` und klickt per `statusItem.click()`. Das ist laut Spec zulässig und die harte Rückfall-Regel (Zeile 619) greift dort nicht. Der Test kann also grün werden, ohne den neuen Weg je zu gehen (dieselbe Falle wie v2). Der Schutz liegt nur im Auswerteskript (fallback-looseends getrennt) und in AC-6/AC-7, die den Anteil menubar-root prüfen müssen.
  Spec requirement: AC-6/AC-7 — jeder gezählte ⌘W-Klick ist menubar-root
  Conflict: Der Pflicht-Check (AC-8) bleibt in diesem Fall grün ohne Mechanismusnachweis.
  Remediation: Kein Codeänderungsbedarf laut Spec; im Probelauf (AC-6) den how-Text zuerst ablesen. Ist er fallback-looseends, A′ ist nicht geprüft, nicht „bestanden“.

Finding:
  ID: F003
  Severity: LOW
  Category: anti_pattern
  Code reference: LooseEndsUITests/MacGalleryTests.swift:466
  Description: Docstring von `testMenuBarReopensAfterOpenAppWithOneClick` spricht noch von „v2: Klick über die vorderste App als Koordinatenwurzel“; Implementierung ist v3 (Menüleiste).
  Spec requirement: keine
  Conflict: irreführender Kommentar
  Remediation: Kommentar auf v3 anpassen.

Finding:
  ID: F004
  Severity: LOW
  Category: edge_case
  Code reference: LooseEndsUITests/MacGalleryTests.swift:619
  Description: frontmost nil oder „none“ (ungleich Loose Ends) führt ebenfalls zum harten XCTFail. Strenger als die Spec („fremde vorderste App“), aber im Sinn der Lehre aus v2; der how-Text `(frontmost none, no menu bar frame)` wird als fallback-noframe gezählt, nicht als eigene Kategorie.
  Spec requirement: AC-3
  Conflict: leichte Überstrenge, kein Fehler.
  Remediation: Absicht in der Spec festhalten (optional).

Offene ACs ohne mögliche Prüfung hier (nur CI auf gepushtem Stand), nicht abgehakt und nichts erfunden:
- AC-6 (Probelauf: how, Klickdauer < 1 s, kein „Activate“, key → Maus hoch < 0,3 s): offen.
- AC-7 (>= 100 Iterationen je Arm, 0 Fälle, alle ⌘W-Klicks menubar-root): offen.
- AC-8 (dreimal Pflicht-Check grün beim ersten Versuch): offen.
Ob die Menüleiste der Finder-App wirklich einen Rahmen mit minY = 0 liefert und `click()` auf der Koordinate nichts aktiviert, ist ohne CI unbelegt (Known Limitation der Spec).

**Implementierer:** (nicht beteiligt)

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: AMBIGUOUS

AC-1 bis AC-5 bewiesen (Diff, Skripttests 20+31+12 grün, Typprüfung ohne Fehler, MenuBarCapture.swift und Kontrollarm unverändert). AC-6 bis AC-8 sind nur durch CI-Läufe auf gepushtem Stand belegbar und stehen offen. F002 (Rückfall bei Loose Ends vorn im ⌘W-Arm kann den neuen Weg unbemerkt umgehen) ist das wichtigste Risiko für die Beweiskraft.
Tests: 63 bestanden, 0 fehlgeschlagen, 0 übersprungen (drei Skriptdateien; volle Suite nicht gelaufen)

## Geprüfte Dateien

- sha256:af34e3061a9543028fc9de2d1e614681c9a3ab633c59f79b1c2ff6e482fbdf99  LooseEndsUITests/MacGalleryTests.swift
- sha256:091d33ddba7cb0598d00491369cb32bfd645ad3700faf6abe7d1009fdf2ff0ac  scripts/mac_panel_repeat_summary.py

## Prüfbasis

- base: c885f7a0f78b21b748aac358f34d91923c0c02ba
- blob:5cfb2f7b09196f764a110f752447a4959037260c  LooseEndsUITests/MacGalleryTests.swift
- blob:d820821220b5351726ca437c7916081e0aceab0b  scripts/mac_panel_repeat_summary.py
