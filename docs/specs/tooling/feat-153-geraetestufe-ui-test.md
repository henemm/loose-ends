---
entity_id: feat-153-geraetestufe-ui-test
type: feature
created: 2026-09-29
updated: 2026-09-29
status: draft
workflow: feat-153-geraetestufe-ui-test
---

# Spec: #153 — Die Gerätestufe fährt den Bedien-Ablauf, statt nur den Start zu belegen

## Approval

- [ ] Approved

## Purpose

Stufe 3 der Abnahme (`./scripts/sim.sh device`) belegt heute nur, dass die App auf Hennings iPhone
16 Pro startet und nicht abstürzt — nicht, dass das geänderte Feature funktioniert
(`feedback-device-stage-is-ceremony`, #153). Diese Spec gibt der Gerätestufe einen neuen Befehl,
`./scripts/sim.sh device-test <Klasse[/test]>`, der einen benannten UI-Test signiert auf dem Gerät
ausführt, gesperrte oder während des Laufs gesperrte Hardware mit einer eindeutigen Meldung meldet
statt endlos zu warten, und Screenshots automatisch als Artefakt ablegt. Der als Nachweis
vorgesehene Ablauf, `RecognitionWalkthroughTests` (#144), wird dabei **modellfest** gemacht: Auf dem
Gerät läuft Apple Intelligence mit, und der unveränderte Test wird nachweislich aus einem falschen
Grund rot (Befund 1) — nicht, weil das Feature kaputt ist, sondern weil der Test einen Umschalter
für einen Setzer hält. Der letzte Punkt aus der ursprünglichen Aufgabenbeschreibung — ein
automatischer Prüfpunkt, der diesen Lauf als Nachweis annimmt — ist von Henning am 2026-09-29 nach
#145 verschoben und **nicht** Teil dieser Spec.

## Source

- **Datei:** `scripts/sim.sh`
- **Bezeichner (Vorbilder):** `cmd_device_build` (Z. 271–292, signierter Aufruf mit eigener
  Aufrufstelle und `PIPESTATUS`-Auswertung), `cmd_lab_run` (Z. 391–420, einzige heute belegte
  Sperr-Erkennung über `BSErrorCodeDescription = Locked` sowie Start/Stopp-Protokollierung),
  `cmd_test` (Z. 216–223, reiner UI-Test-Aufruf im Simulator), `acquire_lock`/`release_lock`
  (Z. 57–73, Vorbild für das neue Gerätelock)
- **Datei:** `LooseEndsUITests/RecognitionWalkthroughTests.swift`
- **Bezeichner:** `testWordEqualRecaptureTakesOverDurationAndContext` (Z. 97–158, der zu ändernde
  Ablauf), `row(containing:in:)` (Z. 50–54, wird für die Identitätsprüfung der zweiten Zeile nicht
  mehr benutzt), `launch()` (Z. 33–42, unverändert)
- **Datei:** `docs/project/04-stand.md`
- **Abschnitt:** „Abnahme in drei Stufen" (Z. 142–165)

## Dependencies

| Baustein | Art | Zweck |
|---|---|---|
| `xcodebuild test -destination "id=<UDID>"` | Werkzeug | Signierter Testlauf auf dem Gerät; wartet bei gesperrtem Telefon unbegrenzt (Befund 2), statt abzubrechen |
| `xcrun devicectl` | Werkzeug | Probestart vor dem Bau (`device_probe_locked`) und Geräteermittlung (`require_device`, unverändert) |
| `xcrun xcresulttool export attachments` | Werkzeug | Exportiert Screenshots und die Bildschirmaufzeichnung aus dem `.xcresult` (Befund 4) — ersetzt das manuelle Auslesen aus #144 |
| `FieldEditorView.contextsControl` (Z. 120–139) | Produktcode, unverändert | Liefert das Merkmal `.isSelected` (Z. 136), auf das der modellfeste Test sich stützt |
| `TaskDetailView.detailRawText` (Z. 47) | Produktcode, unverändert | Liefert die unveränderliche Rohtext-Beschriftung, über die die zweite Zeile identifiziert wird |
| `ViewRules.tasks(for: .new, …)` (Z. 16–17) | Produktcode, unverändert | Sortiert „Neu" absteigend nach Erfassungszeit — Grundlage dafür, dass die oberste Zeile immer die jüngste Erfassung ist |
| `TaskItem.displayTitle` (Z. 118–121) | Produktcode, unverändert | Zeigt mit Modell den geglätteten Titel statt des Rohtexts — der Grund, warum die alte Rohtextsuche (Befund 1, Zeile 141) bricht |
| Team `XK87E2B3VR`, Gerät `00008140-00111D582681801C` (iOS 27.0, kabelgebunden) | Umgebung | Provisioning und Zieldestination für den echten Nachweislauf |
| `docs/project/04-stand.md`, globale und Projekt-`CLAUDE.md` (dreistufige Abnahme) | Doku | Beschreiben die Kette, in die Stufe 3 neu eingeordnet wird |
| #145 (offen) | Nachfolge-Ticket | Übernimmt den automatischen Prüfpunkt, der diesen Lauf als Nachweis erzwingt — bewusst nicht Teil dieser Spec |

## Scope

### Affected Files

| Datei | Change Type | Beschreibung |
|---|---|---|
| `scripts/sim.sh` | MODIFY | Neue Funktionen `device_probe_locked`, `acquire_device_lock`/`release_device_lock`, `cmd_device_test`; Erweiterung des bestehenden `trap release_lock EXIT` auf eine gemeinsame Aufräumfunktion; Dispatch-Zeile und Hilfetext um `device-test` ergänzt |
| `LooseEndsUITests/RecognitionWalkthroughTests.swift` | MODIFY | Die drei Eingriffe aus dem Technical Approach (bedingtes Antippen, Identität über `detailRawText`, Rückkehr-Prüfung ohne erste Zeile); Kopfkommentar von „Simulator, also kein Apple Intelligence" auf „beide Stufen, mit und ohne Modell" |
| `scripts/tests/device-test.sh` | CREATE | Stub-basierte Prüfung der vier Verzweigungen aus `cmd_device_test` (Sperre vorab, `PIPESTATUS`, Zeitschranke/`deviceprep`, Screenshot-Export) ohne echtes iPhone — läuft auch in CI |
| `docs/project/04-stand.md` (Z. 142–165) | MODIFY | Abschnitt „Abnahme in drei Stufen" neu: Befehl, was er belegt, was er voraussetzt; Begründung nicht mehr über `device-console` |
| `docs/project/00-entscheidungen.md` (Z. 133–135) | MODIFY | ADR-11 („Tests") um den Ergänzungssatz zur Gerätestufe erweitert (siehe Abschnitt „Architektur-Entscheidung") — drei Zeilen, keine neue ADR-Nummer |
| `docs/artifacts/feat-153-geraetestufe-ui-test/` | CREATE (bereits angelegt) | Enthält die Belege der Analyse; nach dem echten Lauf zusätzlich `screenshots/` mit den vier benannten Aufnahmen |

Die neue Datei `scripts/tests/device-test.sh` steht nicht in der ursprünglichen Analyse (dort waren
drei geänderte Dateien plus ein neues Verzeichnis vorgesehen). Sie wird hier ergänzt, weil die
Skriptlogik in `cmd_device_test` sonst nur durch einen echten, teuren Gerätelauf geprüft werden
könnte — mit vier geänderten/neuen Dateien bleibt der Schnitt innerhalb der 4–5-Dateien-Grenze aus
CLAUDE.md.

### Estimated Changes

- Dateien: 5 geändert/neu (`scripts/sim.sh`, `RecognitionWalkthroughTests.swift`,
  `scripts/tests/device-test.sh`, `docs/project/04-stand.md`, `docs/project/00-entscheidungen.md`)
  plus 1 bereits bestehendes Artefakt-Verzeichnis — an der Obergrenze von 4–5, nicht darüber
- LoC: `scripts/sim.sh` +115/−3, `scripts/tests/device-test.sh` +85/−0,
  `RecognitionWalkthroughTests.swift` +26/−9, `docs/project/04-stand.md` +18/−11,
  `docs/project/00-entscheidungen.md` +3/−0 — zusammen +247/−23 = 270 LoC. **Das liegt 20 LoC über
  der 250er-Grenze aus CLAUDE.md.** Der Überhang ist vollständig Prüfcode ohne Produktwirkung: das
  Testskript mit sieben statt fünf Fällen (damit AC-1 und AC-7 nicht unbelegt bleiben) und der
  Zweig-Vermerk im Walkthrough (damit AC-9 prüfbar statt bloß plausibel ist). CLAUDE.md verlangt bei
  Überschreitung Stopp und Rückfrage — deshalb geht die Entscheidung an Henning, nicht an eine
  Selbstermächtigung beim Umsetzen. **Der vorgeschlagene Schnitt, falls geteilt wird:**
  `scripts/tests/device-test.sh` wandert mit AC-1 bis AC-7 in ein Folge-Ticket (−85 LoC, macht
  185 LoC), #153 liefert dann Befehl, Walkthrough-Umbau, Doku und den echten Gerätelauf
  (AC-8 bis AC-13). Der Preis dieser Teilung: Die Verzweigungen des neuen Befehls sind bis zum
  Folge-Ticket nur durch echte Geräteläufe prüfbar.
- Risiko: **Mittel**, wie in der Analyse festgestellt — kein Produktpfad wird geändert, aber der
  Nachweis hängt von fremder Hardware und einem entsperrten Telefon ab.

## Implementation Details

### 1. `cmd_device_test` — der neue Befehl

Signierter Aufruf wie `cmd_device_build`, weil `run_xcodebuild` (Z. 123–133) hart
`CODE_SIGNING_ALLOWED=NO` setzt und damit für das Gerät unbrauchbar ist. Drei neue Bausteine
kommen dazu, die es bei `cmd_device_build` nicht braucht: ein Vorab-Sperr-Check, eine Zeitschranke
mit `deviceprep`-Auswertung, und der Screenshot-Export.

```bash
MAIN_BUNDLE_ID="com.henning.looseends"
DEVICE_LOCK_DIR="$PROJECT_DIR/.claude/device_lock.d"
DEVICE_LOCK_ACQUIRED=""

acquire_device_lock() {
    local waited=0
    mkdir -p "$(dirname "$DEVICE_LOCK_DIR")"
    while ! mkdir "$DEVICE_LOCK_DIR" 2>/dev/null; do
        if [ -f "$DEVICE_LOCK_DIR/info" ]; then
            local t; t=$(head -1 "$DEVICE_LOCK_DIR/info" 2>/dev/null || echo 0)
            if [ $(( $(date +%s) - t )) -gt 600 ]; then warn "Stale Gerätelock entfernt"; rm -rf "$DEVICE_LOCK_DIR"; continue; fi
        fi
        [ $waited -ge 300 ] && { error "Gerätelock-Timeout — ein anderer Lauf belegt das iPhone."; return 1; }
        sleep 5; waited=$((waited + 5))
    done
    date +%s > "$DEVICE_LOCK_DIR/info"; echo "$SESSION_ID" >> "$DEVICE_LOCK_DIR/info"; DEVICE_LOCK_ACQUIRED=1
}
release_device_lock() { [ -n "$DEVICE_LOCK_ACQUIRED" ] && rm -rf "$DEVICE_LOCK_DIR" 2>/dev/null; DEVICE_LOCK_ACQUIRED=""; return 0; }
cleanup_locks() { release_lock; release_device_lock; }
trap cleanup_locks EXIT   # ersetzt "trap release_lock EXIT" (Z. 73)

# Schneller Sperr-Check vor dem Bau (Befund 2, Punkt 3): ein xcodebuild-Preflight meldet denselben
# Zustand erst nach dem vollständigen Bau (~3 Minuten). devicectl probiert einen Start der Haupt-App
# und meldet "Locked" in Sekunden — derselbe Weg wie in cmd_lab_run (Z. 408). Ist die App noch nicht
# installiert, meldet devicectl einen anderen Fehler; die Funktion liefert dann "nicht gesperrt",
# und die Auswertung während des Baus (unten) bleibt die eigentliche Absicherung (Befund 2, Punkt 1).
device_probe_locked() {
    local id="$1"
    local out
    out=$($DEVICECTL device process launch --terminate-existing --device "$id" "$MAIN_BUNDLE_ID" 2>&1) || true
    echo "$out" | grep -q "BSErrorCodeDescription = Locked"
}

cmd_device_test() {
    [ -z "${1:-}" ] && { error "Usage: ./scripts/sim.sh device-test Class[/test]"; return 1; }
    command -v timeout >/dev/null || { error "timeout fehlt: brew install coreutils"; return 1; }
    ensure_project
    local id; id=$(require_device) || return 1

    if device_probe_locked "$id"; then
        error "iPhone ist gesperrt — entsperren und erneut versuchen."
        return 1
    fi

    acquire_device_lock || return 1
    local dd; dd=$(device_derived_data)
    local xcresult="$dd/device-test.xcresult"
    local log="$dd/device-test.log"
    rm -rf "$xcresult"; mkdir -p "$dd"
    local timeout_s="${LOOSEENDS_DEVICE_TEST_TIMEOUT:-600}"
    info "Gerätetest ($1) auf $id, Zeitschranke ${timeout_s}s"
    cd "$PROJECT_DIR"
    local args=(test -project "$PROJECT" -scheme "$SCHEME" -destination "id=$id"
                -only-testing:"$UI_TARGET/$1" -derivedDataPath "$dd"
                -resultBundlePath "$xcresult" -allowProvisioningUpdates "DEVELOPMENT_TEAM=$TEAM_ID")
    # Zeitschranke, weil xcodebuild bei gesperrtem Gerät nicht abbricht, sondern unbegrenzt wartet
    # (Befund 2, Punkt 2). Rückgabewert über PIPESTATUS, nie über die Pipe (Lehre aus #151).
    local rc
    if command -v xcbeautify >/dev/null; then
        timeout "$timeout_s" xcodebuild "${args[@]}" 2>&1 | tee "$log" | xcbeautify
        rc=${PIPESTATUS[0]}
    else
        timeout "$timeout_s" xcodebuild "${args[@]}" 2>&1 | tee "$log"
        rc=${PIPESTATUS[0]}
    fi
    release_device_lock

    if [ "$rc" -ne 0 ]; then
        if [ "$rc" -eq 124 ] || grep -q "com.apple.dt.deviceprep Code=-3\|because the device is locked" "$log"; then
            error "Gerätetest abgebrochen — iPhone ist gesperrt oder wurde während des Laufs gesperrt."
        else
            error "Gerätetest fehlgeschlagen (xcodebuild $rc)."
        fi
        return 1
    fi

    local shots_rel="${LOOSEENDS_ARTIFACT_DIR:-docs/artifacts/device-test-$(date +%Y%m%d-%H%M%S)}/screenshots"
    mkdir -p "$PROJECT_DIR/$shots_rel"
    xcrun xcresulttool export attachments --path "$xcresult" --output-path "$PROJECT_DIR/$shots_rel" >/dev/null
    success "Gerätetest bestanden. Screenshots: $shots_rel"
}
```

Dispatch (nach `device-console)` Z. 453) und Hilfetext (Kopfkommentar Z. 23–26) bekommen je eine
Zeile für `device-test`.

**Bewusst kein Refactoring von `acquire_lock`/`release_lock` zu einer gemeinsamen, parametrisierten
Funktion.** Die beiden Lock-Paare sind fast identisch, aber `acquire_lock` wird von sieben
bestehenden Befehlen benutzt; ein Umbau auf eine gemeinsame Funktion wäre ein Drive-by-Refactoring
außerhalb dieses Tickets (CLAUDE.md, Scoping Limits) und ein Seiteneffekt-Risiko für Befehle, die mit
#153 nichts zu tun haben. Die Duplikation ist der Preis dafür.

**`LOOSEENDS_ARTIFACT_DIR` ist eine neue Umgebungsvariable, kein zweites Kommandozeilenargument.**
Die Aufgabenbeschreibung legt die Signatur auf genau ein Argument fest (`<Klasse[/test]>`). Der
Zielordner `docs/artifacts/<workflow>/` aus der Analyse setzt aber voraus, dass das Skript den
„aktuellen Workflow" kennt — dafür gibt es im Repository keinen etablierten Mechanismus (kein
Umgebungsvariable, kein Statusfile, das `sim.sh` lesen dürfte). Der Git-Zweigname ist dafür
nachweislich untauglich: Dieser Arbeitsstand trägt aktuell `fix-sim-device-false-green`, obwohl er
an #153 arbeitet (`loose-ends-worktree-branch-wiederverwendet`). Deshalb: `LOOSEENDS_ARTIFACT_DIR`
nach demselben Muster wie `LOOSEENDS_SIM`/`LOOSEENDS_DEVICE`/`LOOSEENDS_TEAM_ID` (Z. 39–42), von der
aufrufenden Workflow-Phase gesetzt (z. B.
`LOOSEENDS_ARTIFACT_DIR=docs/artifacts/feat-153-geraetestufe-ui-test`); ohne Vorgabe fällt der Befehl
auf einen zeitgestempelten Ordner zurück, der nie überschrieben wird, aber auch nicht automatisch im
richtigen Analyse-Ordner landet — das ist beim Fehlen der Variable bewusst so und wird im DoD als
manueller Schritt für den Nachweislauf benannt.

### 2. Der Walkthrough wird modellfest (drei Eingriffe in `RecognitionWalkthroughTests.swift`)

**Eingriff 1 — Schritt 3 wird bedingt (Z. 127–132).** Ersetzt das unbedingte `garden.tap()`:

```swift
let garden = app.descendants(matching: .any)
    .matching(NSPredicate(format: "label == %@", Self.contextLabel)).firstMatch
XCTAssertTrue(garden.waitForExistence(timeout: 5), "Der Editor bietet \(Self.contextLabel) nicht an")
let alreadySet = garden.isSelected
note(alreadySet ? "Schritt 3: Kontext war bereits gesetzt (Modell) — nicht angetippt"
                : "Schritt 3: Kontext war nicht gesetzt — angetippt", in: app)
if !alreadySet {
    garden.tap()
}
back(in: app)
```

`note(_:in:)` ist eine neue private Hilfsfunktion, die den genommenen Zweig als benannten Textanhang
in das Ergebnisbündel schreibt:

```swift
private func note(_ text: String, in app: XCUIApplication) {
    let attachment = XCTAttachment(string: text)
    attachment.name = "schritt3-zweig"
    attachment.lifetime = .keepAlways
    add(attachment)
}
```

**Warum das nötig ist:** Ohne diesen Vermerk beweist ein grüner Gerätelauf nicht, dass der neue
bedingte Zweig je genommen wurde — Apple Intelligence könnte den Kontext erst nach Schritt 3 setzen,
und der Test wäre grün wie vorher, ohne die Änderung überhaupt zu berühren. Der Anhang landet über
denselben `xcresulttool export attachments`-Aufruf wie die Screenshots im Artefaktordner und macht
AC-9 damit prüfbar statt bloß plausibel.

`garden.isSelected` liest den Trait, den `FieldEditorView.swift:136`
(`accessibilityAddTraits(selected ? .isSelected : [])`) setzt. Hat Apple Intelligence den Kontext
schon gesetzt (Befund 1, Screenshot `geraet-garden-schon-gesetzt.png`), bleibt der Zustand
unangetastet statt abgewählt zu werden; ohne Modell tippt der Test wie bisher an.

**Eingriff 2 — Identität über `detailRawText`, nicht über die Zeilenbeschriftung (Z. 140–143).**
Ersetzt `row(containing: Self.secondText, in: app)`:

```swift
capture(Self.secondText, in: app)
let second = topRow(in: app)
XCTAssertTrue(second.waitForExistence(timeout: 10), "Die zweite Aufgabe steht nicht in Neu")
shot(app, "3-wortgleich-erneut-erfasst")
second.tap()
let secondRawText = element("detailRawText", in: app)
XCTAssertTrue(waitForLabel(Self.secondText, of: secondRawText),
              "Die geöffnete Detailansicht zeigt nicht den zweiten Rohtext")
```

Neue private Hilfsfunktion `topRow(in:)` liefert die oberste Zeile der (absteigend nach
`capturedAt` sortierten, `ViewRules.swift:17`) „Neu"-Liste:

```swift
@MainActor
private func topRow(in app: XCUIApplication) -> XCUIElement {
    app.descendants(matching: .any)
        .matching(NSPredicate(format: "identifier BEGINSWITH %@", "taskRow_"))
        .firstMatch
}
```

`row(containing:in:)` (Z. 50–54) bleibt für Schritt 1 (`first`, Z. 106) unverändert bestehen: Der
erste Erfassungstext „Rasen mähen" ist bereits die vom Modell bevorzugte Wortreihenfolge (siehe
Kopfkommentar der Datei) und damit als Suchtext stabil; nur die zweite, absichtlich unnatürliche
Formulierung „mähen Rasen" (Befund 1, Tabelle) ist von einer Modell-Glättung betroffen.

