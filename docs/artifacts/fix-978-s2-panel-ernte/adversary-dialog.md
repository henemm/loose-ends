# Adversary Dialog — fix-978-s2-panel-ernte
Spec: docs/specs/fix-978-s2-panel-ernte.md
Datum: 2026-11-24 06:32

## Checkliste
- [x] **AC-1:** Given `MenuBarCapture.swift` / When das Panelfenster Key wird, Key verliert oder verschwindet / Then schreibt die App immer eine Zeile der Kategorie `MenuBarPanel` mit Stapel bis 40 Rahmen ab dem ersten Rahmen außerhalb des Beobachters, CGEvent-Feldern des aktuellen Ereignisses (oder „nil“) und bei `key`/`resign` `NSApp.isActive` und `isKeyWindow`. Belegt durch Diff und `log show`-Zeilen im Artefakt `MacGalleryPanelLog` des PR-Laufs, geöffnet und beschrieben.
- [x] **AC-2:** Given `MenuBarCapture.swift` / When die App `didBecomeActive`, `didResignActive`, `didHide`, `didActivateApplication` oder einen Space-Wechsel erlebt und nach `key` 3 s vergangen sind / Then stehen dazu Zeilen im Protokoll (aktivierte App nur als Bundle-ID, Monitorzeilen mit Rohtyp, Fensternummer, Zeitstempel), und die Monitore sind nach 3 s entfernt. Belegt durch Diff und das Artefakt `MacGalleryPanelLog`.
- [x] **AC-3:** Given der Diff von `MenuBarCapture.swift` / When er geprüft wird / Then ändert er kein Verhalten (`applyDockPolicy`, `dismiss()`, `showMain` unberührt; der lokale Monitor gibt jedes Ereignis unverändert zurück), liest nie `subtype` oder `data1`, enthält kein `print`, kein `try?`, keinen Aufgabentext, Fenstertitel oder Token in den Zeilen, jede Funktion ≤ 50 LoC, App-Code ≤ 250 LoC. Belegt durch Diff-Prüfung und `git diff --stat`.
- [x] **AC-4:** Given `.github/workflows/mac-panel-repeat.yml` / When sie geprüft wird / Then ist der Workflow per `workflow_dispatch` auf beliebigem Ref startbar (Eingaben `iterationen`, `kontrollarm`, `sandbox`), fährt nur die beiden Wiederöffnungstests und den Kontrollarm mit `-test-iterations`, zählt alle Iterationen (nicht nur Fehlschläge) und lädt Panel-Protokoll, xcresult und Zusammenfassung hoch. Belegt durch Diff und den Lauf auf dem PR-Zweig.
- [x] **AC-5:** Given ein Lauf des Wiederholungsworkflows auf dem PR-Zweig / When er endet / Then enthalten die Artefakte `MacPanelRepeatLog`, `MacPanelRepeatResults` und `MacPanelRepeatSummary`, und die Zusammenfassung nennt je Arm (Return, Open-App, Kontrollarm) Nenner, Zähler und Rate. Belegt durch die Artefakte, geöffnet und beschrieben (null Fälle sind ein gültiges Ergebnis, die Zählung muss stehen).
- [x] **AC-6:** Given der Kontrollarm in `MacGalleryTests.swift` / When der Pflicht-Job „Mac Gallery (macOS)“ läuft / Then ist der Kontrollarm als übersprungen ausgewiesen, die beiden Wiederöffnungstests klicken weiter mit `statusItem.click()` wie ein Nutzer, und der Job ist beim ersten Versuch grün. Belegt durch Diff und das Ergebnisbündel des PR-Laufs.
- [x] **AC-7:** Given `scripts/test_mac_panel_repeat_summary.py` / When es läuft / Then ist es grün und prüft Nenner, Zähler, Rate und Zeitachse mit festen Eingaben. Belegt durch den Lauf (lokal und in der CI).
- [x] **AC-8:** Given der Diff / When er geprüft wird / Then berührt er nur die fünf genannten Dateien, kein Eintrag in `project.yml`, `Info.plist` oder Entitlements; Unit-Tests und iOS-Bau sind grün. Belegt durch `git diff --stat` und die Läufe.

## Dialog

