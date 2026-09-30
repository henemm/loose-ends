# Validierungsbericht — feat-153-geraetestufe-ui-test (Phase 7)

Stand: `f2306df` · Lauf: 2026-09-30, 12:06–12:23 CEST · Worktree `piped-wiggling-boole`

## Testergebnisse

| Prüfung | Befehl | Ergebnis |
|---|---|---|
| Unit-Tests (AC-7) | `./scripts/sim.sh unit` | **229 Fälle grün, 0 Fehlschläge, Exit 0** (`ac7-unit.txt`) |
| Simulator-UI-Test (AC-8) | `./scripts/sim.sh test RecognitionWalkthroughTests` | **1 Fall grün, 0 Fehlschläge, 100,6 s, Exit 0** (`ac8-uitest.txt`) |

Beides ist zugleich der Regressionslauf: `unit` fährt die vollständige Suite, nicht nur die
Tests dieses Tickets. Keine vorher grüne Prüfung ist rot geworden.

## Beleg statt Zählung

Grün allein beweist beim UI-Test nichts über den genommenen Zweig. Der Testanhang
`ac8-schritt3-zweig.txt` hält ihn fest:

> Schritt 3: Kontext war nicht gesetzt — angetippt

Das ist der erwartete Simulator-Zweig (kein Apple Intelligence, also setzt niemand den Kontext
vorab). Der andere Zweig — Kontext steht bereits, Test tippt ihn **nicht** an — bleibt im Simulator
naturgemäß ungelaufen; genau das ist die in `docs/project/04-stand.md` benannte Nachweislücke.

Das Schlussbild `screenshots/4-zweite-aufgabe-mit-uebernommenen-werten.png` zeigt die Sache selbst:
Die zweite, wortgleich erfasste Aufgabe „mähen Rasen" trägt **Duration 30 min ✦** und
**Contexts Garden ✦** — beide mit KI-Vermerk, von der ersten Aufgabe übernommen. Die
Wiedererkennungsregel greift im echten Ablauf, nicht nur in der Zusicherung.

## Acceptance Criteria

13 von 13 erfüllt.

| AC | Ergebnis | Beleg |
|---|---|---|
| AC-1 `device-test` ist unbekannter Befehl, Exit ≠ 0 | ✅ | Ausgabe „Unbekannter Befehl: device-test", exit=1 |
| AC-2 alle acht Bezeichner aus `scripts/sim.sh` weg | ✅ | acht Zähler, jeder `0` |
| AC-3 ursprünglicher Trap wieder da | ✅ | `trap release_lock EXIT` in Z. 73, `cleanup_locks` = 0 |
| AC-4 Prüfstand gelöscht und aus dem Index | ✅ | Datei `WEG`, `git ls-files` leer |
| AC-5 `scripts/tests/` ohne Eintrag | ✅ | `git ls-files scripts/tests/` leer |
| AC-6 Gegenprobe über Werkzeuge/Regeln/Doku/Testcode | ✅ | kein Treffer; Gegenprobe liefert Kontext + Spec |
| AC-7 Unit-Tests grün | ✅ | 229 grün, Exit 0 |
| AC-8 Simulator-Regressionstest grün | ✅ | 1 grün, Exit 0 |
| AC-9 `device-status` bleibt rein lesend | ✅ | nur `devicectl device info details` |
| AC-10 `04-stand.md` neu | ✅ | `device-status` vorhanden, alter Stufe-3-Befehl weg |
| AC-11 ADR-11-Zusatz | ✅ | „kein Fernstart" vorhanden, alter Satz weg |
| AC-12 `CLAUDE.md` Pfadliste | ✅ | `device-status` vorhanden, alter Satz weg |
| AC-13 kein Produktpfad angefasst | ✅ | `git diff --stat main...HEAD -- Shared/ LooseEnds/Views/` leer |

## Umfang

| Maß | Wert | Grenze |
|---|---|---|
| Code-Dateien gegen `main` | 2 (`CLAUDE.md`, `LooseEndsUITests/RecognitionWalkthroughTests.swift`) | 5 |
| Code-Zeilen netto | +65 | ±250 |
| Produktpfade (`Shared/`, `LooseEnds/Views/`) | unberührt | — |