**Eingriff 3 — Rückkehr prüft die Liste, nicht die erste Zeile (Z. 138–139).** Ersetzt
`XCTAssertTrue(first.waitForExistence(timeout: 5), "Nicht zurück in der Liste")`:

```swift
back(in: app)
let captureButton = app.buttons["captureButton"]
XCTAssertTrue(captureButton.waitForExistence(timeout: 5), "Nicht zurück in der Liste")
```

Grund (Befund 1, Tabelle, zweite Zeile): Das Öffnen der Detailansicht markiert die KI-Vermerke der
ersten Aufgabe als gesehen (`TaskDetailView.swift:98`, `markSeen()`); hat das Modell inzwischen den
Titel gesetzt, verlässt sie über `hasUnseenAIRevisions` (`ViewRules.swift:16`) die „Neu"-Liste — ein
legitimes, gewolltes Verhalten, kein Fehler. Die Zusicherung prüft deshalb nur noch, dass die
Erfassungsfläche wieder sichtbar ist.

**Kopfkommentar (Z. 1–11).** Der Satz „Simulator, also kein Apple Intelligence" wird ersetzt durch
einen Hinweis, dass der Ablauf seit #153 auf beiden Stufen läuft — mit Modell auf dem Gerät, ohne im
Simulator — und deshalb sein Ergebnis, nicht den Weg dorthin, prüft.