### Runde 1
**Adversary:** Ausgangslage: Vorrunde endete AMBIGUOUS (F102, Stapelanfang nicht am echten CI-Lauf). Der Lauf auf 6c26a51 (`panel-log-6c26a51-45249742660.log`, 51 Zeilen mit `stack=`) zeigte den Defekt: jede Zeile begann mit Thunks `...TR`/`...TRTA`, zwei `assumeIsolated`-Rahmen und dem `MacAppDelegate`-Rahmen. Behauptet wird: `afterObserver` (MenuBarCapture.swift:142) behebt das. Eigene Prüfung:
1. `python3 scripts/test_mac_panel_repeat_summary.py` selbst gelaufen: 29 Tests, OK, rc=0, Ausgabe in `adversary-test-output.txt` (kein Test übersprungen, swiftc vorhanden, daher läuft `test_after_observer_behaviour` wirklich).
2. Den echten Rumpf per swiftc gebaut (Skript im Scratchpad, Rumpf per Regex aus der Quelle gezogen, nicht aus dem Test) und an allen 51 `stack=`-Zeilen des CI-Protokolls ausgeführt, je einmal gekürzt (wie im Protokoll) und ungekürzt (zwei eigene `MenuBarPanelLog`-Rahmen `callers`/`record` davor). Ergebnis: 51 von 51 identisch (0 Abweichungen); jedes Ergebnis beginnt mit `$s10Foundation12NotificationVIeghn_So14NSNotificationCIeyBhy_TR + 184` (der Rahmen nach dem letzten Beobachterrahmen), danach `__CFNOTIFICATIONCENTER_IS_CALLING_OUT_TO_AN_OBSERVER__` und das AppKit-Ereignis (`-[NSWindow ...]`); 31 bis 35 Rahmen bleiben, also ist die 40er-Grenze nicht der Engpass.
3. Randfälle: kein Beobachter `[a,b]` gibt `[a,b]` (ganzer Stapel bleibt); nur Beobachter gibt `[]`; Thunk ohne `$s` zwischen Beobachter und Rest (`sxTR`) ist kein Klebstoff, wird aber hinter dem letzten Beobachterrahmen ohnehin ausgegeben; tieferer `MacAppDelegate`-Rahmen nach Nicht-Klebstoff `t` bleibt erhalten (`[$sFooTR, t, MacAppDelegate q, u]`); `-[Foo DATA] + 4` ist kein Klebstoff (verlangt Präfix `$s`); Rahmen vor dem ersten Beobachter (`pre1`, Thunk) fallen weg, Ergebnis `[z]`; Klebstoff zwischen zwei Beobachterrahmen fällt mit weg (Test „glue“ `[x]`).
4. Gegenprobe auf Angriff: ein Swift-Symbol, das zufällig auf „TA“ endet (`$s3Foo4DATA`), würde als Klebstoff gelten, aber nur, wenn es zwischen zwei Beobachterrahmen steht; hinter dem letzten Beobachterrahmen wird es ausgegeben. Folge allenfalls ein zu früh abgeschnittener Anfang in einem unwahrscheinlichen Fall, kein Datenverlust (F104, LOW).
**Implementierer:** `afterObserver` läuft vom ersten Beobachterrahmen über Beobachter- und Klebstoffrahmen, gibt den Rest nach dem letzten Beobachterrahmen zurück (MenuBarCapture.swift:142-155); Aufrufer `callers()` (:132-135) kürzt auf 40. Tests „real“ und „glue“ ergänzt (test_mac_panel_repeat_summary.py:282-340).

### Runde 2
**Adversary:** Zweiter Angriff auf die übrigen ACs und Regression gegen den Gesamtdiff.
- AC-3: `git diff fa3d5076 -- LooseEnds/` ist eine Datei (MenuBarCapture.swift, +128/-11). Suche nach `print(`, `try?`, `subtype`, `data1` in hinzugefügten Zeilen: nur zwei Doc-Kommentar-Treffer (:9 und :10 des Diffs, die „never subtype/data1“ sagen), kein Code. Entfernt wurden nur der alte Logger, die alte `record`-Signatur und die zwei Aufrufer; `applyDockPolicy` kommt nur als unveränderter Kontext vor, `dismiss()` und `showMain` stehen nicht im Diff. Lokaler Monitor (:206-209) gibt `event` unverändert zurück. Zeilen enthalten nur Fensterklasse, Rohtypen, Bundle-ID, Zahlen, nie Titel oder Aufgabentext. Längste neue Funktionen: `observeActivation` etwa 25, `startMonitors` etwa 20, `afterObserver` etwa 16 Zeilen (alle ≤ 50). App-Code 128 eingefügte Zeilen ≤ 250. Verhaltenswechsel durch den Arbeitsstand-Diff (nur `afterObserver`, `callers`): nein, es ändert nur die Zeichenkette der Protokollzeile.
- AC-8: `git diff fa3d5076 --stat` ohne `docs/`: genau die fünf Dateien (Workflow, MenuBarCapture, MacGalleryTests, zwei Skripte); kein `project.yml`, Info.plist oder Entitlements.
- AC-1/AC-2 am CI-Protokoll 6c26a51: 51 `panel key/resign/hide/close`-Zeilen, jede mit `cg=` und `stack=`; `key` und `resign` mit `active=` und `keyWindow=`; 19 Zeilen `monitor end` (Monitore nach 3 s entfernt), `app become-active` und `monitor local`-Zeilen vorhanden.
- AC-4/AC-6: Workflow `workflow_dispatch` mit `iterationen`, `kontrollarm`, `sandbox` (mac-panel-repeat.yml:8-19), `-test-iterations "$ITERATIONS"` (:91). Kontrollarm überspringt per `XCTSkip` ohne `LE_PANEL_CONTROL_ARM` (MacGalleryTests.swift:491), Wiederöffnungstests klicken mit `statusItem.click()` (:537).
- AC-5: Stichprobe `repeat-summary-pr-lauf-45215511542.md` geöffnet: Arme return, open-app, control je Nenner 20, Zähler 0, Rate 0,0 %, Klickweg statusitem 20 / statusitem 20 / xcuicoordinate 20, Soll-Nenner 20 ohne Abweichung; null Fälle ist ein gültiges Ergebnis.
- AC-7: 29 Tests grün (Runde 1).
- Restrisiko: Für den neuen Stand (`afterObserver` mit Klebstoff) gibt es noch keinen CI-Lauf (Commit erst nach diesem Verdict). Der Nachweis läuft aber am echten Quelltextrumpf gegen alle 51 echten CI-Stapel, die Eingabe ist also nicht erfunden. Was die Laufzeit abweichen lassen könnte: Rahmen anderer Namensform bei anderer Compiler- oder OS-Version. Dann fiele der Beobachterblock kürzer aus, der Rest bliebe sichtbar (Fehlerrichtung: etwas zu viel statt zu wenig).
**Implementierer:** keine weiteren Änderungen nötig.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Bestätigungen