Die übrigen geänderten Dateien sind Projektdokumentation (`docs/project/`) und die Artefakte des
Workflows selbst.

**Zur Netto-Null in `scripts/sim.sh`:** Der Vergleich gegen `main` zeigt für `scripts/sim.sh` keine
Änderung und für `scripts/tests/device-test.sh` keine Löschung — nicht weil der Rückbau fehlt,
sondern weil beides innerhalb dieses Arbeitsstands entstanden und wieder entfernt wurde. Belege:
`git show main:scripts/sim.sh | grep -c cmd_device_test` → `0`, dasselbe auf HEAD → `0`;
`git ls-tree -r --name-only main -- scripts/` kennt nur `export-focusblox-corpus.swift`,
`measurement-summary.py`, `sim.sh`. Eine erste automatische Prüfung las die leere Differenz als
fehlende Umsetzung; die Nachprüfung widerlegt das.

## Dokumentationsprüfung

Ein echter Widerspruch gefunden und behoben: `docs/project/04-stand.md` leitete die Abnahme mit
„Keine Stufe wird übersprungen, keine vorgezogen" ein, während `CLAUDE.md` seit #154 festlegt, dass
die Gerätestufe nur bei Treffer auf der Pfadliste läuft. Ein Satz angepasst, der sorgfältig
formulierte Rückbau-Text darunter unverändert.

Weiter geprüft, ohne Fund: jeder in `CLAUDE.md` und `04-stand.md` genannte `sim.sh`-Befehl existiert
in der `case`-Verzweigung (`generate`, `unit`, `build`, `device-status`, `lab`); keine weitere
Dokumentationsstelle im Repo beschreibt noch die alte Gerätestufe; die Folge-Issues #156, #143, #160
sind über alle Dateien hinweg gleich beschrieben.

## Runde 4 des Prüfdialogs

Diese eine Korrektur hat eine bereits gestempelte Datei verändert, worauf das QA-Gate den Abschluss
blockiert hat — zu Recht. Der Prüfdialog wurde um eine vierte Runde ergänzt, die ausschließlich
diese Änderung angreift: Widerspruch belegt (`git show 92c9455 -- CLAUDE.md` zeigt die bedingte
Regel seit #154, während `04-stand.md:144` unverändert blieb), AC-10 nach der Korrektur erneut
grün, kein neuer Widerspruch, der Verweis auf `CLAUDE.md` trägt (Pfadtabelle in Z. 64–78), und
außer `04-stand.md` ist keine gestempelte Datei berührt (die übrigen fünf per `shasum -a 256`
gegengeprüft). **Verdict: VERIFIED.**

Ein nicht blockierender Fund kam dabei heraus — **F003 (LOW):** Der korrigierte Satz ist wörtlich
DoD-Punkt 1 von Issue **#154**, das noch offen ist. Die Sache ist damit erledigt, die Buchhaltung
nicht. Beim Abschluss wird dieser Punkt in #154 mit Verweis auf diesen Stand abgehakt; die übrigen
drei DoD-Punkte von #154 bleiben unberührt offen.

## Nebenwirkung des Testlaufs

Der Unit-Lauf hat wie immer die drei Messberichte (`date-title-fidelity.md`,
`focusblox-calibration-report.md`, `retrieval-leave-one-out-rules.md`) überschrieben — der
Kalibrierungsbericht mit Nullen, weil der Simulator kein Apple Intelligence hat (#147). Alle drei
wurden vor dem Abschluss zurückgesetzt.

## Gerätestufe

**Kein Pfad der Geräteliste berührt.** Geändert sind `CLAUDE.md` und
`LooseEndsUITests/RecognitionWalkthroughTests.swift`; keiner der acht Pfade aus der Liste in
`CLAUDE.md` ist dabei. Die Abnahme endet nach Stufe 2.

## Ergebnis

**PASS.**