### 3. `scripts/tests/device-test.sh` — Stub-basierte Prüfung der Skriptlogik

Ein eigenständiges, abhängigkeitsfreies Bash-Skript (kein `bats`, keine neue Abhängigkeit). Es legt
für jeden Testfall ein leeres Verzeichnis an, stellt darin Stub-Programme namens `xcrun` und
`xcodebuild` bereit (as ausführbare Shell-Skripte), setzt `PATH="<Stub-Verzeichnis>:$PATH"` (damit
die echten `/usr/bin/xcrun`, `/usr/bin/xcodebuild` verdrängt werden, `xcbeautify` aus der
ursprünglichen `PATH` aber real durchläuft) sowie `LOOSEENDS_DEVICE=FAKE-0000` (umgeht
`require_device`, kein echtes Gerät nötig — die Tests laufen damit auch in CI), und ruft
`bash scripts/sim.sh device-test SomeClass` auf:

```bash
#!/bin/bash
# Prüft die Verzweigungen von cmd_device_test ohne echtes iPhone: Sperre vorab, PIPESTATUS,
# Zeitschranke/deviceprep, Screenshot-Export. Was das hier NICHT beweist: das tatsächliche Verhalten
# von devicectl/xcodebuild auf echter Hardware, den realen Inhalt der Screenshots, und ob "Enable UI
# Automation" gesetzt ist — das beweist ausschließlich der echte Lauf auf Hennings iPhone (AC-8).
set -euo pipefail
cd "$(dirname "$0")/../.."
FAILED=0

make_stub_dir() { mktemp -d "${TMPDIR:-/tmp}/device-test-stub.XXXXXX"; }

# xcodebuild-Stub: druckt $XCODEBUILD_STDOUT (falls gesetzt), schläft $XCODEBUILD_SLEEP Sekunden,
# beendet sich mit $XCODEBUILD_EXIT. Legt bei jedem Aufruf eine Markerdatei an, damit ein Testfall
# beweisen kann, dass xcodebuild NICHT aufgerufen wurde (Sperr-Vorabprüfung).
write_xcodebuild_stub() {
    local dir="$1"
    cat > "$dir/xcodebuild" <<'STUB'
#!/bin/bash
touch "$STUB_MARKER"
[ -n "${XCODEBUILD_STDOUT:-}" ] && echo "$XCODEBUILD_STDOUT"
[ -n "${XCODEBUILD_SLEEP:-}" ] && sleep "$XCODEBUILD_SLEEP"
exit "${XCODEBUILD_EXIT:-0}"
STUB
    chmod +x "$dir/xcodebuild"
}

# xrun-Stub: dispatcht nach devicectl (Probestart: $DEVICECTL_PROBE_LOCKED) und xcresulttool
# (Export: legt eine Datei im --output-path an, damit der Export-Test etwas vorfindet).
write_xcrun_stub() {
    local dir="$1"
    cat > "$dir/xcrun" <<'STUB'
#!/bin/bash
if [ "$1" = "devicectl" ]; then
    if [ "${DEVICECTL_PROBE_LOCKED:-0}" = "1" ]; then
        echo 'BSErrorCodeDescription = Locked'; exit 3
    fi
    echo "process launched"; exit 0
elif [ "$1" = "xcresulttool" ]; then
    for ((i=1; i<=$#; i++)); do [ "${!i}" = "--output-path" ]; j=$((i+1)); [ -n "${!j:-}" ] && mkdir -p "${!j}" && touch "${!j}/manifest.json"; done
    exit 0
fi
exit 1
STUB
    chmod +x "$dir/xcrun"
}

assert_contains() { echo "$1" | grep -qF "$2" || { echo "FAIL: '$2' fehlt in: $1"; FAILED=1; return 1; }; }

test_sperrvorabpruefung_verhindert_bau() {
    local dir; dir=$(make_stub_dir); write_xcodebuild_stub "$dir"; write_xcrun_stub "$dir"
    local marker; marker=$(mktemp -u)
    local out
    out=$(PATH="$dir:$PATH" STUB_MARKER="$marker" DEVICECTL_PROBE_LOCKED=1 LOOSEENDS_DEVICE=FAKE-0000 \
        bash scripts/sim.sh device-test SomeClass 2>&1) && { echo "FAIL: sollte scheitern"; FAILED=1; return; }
    assert_contains "$out" "iPhone ist gesperrt"
    [ -f "$marker" ] && { echo "FAIL: xcodebuild wurde trotz Sperre aufgerufen"; FAILED=1; }
}

test_pipestatus_kommt_von_xcodebuild() {
    local dir; dir=$(make_stub_dir); write_xcodebuild_stub "$dir"; write_xcrun_stub "$dir"
    local out
    out=$(PATH="$dir:$PATH" STUB_MARKER=/dev/null XCODEBUILD_EXIT=3 DEVICECTL_PROBE_LOCKED=0 \
        LOOSEENDS_DEVICE=FAKE-0000 bash scripts/sim.sh device-test SomeClass 2>&1) && { echo "FAIL"; FAILED=1; return; }
    assert_contains "$out" "xcodebuild 3"
}

test_zeitschranke_bricht_haengenden_bau_ab() {
    local dir; dir=$(make_stub_dir); write_xcodebuild_stub "$dir"; write_xcrun_stub "$dir"
    local start=$SECONDS out
    out=$(PATH="$dir:$PATH" STUB_MARKER=/dev/null XCODEBUILD_SLEEP=30 DEVICECTL_PROBE_LOCKED=0 \
        LOOSEENDS_DEVICE=FAKE-0000 LOOSEENDS_DEVICE_TEST_TIMEOUT=2 \
        bash scripts/sim.sh device-test SomeClass 2>&1) && { echo "FAIL"; FAILED=1; return; }
    [ $((SECONDS - start)) -le 5 ] || { echo "FAIL: dauerte länger als die Zeitschranke"; FAILED=1; }
    assert_contains "$out" "gesperrt oder wurde während des Laufs gesperrt"
}

test_deviceprep_code_minus3_wird_erkannt() {
    local dir; dir=$(make_stub_dir); write_xcodebuild_stub "$dir"; write_xcrun_stub "$dir"
    local out
    out=$(PATH="$dir:$PATH" STUB_MARKER=/dev/null DEVICECTL_PROBE_LOCKED=0 XCODEBUILD_EXIT=65 \
        XCODEBUILD_STDOUT='Error Domain=com.apple.dt.deviceprep Code=-3 "Unlock … because the device is locked."' \
        LOOSEENDS_DEVICE=FAKE-0000 bash scripts/sim.sh device-test SomeClass 2>&1) && { echo "FAIL"; FAILED=1; return; }
    assert_contains "$out" "gesperrt oder wurde während des Laufs gesperrt"
}

test_erfolg_exportiert_screenshots() {
    local dir; dir=$(make_stub_dir); write_xcodebuild_stub "$dir"; write_xcrun_stub "$dir"
    local shots; shots=$(mktemp -d)
    PATH="$dir:$PATH" STUB_MARKER=/dev/null DEVICECTL_PROBE_LOCKED=0 XCODEBUILD_EXIT=0 \
        LOOSEENDS_DEVICE=FAKE-0000 LOOSEENDS_ARTIFACT_DIR="$shots" \
        bash scripts/sim.sh device-test SomeClass >/dev/null 2>&1 || { echo "FAIL: sollte gelingen"; FAILED=1; return; }
    [ -f "$shots/screenshots/manifest.json" ] || { echo "FAIL: kein Export gefunden"; FAILED=1; }
}

test_ohne_argument_nutzungsmeldung() {
    local dir; dir=$(make_stub_dir); write_xcodebuild_stub "$dir"; write_xcrun_stub "$dir"
    local marker; marker=$(mktemp -u)
    local out
    out=$(PATH="$dir:$PATH" STUB_MARKER="$marker" LOOSEENDS_DEVICE=FAKE-0000 \
        bash scripts/sim.sh device-test 2>&1) && { echo "FAIL: sollte scheitern"; FAILED=1; return; }
    assert_contains "$out" "Usage: ./scripts/sim.sh device-test Class[/test]"
    [ -f "$marker" ] && { echo "FAIL: xcodebuild ohne Argument aufgerufen"; FAILED=1; }
}

test_verwaistes_geraetelock_wird_entfernt() {
    local dir; dir=$(make_stub_dir); write_xcodebuild_stub "$dir"; write_xcrun_stub "$dir"
    mkdir -p .claude/device_lock.d; echo $(( $(date +%s) - 900 )) > .claude/device_lock.d/info
    local shots; shots=$(mktemp -d)
    PATH="$dir:$PATH" STUB_MARKER=/dev/null DEVICECTL_PROBE_LOCKED=0 XCODEBUILD_EXIT=0 \
        LOOSEENDS_DEVICE=FAKE-0000 LOOSEENDS_ARTIFACT_DIR="$shots" \
        bash scripts/sim.sh device-test SomeClass >/dev/null 2>&1 \
        || { echo "FAIL: verwaistes Lock hat den Lauf blockiert"; FAILED=1; }
    [ -d .claude/device_lock.d ] && { echo "FAIL: Lock nach dem Lauf nicht freigegeben"; FAILED=1; rm -rf .claude/device_lock.d; }
}

for t in test_ohne_argument_nutzungsmeldung test_sperrvorabpruefung_verhindert_bau \
         test_pipestatus_kommt_von_xcodebuild \
         test_zeitschranke_bricht_haengenden_bau_ab test_deviceprep_code_minus3_wird_erkannt \
         test_erfolg_exportiert_screenshots test_verwaistes_geraetelock_wird_entfernt; do
    "$t"
done
[ "$FAILED" -eq 0 ] && echo "Alle Verzweigungen geprüft." || { echo "Mindestens ein Fall gescheitert."; exit 1; }
```

