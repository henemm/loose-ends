---
entity_id: fix-419-latenzschutz
type: bugfix
created: 2026-10-19
updated: 2026-10-19
status: draft
workflow: fix-419-latenzschutz
---

# Spec: #419 Latenzschutz aus #274 läuft nirgends – sein Ausfall wird laut benannt

## Approval

- [ ] Approved (Henning)

## Purpose

Die zwei Messtests in `LooseEndsTests/SpeechLatencyTests.swift` („The first word arrives within 3 s of speech start“,
„The final text keeps the key words“) schützen gegen die 12-s-Verzögerung aus #274 (fehlendes `.fastResults`). Sie laufen
nirgends: im Simulator und im CI-Job „Unit Tests (macOS destination)“ brechen beide mit `Test.cancel` ab
(„Sprache de_DE wird hier nicht unterstützt“), die Suite meldet trotzdem „passed“.

**Hat es bisher funktioniert?** Nein, nie. Die Tests liefen seit #274 (2026-10-09) nur von Hand auf Hennings Mac. Kein Rückschritt.

**Nachgestellt (2026-10-19):** CI-Lauf 39167072947 (main, 20b9553), Artefakt `TestResults`, `unit-tests.log` Z. 5249–5252:
`➜ Test "…" was cancelled after 0.003 seconds: "Sprache de_DE wird hier nicht unterstützt"`. Das ist der erste Wächter in
`measuredRun()`: `SpeechTranscriber.supportedLocale(equivalentTo: de_DE)` liefert `nil`.

