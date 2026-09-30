---
entity_id: feat-153-geraetestufe-ui-test
type: feature
created: 2026-09-29
updated: 2026-09-30
status: draft
workflow: feat-153-geraetestufe-ui-test
---

# Spec: #153 — Rückbau: Die Gerätestufe fährt keine Bedienabläufe mehr

## Approval

- [ ] Approved

## Purpose

Stufe 3 der Abnahme trägt aktuell (staged, noch nicht gemergt) den Befehl
`./scripts/sim.sh device-test <Klasse[/test]>`, gebaut nach der ursprünglichen Spec vom 2026-09-29.
Der erste echte Lauf damit — `RecognitionWalkthroughTests` auf Hennings iPhone,
2026-09-30 06:19–06:20, Exit 0, „Test Suite … passed" — hat die Prämisse des Tickets widerlegt,
obwohl er grün war. Drei Befunde aus diesem Lauf
(`docs/context/feat-153-geraetestufe-ui-test.md`, Abschnitt „Analysis — Neuschnitt nach dem echten
Gerätelauf", „Was der echte Lauf gezeigt hat"):

1. **Er ist invasiv.** Er überschrieb die produktive Installation (gleiche Kennung
   `com.henning.looseends`), installierte zusätzlich `com.henning.looseends.uitests.xctrunner`, die
   neu gebaute Sperr-Vorprüfung startete die App im Vordergrund, und das Gerät war 5–10 Minuten
   exklusiv belegt und musste entsperrt bleiben.
2. **Er beweist nicht, wofür er gebaut wurde.** Auf
   `docs/artifacts/feat-153-geraetestufe-ui-test/screenshots/4-zweite-aufgabe-mit-uebernommenen-werten.png`
   ist das Titelfeld leer — Apple Intelligence hat im Testlauf nichts gesetzt. Der neue bedingte
   Zweig aus Schritt 3 (Eingriff 1, unten) wurde nie betreten; der Anhang `schritt3-zweig` zeigt
   auch auf dem Gerät „Kontext war nicht gesetzt — angetippt". Der Lauf prüfte damit dasselbe wie
   der Simulator, nur invasiver.
3. **Er verletzt eine bestehende, nie gekippte Entscheidung.** In `scripts/sim.sh`, im Kommentar
   über `cmd_lab_run`, steht wörtlich: „Gemessen wird in der Labor-App auf dem iPhone, nicht in
   einem Testlauf: ein Testlauf belegt das Gerät am Stück und entsperrt, bis er fertig ist. Henning
   benutzt sein iPhone den ganzen Tag." Dazu die Festlegung seit 2026-09-20: „kein Fernstart einer
   App auf seinem iPhone, nie." Beides wurde beim Bau von #153 übersehen, nicht widerlegt.

**Folge:** Die Gerätestufe fährt keine nachgespielten Bedienabläufe. Der gebaute Befehl kommt
vollständig wieder heraus. Stufe 3 steht wieder auf dem, was unstrittig und nicht invasiv ist:
`./scripts/sim.sh device-status` (rein lesend, `cmd_device_status`, `scripts/sim.sh:287–292` —
liest nur `devicectl device info details`, baut, installiert und startet nichts) plus die Labor-App
(`./scripts/sim.sh lab`), die Henning selbst antippt. Begründung in einem Satz: Ohne Fernstart und
ohne Installation gibt es keinen Bedienablauf auf diesem Gerät — und beides ist aus gutem Grund
ausgeschlossen.