`LOOSEENDS_ARTIFACT_DIR` wird hier direkt als Zielpfad benutzt (nicht als übergeordneter
Workflow-Ordner), weil der Stub-Test kein `docs/artifacts/<workflow>/`-Layout braucht — nur den
Beweis, dass der Export überhaupt aufgerufen wird.

## Test Plan

### Automatisiert, ohne echtes Gerät (TDD RED, läuft auch in CI)

- **`scripts/tests/device-test.sh`** (neu, siehe Implementation Details Abschnitt 3): sieben
  Testfälle gegen `cmd_device_test` — je einer für AC-1 bis AC-7 —, jeweils über gefälschte
  `xcrun`/`xcodebuild`-Programme im `PATH` und `LOOSEENDS_DEVICE=FAKE-0000` statt echter Hardware.
  Geprüft werden Exit-Code und die wörtliche Fehlermeldung auf `stderr`, nicht Zeitverhalten der
  echten Werkzeuge. RED-Zustand: Vor der Implementierung existiert `cmd_device_test` nicht — `bash
  scripts/sim.sh device-test SomeClass` scheitert mit „Unbekannter Befehl", alle sieben Fälle
  schlagen fehl.
- **`./scripts/sim.sh test RecognitionWalkthroughTests`** (Simulator, ohne Modell): Regressionstest
  für die drei Eingriffe. Muss vor und nach der Änderung grün bleiben — ohne Modell ist
  `garden.isSelected` beim Betreten immer `false`, `first`/`topRow` liefern dieselbe Zeile, und die
  Rückkehr-Prüfung ist eine reine Abschwächung der bisherigen Zusicherung (jede grüne alte Zusage
  bleibt grün).