**Recherche:** Apple-Forum 802969 (`supportedLocales` leer, `isAvailable == false` im Simulator), 807739/801197 (Verfügbarkeit hängt an
der Hardware). GitHub-Läufer sind virtuelle Maschinen (runner-images #9460). **Vermutung, nicht belegt:** dort ist `SpeechTranscriber`
ebenfalls leer. Belegt wird sie erst durch die Diagnosezeile aus AC-4 im nächsten CI-Lauf.

**Ohne Modell:** Kein Modell im Spiel. Der Ausfall steht im Testlog; ein Regelwerk über das Log genügt.

**Gewählter Weg („Weg B“):** Weil das CI-Umfeld das Messen sehr wahrscheinlich nicht hergibt und der Läufer nicht änderbar ist, wird der
Ausfall **laut und einzeln benannt** (wie die Messstrecken, #149), und die Diagnosezeile sagt, ob der Grund Sprache, Modell oder
Hardware ist. Liefert die Diagnose im CI wider Erwarten `de_DE`, folgt ein eigenes Ticket „Modell per `AssetInventory` vor dem Test laden“
(Weg A); diese Spec baut es nicht auf Verdacht.

**Alternativen (bewusst genannt):** (1) eigener Mac mit echter Hardware als Läufer: Tests liefen wirklich, braucht Hennings Freigabe und
kippt die Entscheidung „CI nur auf GitHub-Läufern“. (2) Messtests auf `DictationTranscriber`: läuft evtl. überall, misst aber nicht den
App-Pfad (`SpeechTranscriber` + `.fastResults`). (3) Verlegen in „Speech Stress“: läuft im selben Simulator ohne `SpeechTranscriber`, kein Ausweg.

**Offen benannt – Gegenprobe der Ticket-DoD:** „Ohne `.fastResults` wird der CI-Lauf rot“ ist im CI nicht erfüllbar, solange die Messung dort
nicht läuft. Ersatz: Der Konstantentest (`makeTranscriberReportsFastResults`) fängt das Entfernen der Option weiter in jedem Lauf;
nicht abgedeckt bleibt eine *langsamere* Erkennung bei vorhandener Option – dieser Teil schützt nur dort, wo die Messtests wirklich laufen
(Hennings Mac von Hand). Die Spec behauptet keinen Schutz, den sie nicht liefert.

## Lösung

1. `scripts/measurement_status.py` bekommt `--latency-log <Datei>`: liest das Rohlog (`unit-tests.log` bzw. `xcodebuild.log`) und bestimmt für
   die zwei Messtests je einen Zustand aus den Zeilen `✔ Test "<Name>" passed after N seconds`, `➜ Test "<Name>" was cancelled …: "<Grund>"`,
   `✘ Test "<Name>" failed` und – wenn der Test im Log gar nicht vorkommt – „nicht im Log“. Ausgabe: Zeile „Latenzschutz (#274)“, je Test
   `gemessen (passed)` oder `NICHT gemessen: <Grund>`; Markdown-Variante für die CI-Zusammenfassung.
2. `.github/workflows/ci.yml`, Schritt „Report skipped measurements“: übergibt `unit-tests.log`; bei Ausfall zusätzlich
   `::warning::Latenzschutz #274 nicht gemessen: …` (Annotation am Lauf).
3. `scripts/sim.sh`: `measurement_status` übergibt das Rohlog des Laufs (`$BUILD_LOG`), wenn es existiert.
4. `SpeechLatencyTests.swift`: im Abbruchzweig „Sprache nicht unterstützt“ trägt die Abbruchmeldung zusätzlich
   `isAvailable`, `supportedLocales.count` und `installedLocales.count`, damit die Ursache im Log und damit in der Zusammenfassung steht.
   Keine Änderung der Messlogik, keine Änderung an App-Code.

Regelweg-Vermerk: reine Textauswertung eines Logs, kein Modell.

## Acceptance Criteria

- **AC-1:** Enthält das Log für beide Messtests `was cancelled … "<Grund>"`, nennt `measurement_status.py --latency-log` beide Tests einzeln als
  „NICHT gemessen“ mit dem Grund aus dem Log; eine Gesamtzahl allein genügt nicht.
- **AC-2:** Enthält das Log `passed after N seconds` für einen Messtest, steht er als „gemessen“ in der Ausgabe; ein `failed` steht als
  „FEHLGESCHLAGEN“. Gemischte Zustände (ein Test gemessen, einer nicht) werden je Test richtig ausgegeben.
- **AC-3:** Fehlt ein Messtest im Log ganz (z. B. umbenannt, gefiltert), steht er als „NICHT gemessen: nicht im Log“, nie als gemessen und nie schweigend.
- **AC-4:** Die Abbruchmeldung „Sprache de_DE wird hier nicht unterstützt“ enthält `isAvailable`, Anzahl `supportedLocales` und Anzahl `installedLocales`;
  die Zeile erscheint im Latenzschutz-Bericht des CI-Laufs (sichtbar in der Job-Zusammenfassung).
- **AC-5:** Der CI-Schritt schreibt bei Ausfall eine Annotation `::warning::` und die Markdown-Tabelle in `GITHUB_STEP_SUMMARY`; der Lauf bleibt grün
  (der Ausfall ist Umgebung, kein Fehler), meldet aber „nicht gemessen, nicht bestanden“.
- **AC-6:** `sim.sh sim-unit`/`unit` gibt nach dem Lauf die Latenzschutz-Zeile aus (Quelle: Rohlog des Laufs); fehlt das Log, steht ein
  ausdrücklicher Hinweis statt Schweigen.
- **AC-7:** Skripttests (`scripts/test_measurement_status.py`) decken AC-1 bis AC-3 gegen echte Auszüge (der Auszug aus Lauf 39167072947 als Fixture) ab und laufen grün; die
  bestehenden Tests zu den Messstrecken bleiben grün.
- **AC-8:** Ehrlichkeit: Die Spec und der Abschlussbericht nennen, dass die Gegenprobe „ohne `.fastResults` rot“ im CI nicht erfüllt wird und welcher Teil des
  Schutzes (Konstantentest) trotzdem in jedem Lauf läuft.

## Scope

### Affected Files

| Datei | Änderung | Beschreibung |
|---|---|---|
| `scripts/measurement_status.py` | MODIFY | `--latency-log`, Zustand je Messtest, Text und Markdown |
| `scripts/test_measurement_status.py` | MODIFY | Skripttests mit Log-Auszug als Fixture |
| `.github/workflows/ci.yml` | MODIFY | Schritt übergibt das Log, Annotation bei Ausfall |
| `scripts/sim.sh` | MODIFY (klein) | `measurement_status` übergibt `$BUILD_LOG` |
| `LooseEndsTests/SpeechLatencyTests.swift` | MODIFY (klein) | Diagnosewerte in der Abbruchmeldung |

Geschätzt **+100 / −10 LoC**, 5 Dateien (Obergrenze der Scoping-Regel; Funktionen ≤ 50 LoC).

**Geräteliste (CLAUDE.md):** Kein Pfad der Geräteliste berührt. Die Abnahme endet nach Stufe 2. Nichts läuft auf Hennings Geräten.

**Side-Effects:** Keine Änderung an App-Code, Datenmodell, Berechtigungen, Info.plist, AppStorage, Audio. CI-Ausgabe bekommt eine zusätzliche Zeile/Annotation.