Confirmation:
  AC: AC-1
  Code reference: LooseEnds/Mac/MenuBarCapture.swift:142
  Evidence: afterObserver gibt den Stapel ab dem ersten Rahmen nach dem Beobachterblock zurück, callers() kürzt auf 40 (:134); record schreibt cg, active, keyWindow (:118-122). Offline gegen alle 51 echten CI-Stapel: Anfang ist stets der Foundation-Notification-Rahmen, kurze und ungekürzte Form identisch.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: LooseEnds/Mac/MenuBarCapture.swift:213
  Evidence: Lokaler und globaler Monitor schreiben nur, nach 3 s stopMonitors und „monitor end“ (:218-224); activation/space/hide-Beobachter in observeActivation. CI-Protokoll: 19 „monitor end“, app-Zeilen vorhanden.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: LooseEnds/Mac/MenuBarCapture.swift:206
  Evidence: Monitor gibt event unverändert zurück; kein print, try?, subtype, data1 im Code; Funktionen ≤ 50 LoC; 128 App-Zeilen; ein Datei im Verzeichnis LooseEnds.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: .github/workflows/mac-panel-repeat.yml:8
  Evidence: workflow_dispatch mit iterationen, kontrollarm, sandbox; -test-iterations in Zeile 91.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: scripts/mac_panel_repeat_summary.py:39
  Evidence: Auswertung je Arm mit Nenner, Zähler, Rate; Beleg repeat-summary-pr-lauf-45215511542.md geöffnet: 20/0/0,0 % je Arm.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: LooseEndsUITests/MacGalleryTests.swift:491
  Evidence: Kontrollarm per XCTSkip ohne LE_PANEL_CONTROL_ARM; Wiederöffnungstests nutzen statusItem.click() (:537).
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: scripts/test_mac_panel_repeat_summary.py:262
  Evidence: 29 Tests grün, inklusive swiftc-Lauf des echten afterObserver-Rumpfs (real, glue, ci, none, deeper, empty); Ausgabe adversary-test-output.txt.
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: scripts/test_mac_panel_repeat_summary.py:282
  Evidence: git diff --stat: außer docs/ genau fünf Dateien, kein project.yml, Info.plist, Entitlements.
  Status: CONFIRMED

## Findings

Finding:
  ID: F104
  Severity: LOW
  Category: edge_case
  Code reference: LooseEnds/Mac/MenuBarCapture.swift:148
  Description: isGlue erkennt Swift-Rahmen am Namensende „TR“ oder „TA“; ein Symbol, das zufällig so endet (z. B. `$s3Foo4DATA`), zählt als Klebstoff.
  Spec requirement: AC-1 — Stapel ab dem ersten Rahmen außerhalb des Beobachters
  Conflict: Nur wenn ein solcher Rahmen zwischen zwei Beobachterrahmen steht, wird er mit weggelassen; hinter dem letzten Beobachterrahmen bleibt er sichtbar. Praktisch folgenlos, reine Diagnose.
  Remediation: Keine nötig; bei Bedarf Suffix auf „TRTA“/„TR“ mit vorangehendem „_“ beschränken.