- **Statische Prüfung des Diffs** (AC-12): `git diff --stat` gegen `main` zeigt ausschließlich Pfade
  unter `scripts/`, `LooseEndsUITests/` und `docs/`.

### Nur durch den echten Gerätelauf belegbar

- **Ob der modellfeste Test auf echtem Silizium mit Apple Intelligence tatsächlich grün wird**
  (AC-8, AC-9): Die Stub-Tests simulieren `xcodebuild`/`devicectl`, nicht das Modellverhalten selbst.
  Ob Apple Intelligence den Kontext „Garden" wirklich vor Schritt 3 setzt und der bedingte Tap greift,
  zeigt ausschließlich `./scripts/sim.sh device-test RecognitionWalkthroughTests` auf Hennings
  iPhone.
- **Das tatsächliche Wortlaut- und Zeitverhalten von `devicectl`/`xcodebuild`** bei einem wirklich
  gesperrten oder während des Laufs gesperrten Telefon — die Stub-Programme bilden die aus Befund 2
  gemessenen Meldungen nach, garantieren aber nicht, dass Apple sie in einer künftigen Xcode-Version
  unverändert lässt.
- **Der reale Inhalt der exportierten Screenshots** (vier benannte Aufnahmen mit den richtigen
  Bildschirmzuständen) — der Stub-`xcresulttool` legt nur eine leere `manifest.json` an.