Eine geprüfte Alternative — passiv mitlesen statt aktiv bedienen (`xctrace record --template
Logging`) — trägt in der am 2026-09-30 durchdachten Form nicht (Begründung unten, Abschnitt
„Alternativen"). Sie bleibt als Spike bei #143 offen, ist aber kein Ersatz für diesen Rückbau.

### Abweichung vom Tech-Lead-Kommentar zu #153 (2026-09-30T04:41:35Z) — offen benannt

Issue #153 trägt inzwischen den Titel „Gerätestufe: gezielte Sonden statt nachgespielter
Bedienabläufe", aber Body und DoD-Liste des Issues beschreiben weiterhin unverändert den Aufbau,
den diese Spec entfernt. Der einzige Kommentar auf dem Issue (04:41:35Z, Tech Lead) entscheidet sich
für einen Mittelweg: Die nachgespielten Bedienabläufe und die invasive Sperr-Vorprüfung sollen
raus, aber die handwerklich soliden Teile — Zeitschranke, Rückgabewert über `PIPESTATUS`,
`deviceprep`-Erkennung, Belegausgabe, Gerätelock — sollen als Grundlage für künftige „gezielte
Sonden" bestehen bleiben, mit der Vorbedingung „#156 zuerst" (Kennungstrennung, damit Prüfbauten
nicht mehr die Produktivkennung tragen).

**Diese Spec folgt stattdessen der jüngeren Analyse in
`docs/context/feat-153-geraetestufe-ui-test.md`** (Abschnitt „Analysis — Neuschnitt …", entstanden
nach dem Kommentar, am selben Tag): vollständiger Rückbau, nicht Teilerhalt. Begründung für die
Abweichung: Ohne die eigentliche Testausführung hat keiner der „soliden Teile" mehr einen Aufrufer —
`device_probe_locked` probiert den Start der Haupt-App, `cmd_device_test` ruft `xcodebuild test`;
beides ist ohne einen tatsächlich gefahrenen Bedienablauf zwecklos. Ein Befehl, der im Code bleibt,
aber laut Kommentar „nicht vor #156 benutzt werden darf", ist genau die Art Falle, vor der die
Grundregel schützen soll: er ist da, er ist aufrufbar, und nichts im Skript selbst verhindert einen
erneuten Fernstart auf Hennings Gerät vor #156. Es gibt hier **keine vereinbarte Einigkeit** — nur
eine spätere, weitergehende Entscheidung, die die frühere überstimmt. Teil der Definition of Done
ist deshalb, Titel, Body und DoD-Liste von #153 beim Abschluss auf den tatsächlichen Rückbau
nachzuziehen, statt die Diskrepanz stehen zu lassen.

## Source

Rückzubauende Bezeichner, mit den Zeilen im aktuellen (gebauten, noch ungemergten) Arbeitsstand:

- **Datei:** `scripts/sim.sh`
- **Bezeichner:** Hilfetext-Zeile `device-test` (Z. 27); `MAIN_BUNDLE_ID`, `DEVICE_LOCK_DIR`,
  `DEVICE_LOCK_ACQUIRED` (Z. 50–52); `acquire_device_lock`/`release_device_lock`/`cleanup_locks`
  und `trap cleanup_locks EXIT` (Z. 78–96, ersetzt den ursprünglichen `trap release_lock EXIT`);
  `device_probe_locked` und `cmd_device_test` (Z. 365–439); Dispatch-Zeile `device-test)` (Z. 553);
  `cmd_help`-Bereich `sed -n '3,30p'` (Z. 534, zurück auf `'3,29p'`, weil eine Hilfetext-Zeile
  entfällt). `cmd_device_status` (Z. 287–292) bleibt unverändert — sie ist bereits rein lesend.
- **Datei:** `scripts/tests/device-test.sh` (216 Zeilen, zuletzt in Commit `bdab40a`
  „test: RED fuer den Geraete-Testbefehl — 7 Faelle, 0 bestanden (#153)" versioniert, seither weiter
  bearbeitet) — wird vollständig gelöscht.
- **Datei:** `LooseEndsUITests/RecognitionWalkthroughTests.swift`
- **Bezeichner:** nur der Kopfkommentar-Absatz Z. 7–13 („Seit #153 läuft derselbe Ablauf auf beiden
  Abnahmestufen … `device-test RecognitionWalkthroughTests` …"). Die drei Testeingriffe —
  `garden.isSelected`-Bedingung (Z. 157–165), `topRow(in:)` (Z. 62–70) mit `detailRawText`-Abgleich
  (Z. 178–188), Rückkehr über `app.buttons["captureButton"]` (Z. 172–176) — bleiben unverändert; sie
  sind unabhängig vom Gerätelauf richtig, weil ein Simulator mit künftigem Apple-Intelligence-Zugriff
  oder ein anderer Modellzustand dieselbe Robustheit braucht.
- **Datei:** `docs/project/04-stand.md`
- **Abschnitt:** „Abnahme in drei Stufen", Stufe-3-Absätze Z. 149–168.
- **Datei:** `docs/project/00-entscheidungen.md`
- **Abschnitt:** ADR-11-Zusatz Z. 136–140 (angehängt am 2026-09-29, wird jetzt ersetzt, nicht neu
  nummeriert).
- **Datei:** `CLAUDE.md`
- **Abschnitt:** Absatz zur Pfadliste, Z. 81–84 (Satz „Berührt er einen, läuft der volle
  Bedienablauf über `./scripts/sim.sh device-test <Klasse>` …"). **Fehlte in der Affected-Files-
  Tabelle der Analyse** (`docs/context/feat-153-geraetestufe-ui-test.md:313–321`) — dort wurde die
  Konsequenz für diese Datei nicht gezogen, obwohl sie denselben jetzt ungültigen Befehl nennt. Wird
  hier ergänzt und im Changelog vermerkt.

## Dependencies

| Baustein | Art | Zweck |
|---|---|---|
| `scripts/sim.sh` (`acquire_lock`/`release_lock`, Z. 60–76) | Werkzeug, unverändert | Bleibt das einzige Lock-Muster im Skript, nachdem das Gerätelock-Duplikat entfernt ist |
| `scripts/sim.sh` (`cmd_device_status`, Z. 287–292; `cmd_lab`/`cmd_lab_run`) | Werkzeug, unverändert | Trägt Stufe 3 künftig allein: Statusblick plus der von Henning selbst bediente Labor-Lauf |
| `git rm`, `git grep`, `git ls-files` | Werkzeug | Belegen die Abwesenheit der entfernten Bezeichner (siehe Test Plan/Acceptance Criteria) |
| `docs/artifacts/feat-153-geraetestufe-ui-test/` (bereits vorhanden) | Historie, unverändert | Enthält die Belege des gescheiterten Versuchs — Adversary-Dialog, Mutationstests, Screenshots, `test-green-output.txt`. Bleibt als Beleg liegen, warum zurückgebaut wurde; wird beim Aufräumen **nicht** gelöscht. |
| #156 (offen) | Vorbedingung für jede künftige Wiederaufnahme | Kennungstrennung für Prüfbauten — ohne sie darf laut Tech-Lead-Kommentar nichts auf dem Gerät laufen; #153 zieht daraus die Konsequenz, jetzt ganz zurückzubauen statt auf #156 zu warten |
| #143 (offen), #160 (offen) | Folgeticket | Spike zu `xctrace record` als Beobachtungskanal (#143) und Klärung, dass `device-console` die falsche Quelle liest (#160) — beide schließen die durch den Rückbau offene Nachweislücke nicht in diesem Ticket |
| #154 (offen) | Unverändert von diesem Schnitt | Die Pfadliste in `CLAUDE.md` bleibt bestehen; nur der Satz, was bei einem Treffer läuft, ändert sich. #154 gilt dadurch nicht als erledigt und nicht als gekippt. |
| #155 (offen) | Wird gegenstandslos | „Prüfstand des Gerätetest-Befehls läuft in keinem CI-Job" — der Prüfstand existiert nach diesem Rückbau nicht mehr; #155 wird mit Begründung geschlossen, nicht bearbeitet. |

## Scope

### Affected Files

| Datei | Change Type | Beschreibung |
|---|---|---|
| `scripts/sim.sh` | MODIFY | `cmd_device_test`, `device_probe_locked`, `acquire_device_lock`, `release_device_lock`, `cleanup_locks` entfernen; `trap cleanup_locks EXIT` → `trap release_lock EXIT`; `MAIN_BUNDLE_ID`, `DEVICE_LOCK_DIR`, `DEVICE_LOCK_ACQUIRED` entfernen; Dispatch-Zeile und Hilfetext-Zeile entfernen; `cmd_help`-Bereich zurück auf `'3,29p'` |
| `scripts/tests/device-test.sh` | DELETE | Prüfstand des entfernten Befehls (`git rm`); `scripts/tests/` bleibt danach ohne Inhalt (Git kennt keine leeren Verzeichnisse, verschwindet also aus jeder `git ls-files`-Auflistung von selbst) |
| `docs/project/04-stand.md` | MODIFY | Stufe 3 neu: `device-status` (rein lesend) plus Labor-App; Begründung, warum kein Bedienablauf mehr läuft; `device-console`-Begründung ausdrücklich für hinfällig erklärt (#160); Verweis auf die offene Nachweislücke und die Folgetickets #156/#143/#160 |
| `docs/project/00-entscheidungen.md` | MODIFY | ADR-11-Zusatz ersetzt (keine neue ADR-Nummer): kein Testlauf, kein Fernstart auf Hennings Gerät; Hardware-Only-Sachverhalte werden gemessen oder beobachtet, nicht bedient |
| `CLAUDE.md` | MODIFY | Satz zur Pfadliste (Z. 81–84) auf `device-status` + Labor-App umgeschrieben, Nachweislücke für Watch/Widgets/Share/Mikrofon/Mitteilungen benannt. **Ergänzt gegenüber der Analyse** (siehe Changelog). |
| `LooseEndsUITests/RecognitionWalkthroughTests.swift` | MODIFY | Nur der Kopfkommentar-Absatz Z. 7–13 zurück auf „läuft im Simulator"; die drei Testeingriffe (Endzustand statt Bedienweg) bleiben unverändert, mit Verweis auf #158 (Verschärfung auf Wertgleichheit) |
| `docs/artifacts/feat-153-geraetestufe-ui-test/` | KEEP (unverändert) | Historie des gescheiterten Versuchs bleibt liegen — kein Aufräumen, kein Löschen |

Sechs Dateien werden geändert oder gelöscht, eine bleibt bewusst unangetastet. Das reißt die
Scoping-Grenze aus der globalen `CLAUDE.md` („Max 4–5 Dateien"). Siehe Begründung unter „Estimated
Changes".

### Estimated Changes

Gemessen, nicht geschätzt — jede Zahl stammt aus `git diff HEAD --numstat` für das bereits Gebaute
bzw. aus `wc -l` gegen die tatsächlich formulierten Ersatztexte dieser Spec:

| Datei | entfernt | hinzugefügt | Netto |
|---|---:|---:|---:|
| `scripts/sim.sh` | 99 | 1 (`trap release_lock EXIT`) | −98 |
| `scripts/tests/device-test.sh` | 216 | 0 | −216 |
| `docs/project/04-stand.md` | 20 | 27 | +7 |
| `docs/project/00-entscheidungen.md` | 5 | 4 | −1 |
| `CLAUDE.md` | 4 | 8 | +4 |
| `LooseEndsUITests/RecognitionWalkthroughTests.swift` | 7 | 6 | −1 |
| **Summe** | **351** | **46** | **−305** |

`scripts/sim.sh` (99 entfernte Zeilen: 1 Hilfetext + 3 Variablen + 19 Gerätelock-Block + 75
`device_probe_locked`/`cmd_device_test` + 1 Dispatch-Zeile) und `scripts/tests/device-test.sh` (216
Zeilen komplett) tragen den Rückbau; die drei Dokumente und der Testkommentar sind Korrekturen im
einstelligen bis niedrigen zweistelligen Bereich.

**Additionen + Deletionen zusammen: 397 LoC — 147 über der 250er-Grenze aus `CLAUDE.md`. Dazu
6 statt 4–5 Dateien.** Beide Grenzen sind gerissen; das wird hier offen benannt, nicht
stillschweigend überschritten. Kein Pfad unter `Shared/` oder `LooseEnds/Views/` ist betroffen
(siehe AC-13).

**Das ist eine eigene Entscheidung des PO, nicht eine Folge der Spec-Freigabe.** `CLAUDE.md`
verlangt bei Überschreitung ausdrücklich „STOP und nachfragen mit konkreter Schätzung" — diese Spec
darf sich die Überschreitung deshalb nicht selbst genehmigen. Die beiden Wege stehen offen, mit
ihrem jeweiligen Preis:

| Weg | Preis |
|---|---|
| **A — in einem Zug zurückbauen** (Empfehlung) | Reißt die Grenzen einmalig um 1 Datei und 147 LoC. Dafür ist der invasive Befehl nach einem Schritt vollständig weg. |
| **B — in zwei Tickets teilen** (etwa: Skript und Prüfstand jetzt, die vier Dokumente später) | Hält beide Grenzen ein. Preis: Zwischen den beiden Tickets steht entweder ein Befehl im Skript, den die Dokumentation schon für abgeschafft erklärt, oder eine Dokumentation, die auf einen entfernten Befehl verweist. Beides ist genau die Falle, die den Vorfall vom 30.09. ermöglicht hat: etwas, das aufrufbar ist und dessen einzige Schranke ein Satz in einer Datei ist. |

**Empfehlung: Weg A.** Der Überhang ist zu über 90 % (315 von 351 entfernten Zeilen) reiner Abbau
von Code, der in diesem selben, noch ungemergten Arbeitsstand erst entstanden ist — nicht neue
Logik, sondern die Rücknahme einer bereits vollständig geschriebenen und bereits einmal (fälschlich)
für fertig befundenen Änderung. Das Risiko, das die 250er-Grenze abwehren soll (zu viel neue,
ungeprüfte Logik auf einmal), entsteht hier nicht. Wählt der PO Weg B, wird die Spec entsprechend
geteilt, bevor die Umsetzung beginnt.

Zur Dateizahl trägt dieselbe Begründung: Fünf der sechs Änderungen sind mechanische Entfernungen
oder Ein-Satz-Korrekturen ohne neue Entscheidungen; nur `docs/project/04-stand.md` bekommt einen
inhaltlich neuen Absatz (die offene Nachweislücke).

- Risiko: **Niedrig** — es wird nur entfernt, was in diesem Arbeitsstand entstanden und noch nicht
  gemergt ist, plus vier kleine Dokument-Korrekturen. Kein Produktpfad wird berührt.

## Implementation Details

### 1. `scripts/sim.sh` — Rückbau in der Reihenfolge des Bauens, rückwärts

**Hilfetext (Z. 27).** Zeile
`#   ./scripts/sim.sh device-test <Class[/test]> # UI-Test signiert auf dem Gerät, Screenshots als Artefakt`
entfällt ersatzlos. `cmd_help` (Z. 534) zeigt `sed -n '3,30p'` — zurück auf `'3,29p'`, weil eine
Kopfkommentarzeile weniger existiert.

**Variablen (Z. 50–52).** `MAIN_BUNDLE_ID`, `DEVICE_LOCK_DIR`, `DEVICE_LOCK_ACQUIRED` entfallen; sie
werden nach dem Rückbau von keiner Funktion mehr gelesen.

**Gerätelock-Block (Z. 78–96).** Der komplette Kommentar plus `acquire_device_lock`,
`release_device_lock`, `cleanup_locks` und `trap cleanup_locks EXIT` entfallen. An ihrer Stelle
steht wieder, was vor dem Bau von #153 dort stand:

```bash
release_lock() { [ -n "$LOCK_ACQUIRED" ] && rm -rf "$LOCK_DIR" 2>/dev/null; LOCK_ACQUIRED=""; return 0; }
trap release_lock EXIT
```

**`device_probe_locked` und `cmd_device_test` (Z. 365–439).** Beide Funktionen entfallen vollständig,
einschließlich aller Kommentare (Begründung der 30-Sekunden-Zeitschranke im Probestart, Begründung
der `PIPESTATUS`-Auswertung, Begründung des `LOOSEENDS_ARTIFACT_DIR`-Fallbacks). Diese Kommentare
sind Wissen, nicht Code — ihr Inhalt landet, soweit er über den Anlass dieses Rückbaus hinaus
trägt, nicht in einer neuen Datei, sondern bleibt in der Git-Historie dieses Reverts auffindbar
(`git log -p -- scripts/sim.sh`) und im ADR-11-Zusatz zusammengefasst (siehe unten).

**Dispatch-Zeile (Z. 553).** `device-test)    cmd_device_test "$@" ;;` entfällt.

### 2. `scripts/tests/device-test.sh` — Löschen

```bash
git rm scripts/tests/device-test.sh
```

Die Datei ist versioniert (zuletzt Commit `bdab40a`); ein einfaches `rm` würde sie als „deleted,
not staged" zurücklassen. Kein Ersatz, keine Verschiebung in ein Folgeticket — der Prüfstand prüft
einen Befehl, der nicht mehr existiert, und ist damit gegenstandslos, nicht aufhebenswert (siehe
„Was mit #155 passiert" unten).

### 3. `LooseEndsUITests/RecognitionWalkthroughTests.swift` — nur der Kopfkommentar

Ersetzt Z. 7–13:

```swift
/// `--ui-testing` schaltet auf einen In-Memory-Store, lässt aber den echten
/// `FoundationModelsEnricher` laufen: im Simulator praktisch immer ohne Apple Intelligence. Die
/// Zusicherungen prüfen trotzdem das **Ergebnis** (steht der Wert dran?) und nie den Bedienweg
/// (habe ich ihn angetippt?) — robuster gegenüber einem Umschalter, den ein Modell schon gesetzt
/// haben könnte, und einem Rohtext, den es geglättet hat. Die Verschärfung der Zusicherungen auf
/// Wertgleichheit statt Teilzeichenfolgen ist #158.
```

Die drei Eingriffe im Testkörper selbst (bedingtes `garden.tap()` über `.isSelected`, Z. 157–165;
`topRow(in:)` + `detailRawText` statt Labelsuche, Z. 62–70 und 178–188; Rückkehr über
`captureButton` statt der ersten Zeile, Z. 172–176) bleiben zeichengleich stehen. Sie sind unabhängig vom Gerätelauf gerechtfertigt: Der
Simulator kann in einer künftigen iOS-Version ebenfalls Modell-Zugriff bekommen, und ein robusterer
Test ist in jedem Fall besser als ein fragiler — die Rückbau-Entscheidung betrifft nur, **wo** der
Test läuft, nicht, wie er prüft.

### 4. `docs/project/04-stand.md` — Stufe 3 neu

Ersetzt Z. 149–168 (Punkt 3 der Liste plus die vier folgenden Absätze):

```markdown
3. **Hennings iPhone 16 Pro** — `./scripts/sim.sh device-status` (liest nur) und die Labor-App
   (`./scripts/sim.sh lab`), die Henning selbst antippt. Erst danach gilt eine Änderung als fertig.

Stufe 3 fährt seit #153 keinen nachgespielten Bedienablauf mehr. Der erste echte Versuch dafür —
derselbe UI-Test wie im Simulator, aber signiert auf dem Gerät — lief am 2026-09-30 zwar grün, war
dabei aber invasiv: Er überschrieb Hennings produktive Installation (gleiche Kennung
`com.henning.looseends`), die Sperr-Vorprüfung startete die App im Vordergrund und verdrängte, was
gerade lief, und das Telefon war 5–10 Minuten exklusiv belegt und musste entsperrt bleiben. Belegt
hat er dabei nichts von dem, wofür er gebaut wurde: Auf dem Beweisbild
(`docs/artifacts/feat-153-geraetestufe-ui-test/screenshots/`) hatte Apple Intelligence im Testlauf
nichts gesetzt — der Lauf prüfte damit dasselbe wie der Simulator, nur invasiver. Das verletzte eine
bestehende Entscheidung, die nie gekippt, sondern beim Bauen übersehen wurde (siehe die Begründung
zu `cmd_lab_run` unten in dieser Datei) und die Festlegung, nie eine App auf Hennings Gerät
fernzustarten.

`device-status` zeigt nur, ob und wie das Gerät verbunden ist — es baut, installiert und startet
nichts. Die frühere Begründung dieser Stufe über `device-console` ist hinfällig, nicht nur ersetzt:
Das Kommando liest die Standardausgabe (`--console`), die App schreibt aber ausschließlich über
`Logger`, nie über `print` (#160) — es hat nie gelesen, was sein Kommentar behauptete.

**Die dadurch entstehende Lücke wird hier benannt, nicht versteckt.** Für Apple Intelligence bleibt
die Labor-App der Messweg. Für Watch, Widgets, Share, Mikrofon und Mitteilungen gibt es auf echter
Hardware aktuell **keinen** automatisierten Nachweis mehr, nur den lesenden Statusblick. Folgeticket
für den Verschluss: #156 (eigene Kennung für Prüfbauten — Vorbedingung für alles Weitere auf dem
Gerät, weil Prüfbauten heute noch unter der Produktivkennung installieren), #143 (Spike: trägt
`xctrace record --template Logging` als Beobachtungskanal, ohne die App zu starten?), #160
(`device-console` klären oder ersetzen).
```

Die anschließenden Absätze „Was Stufe 3 findet und Stufe 2 prinzipiell nicht kann …" (unverändert
gültig — Apple Intelligence, CloudKit, Watch, Widgets, Mikrofon bleiben Dinge, die nur echte
Hardware zeigt, auch wenn kein Bedienablauf mehr dafür läuft) und der TestFlight-Absatz bleiben
zeichengleich stehen.

### 5. `docs/project/00-entscheidungen.md` — ADR-11-Zusatz ersetzen

Ersetzt Z. 136–140 (den am 2026-09-29 angehängten #153-Zusatz):

```markdown
Auf Hennings Gerät läuft kein Testlauf und kein Fernstart einer App. Was sich nur auf echter
Hardware zeigt, wird gemessen (Labor-App) oder beobachtet, nie bedient. Bedienabläufe — auch
UI-Tests — bleiben im Simulator; ein Versuch, sie signiert auf dem Gerät zu fahren, überschrieb
2026-09-30 Hennings produktive Installation und bewies dabei nicht, wofür er gebaut war (#153).
```

Keine neue ADR-Nummer — ADR-11 bleibt „Tests", nur ihr Zusatz ändert sich zum zweiten Mal
(einmal angehängt am 2026-09-29, jetzt ersetzt am 2026-09-30).

### 6. `CLAUDE.md` — Satz zur Pfadliste umschreiben

Ersetzt Z. 81–84:

```markdown
Berührt der Schnitt keinen dieser Pfade, endet die Abnahme nach Stufe 2, und das wird im
Abschlussbericht mit genau diesem Satz begründet: „Kein Pfad der Geräteliste berührt." Berührt er
einen, läuft `./scripts/sim.sh device-status` (liest nur, installiert und startet nichts) — für
Apple Intelligence zusätzlich die Labor-App, die Henning selbst antippt. Einen nachgespielten
Bedienablauf auf dem Gerät gibt es seit dem Rückbau von #153 nicht mehr: Der Versuch dazu
überschrieb Hennings produktive Installation und bewies nicht, wofür er gebaut war. Für Watch,
Widgets, Share, Mikrofon und Mitteilungen bleibt der automatisierte Nachweis auf echter Hardware
damit offen (`docs/project/04-stand.md`, #156, #143, #160). Im Zweifel läuft die Stufe.
```

Die Pfadliste selbst (Zeilen davor und danach, Tabelle mit den acht Pfaden aus #154) bleibt
zeichengleich stehen — sie wird durch diesen Rückbau weder erweitert noch verkleinert, nur die
Aussage, was ein Treffer auslöst, ändert sich.

## Test Plan

### TDD RED — wie sieht Rot vor dem Rückbau aus?

Jede Abwesenheits-Prüfung unten schlägt **heute**, vor der Umsetzung dieser Spec, mit dem
gegenteiligen Befund fehl, weil `cmd_device_test` und sein Prüfstand im aktuellen Arbeitsstand
existieren:

```bash
# heute: device-test ist ein bekannter Befehl (bricht NICHT mit "Unbekannter Befehl" ab)
./scripts/sim.sh device-test RecognitionWalkthroughTests --help 2>&1 | head -1
# → heute: "iPhone ist gesperrt …" oder ein Baufehler, NIE "Unbekannter Befehl: device-test"

# heute: jeder Bezeichner ist mindestens einmal vorhanden
for sym in cmd_device_test device_probe_locked acquire_device_lock release_device_lock \
           cleanup_locks MAIN_BUNDLE_ID DEVICE_LOCK_DIR DEVICE_LOCK_ACQUIRED; do
    echo "$sym: $(grep -c "$sym" scripts/sim.sh)"   # → heute jeweils ≥ 1
done

# heute: die Datei existiert
test -f scripts/tests/device-test.sh && echo VORHANDEN   # → heute VORHANDEN

# heute: die Dokumente nennen den Befehl
grep -c "device-test" docs/project/04-stand.md docs/project/00-entscheidungen.md CLAUDE.md
# → heute jeweils ≥ 1
```

Das ist der RED-Zustand: Ein Rückbau, der noch nicht stattgefunden hat, kann per Definition keine
Abwesenheit zeigen. Nach der Umsetzung (Implementation Details, oben) kippen alle Befunde ins
Gegenteil — das ist GREEN, geprüft in den Acceptance Criteria unten.

### Automatisiert, ohne echtes Gerät

- **`./scripts/sim.sh unit`** — Regressionsschutz, dass der Rückbau in `scripts/sim.sh` nichts
  anderes mitreißt (kein Produktpfad betroffen, aber das Skript wird von Tests aufgerufen).
- **`./scripts/sim.sh test RecognitionWalkthroughTests`** (Simulator) — Regressionstest für die drei
  unverändert bleibenden Testeingriffe. Muss grün bleiben, weil sich am Testkörper nichts ändert.
- **`git grep`/`grep -c`/`git ls-files`** wie oben — belegen die Abwesenheit der entfernten
  Bezeichner und Dateien repoweit.
- **`git diff --stat main...HEAD -- Shared/ LooseEnds/Views/`** — belegt, dass kein Produktpfad
  angefasst wurde (AC-13).

### Kein neues Prüfskript — bewusste Entscheidung, mit Begründung

Die Abwesenheits-Prüfungen werden **nicht** in einer neuen Skriptdatei (etwa
`scripts/tests/no-device-test.sh`) verankert, sondern als literale Befehle in dieser Spec und im
Abschlussbericht geführt. Drei Gründe:

1. **Widersprüchliches Bild.** Dieselbe Änderung löscht `scripts/tests/device-test.sh`, weil ein
   Prüfstand für einen nicht mehr existierenden Befehl gegenstandslos ist. Im selben Zug ein neues
   Prüfskript anzulegen, das einen anderen nicht mehr existierenden Zustand dauerhaft bewacht, wäre
   dieselbe Art Ballast — nur mit umgekehrtem Vorzeichen.
2. **Der Wert einer Abwesenheits-Prüfung verfällt schnell.** Sie beweist etwas über den heutigen
   Stand. Kommt `device-test` in einem späteren, bewusst neu aufgesetzten Ticket zurück (z. B. nach
   #156, als gezielte Sonde), müsste das Skript im selben Commit wieder entfernt oder umgeschrieben
   werden — es hätte nie eigenständigen Bestand.
3. **`feedback-device-stage-is-ceremony`** (Hennings Feedback vom 2026-09-28, im Gedächtnis
   verankert): ein Prüfschritt, der nur eine Formalie belegt und kein Feature, ist selbst Zeremonie.
   Ein dauerhaftes Skript, dessen einzige Aussage „dieser Befehl existiert noch nicht wieder" ist,
   fiele in genau diese Kategorie.

**Empfehlung:** Die Befehle oben werden während der Umsetzung ausgeführt, ihre Ausgabe wird im
Abschlussbericht wörtlich zitiert (wie bei jedem anderen Nachweis in diesem Projekt), und sie
verschwinden mit dem Abschluss des Tickets aus der aktiven Prüfkette — dieselbe Behandlung wie die
Messberichte unter `Measurement/`, die laut Memory bei jedem Lauf überschrieben und vor dem Commit
zurückgesetzt werden, nicht als Dauereinrichtung geführt.

### Was diese Prüfungen NICHT belegen

- **Dass niemand den Befehl in einem künftigen, unabhängig entstehenden Patch versehentlich wieder
  einführt.** Grep-Abwesenheit heute sagt nichts über morgen. Schutz dagegen ist Sache von
  Codereview und der ADR-11/CLAUDE.md-Begründung, nicht dieser Spec.
- **Dass CI nach dem Rückbau tatsächlich grün bleibt.** Das zeigt ausschließlich ein echter
  CI-Lauf, nicht die lokale Grep-Prüfung.
- **Dass Hennings Gerät durch den Rückbau selbst unangetastet bleibt.** Das lässt sich nicht
  positiv nachweisen, ohne genau das zu tun, was jetzt verboten ist (das Gerät ansprechen) — die
  einzig zulässige „Prüfung" ist, dass der Code, der es angesprochen hätte, nicht mehr existiert.
- **Dass die Nachweislücke (Watch, Widgets, Share, Mikrofon, Mitteilungen) durch diesen Rückbau
  irgendwie geschlossen wird.** Sie wird größer, nicht kleiner — siehe Risiken.

## Acceptance Criteria

- **AC-1 Befehl unbekannt, kein Gerätekontakt:** Given der Rückbau ist umgesetzt / When
  `./scripts/sim.sh device-test RecognitionWalkthroughTests` läuft / Then meldet der Befehl
  „Unbekannter Befehl: device-test", Exit-Code ≠ 0, und es wird weder `devicectl` noch `xcodebuild`
  mit einer Geräte-Destination aufgerufen (belegt durch Lesen von `cmd_help`/`case "$COMMAND"`, kein
  passender Zweig mehr vorhanden). Befehl: `./scripts/sim.sh device-test X; echo "exit=$?"`.
- **AC-2 Alle acht Bezeichner aus `scripts/sim.sh` entfernt:** Given der Rückbau ist umgesetzt /
  When jeder der acht Bezeichner gezählt wird / Then liefert jeder Zähler 0. Befehl:
  `for sym in cmd_device_test device_probe_locked acquire_device_lock release_device_lock cleanup_locks MAIN_BUNDLE_ID DEVICE_LOCK_DIR DEVICE_LOCK_ACQUIRED; do grep -c "$sym" scripts/sim.sh; done`
  → jede Zeile `0`.
- **AC-3 Ursprünglicher Trap wiederhergestellt:** Given der Rückbau ist umgesetzt / When
  `scripts/sim.sh` gelesen wird / Then steht `trap release_lock EXIT` wieder da, `cleanup_locks`
  kommt nirgends mehr vor. Befehl: `grep -n "trap release_lock EXIT" scripts/sim.sh` liefert genau
  eine Zeile; `grep -c cleanup_locks scripts/sim.sh` → `0`.
- **AC-4 Prüfstand gelöscht und aus dem Index entfernt:** Given der Rückbau ist umgesetzt / When
  `scripts/tests/device-test.sh` gesucht wird / Then existiert die Datei nicht mehr und `git
  ls-files` kennt sie nicht. Befehl: `test -f scripts/tests/device-test.sh && echo VORHANDEN ||
  echo WEG` → `WEG`; `git ls-files scripts/tests/device-test.sh` → leer.
- **AC-5 `scripts/tests/` trägt keinen Eintrag mehr:** Given der Rückbau ist umgesetzt / When das
  Verzeichnis über Git abgefragt wird / Then liefert `git ls-files scripts/tests/` keine Zeile.
- **AC-6 Gegenprobe über alle Pfade, die einen Befehl behaupten könnten:** Given der Rückbau ist
  umgesetzt / When die Pfade durchsucht werden, in denen `device-test` als *aufrufbarer Befehl*
  stehen würde — Werkzeuge, Projektregeln, Projektdokumentation, Testcode / Then gibt es keinen
  Treffer mehr. Befehl:
  `git grep -n "device-test" -- scripts CLAUDE.md docs/project LooseEndsUITests` → leer.
  **Bewusst ausgenommen, mit Begründung je Pfad:** `docs/artifacts/…` (Screenshots, Protokolle,
  Adversary-Dialog — Beweismaterial des gescheiterten Versuchs), `docs/context/…` (die Analyse, die
  den Rückbau begründet), `docs/specs/…` (diese Spec selbst) und `docs/briefings/…` (das PO-Briefing
  dazu). Diese vier Pfade **müssen** den Befehl weiterhin nennen — sie sind die Begründung des
  Rückbaus; ein AC, das sie einschließt, wäre nur erfüllbar, indem man die eigene Beweislage löscht.
  Gegenprobe dazu, damit die Ausnahme nichts verdeckt:
  `git grep -l "device-test" -- docs/context docs/specs` → liefert mindestens zwei Dateien.
- **AC-7 Unit-Tests grün:** Given der Rückbau ist umgesetzt / When `./scripts/sim.sh unit` läuft /
  Then endet der Lauf grün.
- **AC-8 Simulator-Regressionstest grün:** Given der Rückbau ist umgesetzt / When
  `./scripts/sim.sh test RecognitionWalkthroughTests` im Simulator läuft / Then endet der Lauf grün
  — die drei Eingriffe aus #153 (Endzustand statt Bedienweg) bleiben nachweislich funktionsfähig.
- **AC-9 `device-status` bleibt rein lesend:** Given `cmd_device_status` (Z. 287–292) / When der
  Code gelesen wird / Then ruft er ausschließlich `devicectl device info details` auf — kein
  `install`, kein `launch`, kein `xcodebuild`. Befehl: `grep -n "cmd_device_status" -A 6
  scripts/sim.sh` → enthält `device info details`, nicht `install|launch|xcodebuild`.
- **AC-10 `docs/project/04-stand.md` trägt den neuen Text, nicht mehr den alten:** Given der
  Rückbau ist umgesetzt / When die Datei gelesen wird / Then enthält sie „device-status (liest
  nur)" und die Nachweislücken-Nennung, aber nicht mehr „./scripts/sim.sh device-test <Klasse[/test]>"
  als Stufe-3-Befehl. Befehl: `grep -q "device-status" docs/project/04-stand.md &&
  ! grep -q "3\..*device-test" docs/project/04-stand.md`.
- **AC-11 `docs/project/00-entscheidungen.md` trägt den neuen ADR-11-Zusatz:** Given der Rückbau
  ist umgesetzt / When ADR-11 gelesen wird / Then enthält sie „kein Testlauf und kein Fernstart",
  aber nicht mehr „läuft mindestens ein Smoke-Test zusätzlich auf dem angeschlossenen iPhone".
  Befehl: `grep -q "kein Fernstart" docs/project/00-entscheidungen.md &&
  ! grep -q "Smoke-Test zusätzlich auf dem angeschlossenen iPhone" docs/project/00-entscheidungen.md`.
- **AC-12 `CLAUDE.md` trägt den neuen Satz zur Pfadliste:** Given der Rückbau ist umgesetzt / When
  der Absatz zur Pfadliste gelesen wird / Then verweist er auf `device-status` und die
  Nachweislücke, nicht mehr auf „der volle Bedienablauf über `./scripts/sim.sh device-test
  <Klasse>`". Befehl: `grep -q "device-status" CLAUDE.md && ! grep -q "der volle Bedienablauf über"
  CLAUDE.md`.
- **AC-13 Kein Produktpfad angefasst:** Given der fertige Diff gegen `main` / When `git diff --stat
  main...HEAD -- Shared/ LooseEnds/Views/` geprüft wird / Then ist die Ausgabe leer.

## Risiken

1. **Nachweislücke auf echter Hardware.** Nach dem Rückbau gibt es für Apple Intelligence, Watch,
   Widgets, Share, Mikrofon und Mitteilungen keinen automatisierten Beleg auf echtem Gerät mehr,
   nur die Labor-App (nur Modell) und den lesenden `device-status`-Blick. Laut Deckungsanalyse in
   `docs/context/feat-153-geraetestufe-ui-test.md` („Deckung der acht Bereiche durch passives
   Zuhören") wäre selbst ein funktionierender passiver Kanal nur bei App-Gruppe/CloudKit und Share
   gut, bei Apple Intelligence und Mikrofon nur teilweise, bei Watch und Mitteilungen eingeschränkt
   und bei **Widgets gar nicht** — die Lücke ist also größer als „ein Feature fehlt", sie betrifft
   mehrere der acht Pfade aus #154 fast vollständig.
2. **Rückfall in eine bereits widerlegte Begründung.** Ohne den ausdrücklichen Hinweis in
   `docs/project/04-stand.md`, dass `device-console` die Standardausgabe liest statt `os_log` (#160),
   liegt es nahe, die alte, jetzt falsche Begründung „Stufe 3 existiert wegen `device-console`"
   wiederherzustellen, sobald jemand den Abschnitt erneut umschreibt. Deshalb wird die Widerlegung
   explizit im Text verankert, nicht nur weggelassen.
3. **#154 wird durch diesen Rückbau schwächer, als am 29.09. zugesagt.** Die Zusage lautete: „Berührt
   er einen [Pfad], läuft der volle Bedienablauf." Nach diesem Rückbau läuft bei einem Treffer nur
   noch ein lesender Check plus, für Modellthemen, die Labor-App — kein Bedienablauf mehr. Das ist
   eine reale Abschwächung der Abnahmekette, nicht nur eine Umformulierung, und wird hier als solche
   benannt statt beschönigt.
4. **Der gute handwerkliche Teil geht mit unter und müsste bei #156 neu entstehen.** Zeitschranke,
   `PIPESTATUS`-Auswertung statt Pipe-Status, `deviceprep`-Code-Erkennung und die
   Belegausgabe-Konvention (`LOOSEENDS_ARTIFACT_DIR`) waren sauber gebaut und sind durch reale
   Läufe geprüft (Befund 2, Phase-2-Analyse). Ein künftiger #156-Nachfolgeversuch muss sie neu
   schreiben oder aus der Git-Historie dieses Reverts wiederherstellen (`git show
   bdab40a^..HEAD -- scripts/sim.sh` bleibt dafür auffindbar) — das ist Mehraufwand, aber kein
   Wissensverlust, weil nichts aus der Historie gelöscht wird.
5. **Die Titel/Body/DoD-Diskrepanz auf Issue #153 bleibt bis zum Abschluss bestehen**, wenn sie
   nicht nachgezogen wird (siehe „Abweichung vom Tech-Lead-Kommentar" und Definition of Done) —
   ein künftiger Leser des Issues sähe sonst „gezielte Sonden" im Titel, aber einen Rückbau ohne
   jede Sonde in der Umsetzung.

## Alternativen

- **Den Befehl behalten, aber nur nach #156 benutzen** (die Sonden-Variante aus dem
  Tech-Lead-Kommentar vom 30.09., 04:41Z): **verworfen für diesen Schnitt.** Die handwerklich guten
  Teile blieben nutzbar, aber ohne eine tatsächliche Testausführung hat keiner von ihnen einen
  Aufrufer — `device_probe_locked` und `cmd_device_test` existierten als toter, aber aufrufbarer
  Code, dessen einzige Absicherung ein Kommentar wäre („nicht vor #156 benutzen"). Genau das ist die
  Art Falle, die ein späterer, unter Zeitdruck arbeitender Aufruf übersieht — wie am 30.09. selbst
  geschehen. Wird #156 abgeschlossen, ist ein Neubau mit dem dann echten Kennungs-Kontext ohnehin
  sauberer als ein Wiederbeleben alten, nie in Produktion gelaufenen Codes.
- **Passiv zuhören statt aktiv bedienen** (`xcrun xctrace record --template Logging
  --all-processes --device <UDID>`): **verworfen für diesen Schnitt, bleibt Spike bei #143.** Am
  Werkzeug nachgeprüft (`docs/context/feat-153-geraetestufe-ui-test.md`, Abschnitt „Geprüfte
  Alternative"): `devicectl` hat kein Log-Subkommando (`device info` kennt nur `appIcon, appResize,
  appearance, apps, audio, authListing, ddiServices, details, displays, files, lockState, processes,
  voiceover`), `device-console`/`--console` liest die Standardausgabe statt `os_log`, und die App
  schreibt ausschließlich über `Logger` — der vermeintliche Kanal existiert nicht. Der tatsächlich
  funktionierende Weg über `xctrace` wurde im Projekt nie benutzt, ist schwerer zu skripten, und
  sein Zustimmungsverhalten am Gerät ist ungeklärt. Zusätzlich strukturell schwächer als ein aktiver
  Test: Abwesenheit einer Logzeile ist mehrdeutig (kaputt? nie ausgelöst? Verbindung abgerissen?
  redigiert?), und ohne Installation fehlt der Bezug zum aktuell geprüften Stand.
- **Alles so lassen und nur die Dokumentation entschärfen** (Befehl bleibt im Skript, nur
  `docs/project/04-stand.md` verliert die Empfehlung, ihn zu benutzen): **verworfen, schlechteste
  Option.** Ein Befehl, den niemand benutzen soll, aber jeder benutzen kann, bleibt benutzbar — die
  Dokumentation ist keine technische Schranke. Das ADR-11-Zusatz und der CLAUDE.md-Satz blieben
  falsch (sie behaupten weiterhin einen Smoke-Test auf dem Gerät), und der nächste Versuch, Stufe 3
  „endlich richtig" zu machen, träfe exakt denselben Fehler wie am 30.09. — nur mit noch mehr
  scheinbar fertigem Code, der zum Weiterbauen einlädt.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** ADR-11 (Ersatz des zweiten Zusatzes, keine neue Nummer)
- **Rationale:** ADR-11 („Tests") legt fest: „UI-Tests erst nach Design-Freeze und nur als
  Smoke-Tests." Das bleibt unverändert gültig. Der am 2026-09-29 angehängte Zusatz („Seit #153
  läuft mindestens ein Smoke-Test zusätzlich auf dem angeschlossenen iPhone …") wird durch diesen
  Rückbau **falsch**, nicht nur veraltet — der beschriebene Smoke-Test-Lauf auf dem Gerät existiert
  nach dieser Spec nicht mehr. Ersatztext für `docs/project/00-entscheidungen.md`, direkt im
  Anschluss an den bestehenden ADR-11-Text (Z. 135): „Auf Hennings Gerät läuft kein Testlauf und
  kein Fernstart einer App. Was sich nur auf echter Hardware zeigt, wird gemessen (Labor-App) oder
  beobachtet, nie bedient. Bedienabläufe — auch UI-Tests — bleiben im Simulator; ein Versuch, sie
  signiert auf dem Gerät zu fahren, überschrieb 2026-09-30 Hennings produktive Installation und
  bewies dabei nicht, wofür er gebaut war (#153)." Kein Ersatz für ADR-11 selbst, keine neue Nummer
  — nur ihr zweiter Zusatz wechselt zum zweiten Mal den Inhalt.

## Definition of Done

- [ ] AC-1 bis AC-13 erfüllt, jeder Befehl ausgeführt und seine Ausgabe im Abschlussbericht wörtlich
      zitiert
- [ ] `docs/project/00-entscheidungen.md`, ADR-11-Zusatz, durch den oben formulierten Ersatztext
      ersetzt
- [ ] `scripts/tests/device-test.sh` per `git rm` entfernt, `scripts/tests/` trägt keinen Eintrag
      mehr in `git ls-files`
- [ ] `./scripts/sim.sh unit` grün
- [ ] `./scripts/sim.sh test RecognitionWalkthroughTests` im Simulator grün
- [ ] `docs/project/04-stand.md`, Abschnitt „Abnahme in drei Stufen", auf `device-status` + Labor-App
      umgeschrieben, mit ausdrücklicher Nennung der Nachweislücke und der Folgetickets #156/#143/#160
- [ ] `CLAUDE.md`, Absatz zur Pfadliste, auf denselben Stand umgeschrieben (Pfadliste selbst
      unverändert)
- [ ] `docs/artifacts/feat-153-geraetestufe-ui-test/` bleibt vollständig erhalten (Belege des
      gescheiterten Versuchs, nicht Teil des Aufräumens)
- [ ] Kein Produktpfad geändert (`Shared/`, `LooseEnds/Views/` unberührt) — geprüft per `git diff
      --stat main...HEAD`
- [ ] Jeder Commit kompiliert
- [ ] Nach dem Zusammenführen: Hennings Hauptordner nachgezogen und Projekt neu erzeugt
      (`bash ~/.claude/scripts/loose-ends-sync-main.sh`)
- [ ] PR schließt #153 (`Closes #153`)
- [ ] Issue #153: Titel, Body und DoD-Liste werden beim Abschluss auf den tatsächlichen Rückbau
      nachgezogen (sie beschreiben heute noch den entfernten Aufbau bzw. „gezielte Sonden", die
      dieser Schnitt nicht liefert) — siehe „Abweichung vom Tech-Lead-Kommentar"
- [ ] #155 („Prüfstand des Gerätetest-Befehls läuft in keinem CI-Job") mit Begründung geschlossen —
      der Prüfstand, den #155 meint, existiert nach diesem Rückbau nicht mehr
- [ ] #154 bleibt offen und unverändert in seinem Anspruch; nur die Formulierung in `CLAUDE.md`, was
      bei einem Pfadtreffer läuft, ist an diesen Rückbau angepasst
- [ ] Kein manueller Testhinweis an Henning — jede Acceptance Criterion ist automatisiert oder durch
      einen protokollierten Befehl belegt
- [ ] CI grün

## Changelog

- 2026-09-30: Spec aus der Analyse „Neuschnitt nach dem echten Gerätelauf" (Phase 2,
  `docs/context/feat-153-geraetestufe-ui-test.md`) neu geschrieben und die Vorgänger-Spec vom
  2026-09-29 vollständig ersetzt — Vorzeichenwechsel von Aufbau zu Rückbau. `CLAUDE.md` als
  sechste betroffene Datei ergänzt: Sie war in der Affected-Files-Tabelle der Analyse
  (`docs/context/feat-153-geraetestufe-ui-test.md:313–321`) nicht enthalten, obwohl ihr Satz zur
  Pfadliste (Z. 81–84) denselben, jetzt entfernten Befehl `device-test` nennt — ohne diese Änderung
  verwiese die Projektregel auf einen nicht mehr existierenden Befehl. Die Abweichung vom
  Tech-Lead-Kommentar zu #153 (04:41:35Z, „gezielte Sonden statt Rückbau") wird als eigener
  Unterabschnitt unter „Purpose" offen benannt, nicht stillschweigend übergangen. Scope-Grenzen
  (4–5 Dateien, 250 LoC) werden beide gerissen (6 Dateien, 397 LoC brutto) und mit gemessenen, nicht
  geschätzten Zahlen begründet.