Frühere Befunde F101 (Filter), F102 (Stapelanfang am echten Lauf), F103 (Klebstoff zwischen Beobachterrahmen) sind behoben: F102 am echten CI-Protokoll 6c26a51 offline nachgestellt (51/51), F103 per Test „glue“.


## Verdict

═══════════════════════════════════════
VERDICT: VERIFIED
═══════════════════════════════════════
Der Stapelanfang (F102) ist behoben: der echte `afterObserver`-Rumpf liefert an allen 51 echten Stapeln des CI-Laufs 45249742660 (kurz und ungekürzt) denselben Anfang, den Foundation-Notification-Rahmen nach dem letzten Beobachterrahmen.
Tests: 29 passed, 0 failed, 0 übersprungen (scripts/test_mac_panel_repeat_summary.py)
Edge cases: geprüft, nichts gebrochen (nur F104 LOW)
Regressions: keine; Verhalten der App unverändert
Checklist: 8/8 points proven
Offen für den nächsten CI-Lauf (nach Commit): `log show`-Zeilen `panel ...` im Artefakt `MacGalleryPanelLog` müssen mit einem Rahmen nach dem Beobachter beginnen (kein `...TRTA`, kein `assumeIsolated`, kein `MacAppDelegate`-Beobachterrahmen als erster Rahmen); Pflichtjob „Mac Gallery (macOS)“ grün beim ersten Versuch; Wiederholungslauf mit Nenner = Iterationen je Arm. Restrisiko niedrig: abweichende Rahmennamen bei anderer Toolchain ließen höchstens mehr Rahmen stehen, nie weniger.

## Geprüfte Dateien

- sha256:05862f4d00a8c539043257bceaf746e610a8b72f6e2e710d925b11b5779a1e5f  .github/workflows/mac-panel-repeat.yml
- sha256:c2687c15da6a8983f4a3ec653f69548218e0e899a71f1d12b27e7d74e902e57a  LooseEnds/Mac/MenuBarCapture.swift
- sha256:b39f3050e76ecaa537358ef3712b32feb31b9be11a566c7ae9afd924f57bce2f  LooseEndsUITests/MacGalleryTests.swift
- sha256:7d41009d5fee0a33839986decaf92083d7101ac0768ecf9d16972c877470151e  scripts/mac_panel_repeat_summary.py
- sha256:8eddc63945a1d2a4ba001471bfd512ace6a59f7632559759a1c467573d8128df  scripts/test_mac_panel_repeat_summary.py

## Prüfbasis

- base: fa3d5076cd6e5df73d420a42564d78ca71495859
- blob:34516285072b96e128b00267710ed3f4b6aa42e9  .github/workflows/mac-panel-repeat.yml
- blob:45db4826d36f8e0fb2f3d65234040fde251c22a5  LooseEnds/Mac/MenuBarCapture.swift
- blob:5e88f752ad6c4f315d0b59d20e3d7eb95f32cbaa  LooseEndsUITests/MacGalleryTests.swift
- blob:1cf5d406d59e48ed043c944eac0118461a5192e1  scripts/mac_panel_repeat_summary.py
- blob:13b846a1b47d7027a2e035988c5e7b0d6604fa9e  scripts/test_mac_panel_repeat_summary.py

## Geprüfte Dateien

- sha256:05862f4d00a8c539043257bceaf746e610a8b72f6e2e710d925b11b5779a1e5f  .github/workflows/mac-panel-repeat.yml
- sha256:c2687c15da6a8983f4a3ec653f69548218e0e899a71f1d12b27e7d74e902e57a  LooseEnds/Mac/MenuBarCapture.swift
- sha256:b39f3050e76ecaa537358ef3712b32feb31b9be11a566c7ae9afd924f57bce2f  LooseEndsUITests/MacGalleryTests.swift
- sha256:7d41009d5fee0a33839986decaf92083d7101ac0768ecf9d16972c877470151e  scripts/mac_panel_repeat_summary.py
- sha256:8eddc63945a1d2a4ba001471bfd512ace6a59f7632559759a1c467573d8128df  scripts/test_mac_panel_repeat_summary.py

## Prüfbasis

- base: fa3d5076cd6e5df73d420a42564d78ca71495859
- blob:34516285072b96e128b00267710ed3f4b6aa42e9  .github/workflows/mac-panel-repeat.yml
- blob:45db4826d36f8e0fb2f3d65234040fde251c22a5  LooseEnds/Mac/MenuBarCapture.swift
- blob:5e88f752ad6c4f315d0b59d20e3d7eb95f32cbaa  LooseEndsUITests/MacGalleryTests.swift
- blob:1cf5d406d59e48ed043c944eac0118461a5192e1  scripts/mac_panel_repeat_summary.py
- blob:13b846a1b47d7027a2e035988c5e7b0d6604fa9e  scripts/test_mac_panel_repeat_summary.py