- **Ob „Enable UI Automation" weiterhin ohne Rückfrage läuft** (Befund 3) — das lässt sich nicht
  stellen, nur beobachten.

Der Nachweis für AC-8 ist eine Belegdatei aus dem echten Lauf: das `xcodebuild`-Log mit der
Zeile „Test Suite 'RecognitionWalkthroughTests' passed" und die vier Screenshots unter
`docs/artifacts/feat-153-geraetestufe-ui-test/screenshots/`.

## Acceptance Criteria

- **AC-1 Neuer Befehl mit Nutzungsmeldung:** Given kein Klassenname übergeben / When
  `./scripts/sim.sh device-test` läuft / Then bricht der Befehl mit Exit-Code 1 und der Meldung
  „Usage: ./scripts/sim.sh device-test Class[/test]" ab, ohne ein Gerät anzusprechen — geprüft in
  `test_ohne_argument_nutzungsmeldung`.
- **AC-2 Sperr-Vorabprüfung verhindert den Bau:** Given der `devicectl`-Probestart gegen die
  Haupt-App liefert `BSErrorCodeDescription = Locked` / When `cmd_device_test` läuft / Then meldet
  der Befehl „iPhone ist gesperrt — entsperren und erneut versuchen." mit Exit-Code 1, und
  `xcodebuild` wird nicht aufgerufen — geprüft in `test_sperrvorabpruefung_verhindert_bau`.
- **AC-3 Rückgabewert kommt aus `xcodebuild`, nicht aus der Pipe:** Given der `xcodebuild`-Stub
  beendet sich mit Exit 3, während `xcbeautify` real durchläuft / When `cmd_device_test` läuft /
  Then meldet der Befehl „Gerätetest fehlgeschlagen (xcodebuild 3)." mit Exit-Code 1 — geprüft in
  `test_pipestatus_kommt_von_xcodebuild`.
- **AC-4 Zeitschranke bricht ein hängendes `xcodebuild` ab:** Given der `xcodebuild`-Stub schläft
  30 Sekunden und `LOOSEENDS_DEVICE_TEST_TIMEOUT=2` / When `cmd_device_test` läuft / Then bricht der
  Lauf innerhalb von 5 Sekunden ab, nicht nach 30 — geprüft in
  `test_zeitschranke_bricht_haengenden_bau_ab`.
- **AC-5 Sperrung während des Laufs wird erkannt und benannt:** Given der `xcodebuild`-Stub druckt
  `Error Domain=com.apple.dt.deviceprep Code=-3 "… because the device is locked."` und beendet sich
  mit Exit 65 / When `cmd_device_test` läuft / Then lautet die Meldung „Gerätetest abgebrochen —
  iPhone ist gesperrt oder wurde während des Laufs gesperrt." statt der generischen
  Fehlschlag-Meldung — geprüft in `test_deviceprep_code_minus3_wird_erkannt`.
- **AC-6 Screenshots werden automatisch exportiert:** Given der `xcodebuild`-Stub meldet Erfolg
  (Exit 0) / When `cmd_device_test` mit `LOOSEENDS_ARTIFACT_DIR=<Scratch-Verzeichnis>` läuft / Then
  existiert `<Scratch-Verzeichnis>/screenshots/manifest.json` danach — geprüft in
  `test_erfolg_exportiert_screenshots`.
- **AC-7 Nur ein Gerätelauf zur Zeit, verwaistes Lock blockiert nicht dauerhaft:** Given ein
  Gerätelock-Verzeichnis `.claude/device_lock.d` mit einem 900 Sekunden alten Zeitstempel (also
  verwaist, Schwelle 600 s) / When `cmd_device_test` startet / Then entfernt der Befehl das
  verwaiste Lock, läuft durch und gibt das Lock danach wieder frei (`.claude/device_lock.d`
  existiert nach dem Lauf nicht mehr) — geprüft in `test_verwaistes_geraetelock_wird_entfernt`.
  Die Gegenrichtung (ein **frisches** Lock lässt einen zweiten Aufruf warten) wird bewusst **nicht**
  automatisiert geprüft: Der Testfall müsste fünf Minuten auf den Lock-Timeout warten oder einen
  zweiten Prozess nebenherlaufen lassen; beides ist in CI unruhig. Die Wartelogik ist Zeile für
  Zeile aus `acquire_lock` (Z. 57–73) übernommen, das sich seit Projektbeginn bewährt hat.
- **AC-8 Echter Nachweis auf Hennings iPhone (nur durch den realen Lauf belegbar):** Given Hennings
  entsperrtes iPhone 16 Pro im selben Netz / When
  `./scripts/sim.sh device-test RecognitionWalkthroughTests` läuft / Then endet der Lauf mit
  Exit-Code 0, das Log enthält wörtlich „Test Suite 'RecognitionWalkthroughTests' passed", und
  `docs/artifacts/feat-153-geraetestufe-ui-test/screenshots/` enthält die vier benannten Aufnahmen
  (`1-erste-aufgabe-erfasst`, `2-werte-von-hand-gesetzt`, `3-wortgleich-erneut-erfasst`,
  `4-zweite-aufgabe-mit-uebernommenen-werten`).
- **AC-9 Der Walkthrough bleibt modellfest, und welcher Zweig lief, ist belegt:** Given derselbe
  Testcode läuft einmal mit Modell (Gerät) und einmal ohne (Simulator) / When Schritt 3 den Kontext
  „Garden" behandelt / Then liegt im Artefaktordner jedes Laufs ein Textanhang `schritt3-zweig`, der
  wörtlich benennt, welcher der beiden Zweige genommen wurde, und beide Läufe sind grün. Der
  Simulator-Lauf muss „Kontext war nicht gesetzt — angetippt" zeigen (kein Modell vorhanden); der
  Gerätelauf zeigt je nach Zeitverhalten des Modells den einen oder den anderen Zweig — zeigt er
  „nicht angetippt", ist der neue bedingte Zweig damit auf echter Hardware nachweislich gelaufen.
  Zeigt er über drei aufeinanderfolgende Läufe ausschließlich „angetippt", greift Apple Intelligence
  später als in Befund 1 gemessen; dann ist der bedingte Zweig auf dem Gerät unbelegt, und das ist
  im Abschlussbericht so zu benennen statt als grün durchzuwinken.
- **AC-10 Identität über den Rohtext, nicht über die Zeilenbeschriftung:** Given das Modell glättet
  den zweiten Erfassungstext zu einem anderen Titel / When der Test die zweite Zeile identifiziert /
  Then geschieht das über die oberste Zeile der absteigend nach Erfassungszeit sortierten
  „Neu"-Liste (`topRow`) und den Abgleich mit `detailRawText`, nicht über eine Labelsuche nach dem
  Rohtext — belegt durch den geänderten Testcode und den grünen Gerätelauf (AC-8).
- **AC-11 Rückkehr in die Liste prüft die Liste, nicht die erste Zeile:** Given die erste Aufgabe
  verliert nach dem Öffnen ihren Sichtbarkeits-Filter, weil das Modell den Titel gesetzt hat
  (`hasUnseenAIRevisions` wird `false`) / When Schritt 4 „zurück" tippt / Then prüft die Zusicherung,
  dass die Erfassungsfläche (`captureButton`) wieder sichtbar ist, nicht dass die erste Zeile noch
  existiert — belegt durch den geänderten Testcode und AC-8.
- **AC-12 Kein Produktpfad angefasst:** Given der fertige Diff gegen `main` / When
  `git diff --stat main...HEAD` geprüft wird / Then liegen alle geänderten Dateien unter `scripts/`,
  `LooseEndsUITests/` oder `docs/` — kein Pfad unter `Shared/` oder `LooseEnds/Views/`.
- **AC-13 Dokumentation der dritten Stufe aktualisiert:** Given `docs/project/04-stand.md` / When
  der Abschnitt „Abnahme in drei Stufen" gelesen wird / Then nennt er
  `./scripts/sim.sh device-test <Klasse[/test]>` als Stufe 3, begründet ihre Existenz mit dem
  gefahrenen Ablauf statt mit `device-console`, und benennt die Meldung, die ein gesperrtes Telefon
  liefert.

## Risiken

1. **Der modellfeste Test kann trotzdem unruhig werden**, wenn Apple Intelligence den Kontext
   manchmal setzt und manchmal nicht (zeitliches Wettrennen zwischen Veredelung und Testschritt).
   Gegenmaßnahme: `waitForLabel` wartet bereits auf das Ergebnis, nicht auf einen festen Zeitpunkt;
   bleibt der Lauf trotzdem unruhig, ist die in der Analyse genannte Alternative „Modell per
   Startargument abschalten" (`--no-model`) der dokumentierte Rückfall — kein neuer Weg, sondern der
   bereits geprüfte und bewusst nicht gewählte.
2. **Der Sperr-Vorabcheck startet die Haupt-App auf Hennings iPhone als Seiteneffekt** (Befund 2,
   Ansatz „derselbe Weg wie `cmd_lab_run`"), auch wenn das Telefon entsperrt ist — verdrängt eine
   andere gerade offene App in den Vordergrund. Vertretbar, weil ein Gerätetestlauf das Telefon
   ohnehin exklusiv belegt (Risiko 5 aus der Analyse), aber ein spürbarer Unterschied zu
   `cmd_device_build`, das nichts startet.
3. **Ist die Haupt-App auf dem Gerät noch nicht installiert, erkennt der Vorabcheck keine Sperre**
   (er sieht einen anderen `devicectl`-Fehler, keinen „Locked"-Treffer) und der Bau läuft trotzdem
   an. Die während des Baus laufende `deviceprep`-Auswertung bleibt in diesem Fall die einzige
   Absicherung — dokumentiert im Code-Kommentar zu `device_probe_locked`, kein stiller Blindspot.
4. **`LOOSEENDS_ARTIFACT_DIR` ist neu und wird von keinem bestehenden Aufrufer gesetzt.** Ohne
   diese Variable legt der Befehl Screenshots in einem zeitgestempelten Ordner statt im
   Analyse-Ordner des Tickets ab. Für den in AC-8 verlangten Nachweis muss die Variable beim realen
   Lauf explizit gesetzt werden — als Schritt in der Definition of Done festgehalten, nicht der
   Erinnerung überlassen.
5. **`-resultBundlePath` kollidiert, wenn ein vorheriger Lauf im selben `DEVICE_DERIVED_DATA`
   abgebrochen wurde und die `.xcresult`-Datei stehen blieb.** Gegenmaßnahme: `rm -rf "$xcresult"`
   direkt vor jedem Lauf.
6. **`xcrun xcresulttool export attachments` ist kein von Apple vertraglich stabil dokumentiertes
   Format** — eine künftige Xcode-Version könnte die `manifest.json`-Struktur ändern. Nur der echte
   Lauf zeigt, ob der Export weiterhin die erwarteten Dateien liefert; die Stub-Tests prüfen nur,
   dass der Aufruf mit den richtigen Argumenten geschieht.
7. **Ein abgebrochener Gerätetestlauf könnte das neue Gerätelock verwaist zurücklassen**, wenn der
   Prozess zwischen `acquire_device_lock` und `release_device_lock` hart beendet wird (z. B. Ctrl-C).
   Gegenmaßnahme: derselbe Stale-Lock-Mechanismus wie beim Simulator-Lock (600 Sekunden), plus der
   gemeinsame `trap cleanup_locks EXIT`.
8. **Duplizierte Lock-Logik statt einer gemeinsamen Funktion** (bewusste Entscheidung, siehe
   Implementation Details) bedeutet: eine künftige Änderung an der Lock-Semantik (z. B. andere
   Zeitschranke) muss an zwei Stellen gepflegt werden. Akzeptiert, um kein Drive-by-Refactoring
   einzuführen.
9. **Der Nebenbefund der doppelten Kontextliste** (Englisch/Deutsch nebeneinander im
   Beweis-Screenshot) ist nicht Teil dieser Spec und bleibt in künftigen Screenshots sichtbar; er
   wird laut Analyse als eigenes Issue verfolgt, sobald außerhalb des Testlaufs bestätigt.

## Alternativen

- **Modell per Startargument abschalten** (`--no-model`, `FoundationModelsEnricher` meldet „nicht
  verfügbar"): deterministisch und billig, aber die Gerätestufe belegt dann genau das nicht mehr,
  wofür sie laut Aufgabenbeschreibung existiert — Verhalten mit vorhandenem Apple Intelligence. Sie
  wäre ein zweiter Simulator auf teurer Hardware. **Bleibt als Rückfall**, falls der modellfeste
  Ablauf sich als unruhig erweist (siehe Risiko 1).
- **Eigener Gerätetest, der das Modell erwartet** (z. B. „nach dem Erfassen steht ein Kontext
  dran"): verworfen. Misst das Modell statt das Feature; das Modell ist nicht deterministisch, der
  Test würde sporadisch rot und damit wertlos. „Regeln vor Modell" gilt auch für Zusicherungen.
- **Denselben Test unverändert fahren:** verworfen, gemessen rot (Befund 1) — falsches Rot bei
  funktionierendem Feature, ebenso wertlos wie das falsche Grün, das die alte Gerätestufe erzeugte.
- **`bats-core` als Test-Framework für die Skriptlogik statt eines eigenen Bash-Skripts:** verworfen.
  Sauberere Testsyntax, aber eine neue Abhängigkeit (CLAUDE.md: „Keine neuen Dependencies ohne
  explizite Freigabe") mit einem zusätzlichen `brew install`-Schritt an vier bereits duplizierten
  Stellen in `.github/workflows/ci.yml`. Der Nutzen rechtfertigt diesen Eingriff nicht.
- **Gar keine automatisierten Tests für die Skriptlogik, nur der reale Gerätelauf:** verworfen. Die
  vier Verzweigungen (Sperre vorab, `PIPESTATUS`, Zeitschranke/`deviceprep`, Export) wären dann nie
  ohne Hennings iPhone prüfbar — jede künftige Änderung an `cmd_device_test` bräuchte zwingend einen
  Gerätelauf, nur um zu sehen, ob sie überhaupt die richtige Verzweigung trifft.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** ADR-11 (Ergänzung, keine neue Nummer)
- **Rationale:** ADR-11 („Tests", `docs/project/00-entscheidungen.md` Z. 133–135) legt heute fest:
  „UI-Tests erst nach Design-Freeze und nur als Smoke-Tests." Die Aussage bleibt gültig — der
  Umfang der UI-Tests wächst mit #153 nicht, es kommt kein einziger neuer Testfall dazu. Was sich
  ändert, ist allein der **Ort**, an dem ein bereits bestehender Smoke-Test läuft: zusätzlich zum
  Simulator auch auf echter Hardware, als dritte Abnahmestufe. Das ist kein neuer
  Architekturbaustein, sondern eine zweite Destination für denselben Test, und es zieht eine
  Zusage nach sich, die bisher nirgends stand: Ein UI-Test, der als Gerätestufe taugt, muss sein
  **Ergebnis** prüfen, nicht den Weg dorthin — auf dem Gerät läuft Apple Intelligence mit und setzt
  Felder, die im Simulator leer bleiben. Ergänzungssatz für `docs/project/00-entscheidungen.md`,
  direkt im Anschluss an den bestehenden Text zu ADR-11 (Z. 135): „Seit #153 läuft mindestens ein
  Smoke-Test zusätzlich auf dem angeschlossenen iPhone (`./scripts/sim.sh device-test <Klasse>`) und
  bildet dort die dritte Abnahmestufe. Weil auf dem Gerät Apple Intelligence mitläuft, prüfen
  Zusicherungen dieser Tests den Endzustand (steht der Kontext dran?) und nie den Bedienweg (habe
  ich ihn angetippt?) — ein Umschalter, den das Modell schon gesetzt hat, würde sonst abgewählt."
  Kein Ersatz für ADR-11, keine neue Nummer.

## Definition of Done

- [ ] AC-1 bis AC-13 erfüllt, belegt durch die im Test Plan genannten Tests bzw. den echten Lauf
- [ ] `docs/project/00-entscheidungen.md`, ADR-11, um den Ergänzungssatz erweitert
- [ ] Der Textanhang `schritt3-zweig` liegt im Artefaktordner beider Läufe (Simulator und Gerät) und
      wird im Abschlussbericht wörtlich zitiert — auch dann, wenn er auf dem Gerät „angetippt" zeigt
      und der bedingte Zweig damit unbelegt bleibt (AC-9)
- [ ] `scripts/tests/device-test.sh` grün, ohne echtes iPhone, auch in CI lauffähig
- [ ] `./scripts/sim.sh unit` und `./scripts/sim.sh build` weiterhin grün (kein Produktpfad
      geändert, aber die Bauzeit muss stehen bleiben)
- [ ] `./scripts/sim.sh test RecognitionWalkthroughTests` im Simulator grün (Regressionstest ohne
      Modell)
- [ ] Echter Lauf auf Hennings iPhone: `LOOSEENDS_ARTIFACT_DIR=docs/artifacts/feat-153-geraetestufe-ui-test
      ./scripts/sim.sh device-test RecognitionWalkthroughTests` endet mit Exit-Code 0, die vier
      Screenshots liegen unter `docs/artifacts/feat-153-geraetestufe-ui-test/screenshots/`
- [ ] `docs/project/04-stand.md`, Abschnitt „Abnahme in drei Stufen", auf den neuen Befehl
      umgeschrieben (AC-13)
- [ ] Kein Produktpfad geändert (`Shared/`, `LooseEnds/Views/` unberührt) — geprüft per `git diff --stat`
- [ ] Jeder Commit kompiliert
- [ ] Nach dem Zusammenführen: Hennings Hauptordner nachgezogen und Projekt neu erzeugt
      (`bash ~/.claude/scripts/loose-ends-sync-main.sh`)
- [ ] PR schließt #153 (`Closes #153`)
- [ ] Der letzte Punkt aus der ursprünglichen Aufgabenbeschreibung (automatischer Prüfpunkt, der
      diesen Lauf als Nachweis annimmt) ist **nicht** Teil dieser Abnahme — er ist als Schnitt bei
      #145 vermerkt
- [ ] Kein manueller Testhinweis an Henning — jede Acceptance Criterion ist automatisiert oder durch
      einen registrierten Lauf bewiesen
- [ ] CI grün

## Changelog

- 2026-09-29: Spec aus der Analyse-Zusammenfassung (Phase 2, #153) erstellt. Ergänzt gegenüber der
  Analyse: eine vierte Datei, `scripts/tests/device-test.sh`, für die stub-basierte Prüfung der
  Skriptlogik ohne echtes Gerät (die Analyse hatte nur den echten Lauf als Nachweisweg benannt); die
  neue Umgebungsvariable `LOOSEENDS_ARTIFACT_DIR`, weil die Befehlssignatur auf ein Argument
  festgelegt ist, das Skript den „aktuellen Workflow" für den Zielordner aber sonst nicht kennen
  kann.
- 2026-09-29: Abschnitt „Architektur-Entscheidung (ADR)" nachgetragen (Befund der Spec-Validierung).
  ADR-11 („Tests") wird ergänzt statt ersetzt: Der Umfang der UI-Tests wächst nicht, nur ihr
  Laufort, und die Zusicherungen prüfen künftig den Endzustand statt den Bedienweg. Dadurch fünfte
  geänderte Datei (`docs/project/00-entscheidungen.md`, +3 Zeilen), Schätzung 233 → 236 LoC.
- 2026-09-29: AC-1 und AC-7 hatten keinen benannten Testfall, obwohl die Definition of Done für alle
  ACs einen Beleg behauptete (Befund des PO-Briefings). Zwei Testfälle ergänzt
  (`test_ohne_argument_nutzungsmeldung`, `test_verwaistes_geraetelock_wird_entfernt`); AC-7
  umformuliert, weil nur die Verwaist-Richtung sinnvoll automatisierbar ist und die Warte-Richtung
  fünf Minuten Laufzeit kosten würde — die Einschränkung steht jetzt offen im AC statt verdeckt.
  Schätzung dadurch 236 → 256 LoC.
- 2026-09-29: AC-9 war nicht prüfbar (Befund des PO-Briefings): Ein grüner Gerätelauf hätte nicht
  gezeigt, ob der neue bedingte Zweig überhaupt genommen wurde — setzt Apple Intelligence den
  Kontext erst nach Schritt 3, wäre der Test grün wie vorher, ohne die Änderung zu berühren. Der
  Test schreibt den genommenen Zweig jetzt als Textanhang `schritt3-zweig` ins Ergebnisbündel; AC-9
  fordert diesen Anhang und benennt ausdrücklich den Fall, in dem der Zweig auf dem Gerät unbelegt
  bleibt. Schätzung 256 → 270 LoC, damit 20 LoC über der Grenze — Entscheidung über Teilen oder
  Überziehen liegt beim PO, Schnittvorschlag in „Estimated Changes".
