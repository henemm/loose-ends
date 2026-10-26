# Abnahme und Arbeitsweise

Hierher ausgelagert aus `docs/project/04-stand.md` (aufgelöst am 2026-10-12, Henning: Priorisierung
gehört in GitHub). Die Prioritätsreihenfolge steht in den Meilensteinen M1 bis M4 des Repos, der
Funktionsstand in `docs/reference/funktionsuebersicht.md`. Verbindlich bleibt `CLAUDE.md`; diese Datei
trägt die Begründungen und die Geschichte.

## Arbeitsweise, die sich bewährt hat

- Ein Schnitt = ein PR mit reiner Logik in `Shared/Services` oder `Shared/Models` plus Unit-Tests,
  dazu die View in `LooseEnds/Views` und ein UI-Smoke-Test unter `--ui-testing`.
- Gestapelte PRs gehen, aber jede Ebene schreibt `Localizable.xcstrings` am Ende weiter; beim Zusammenführen
  nach main jede Ebene erst mit main zusammenführen (Seite des Zweigs gewinnt, sie ist die Obermenge).
- Ein `ModelContext` hält seinen `ModelContainer` nicht: in Tests `TestStore` benutzen.
- Nichts mit `try?` verschlucken, `Logger` statt `print`, Berechtigungsabfragen unter Tests aus.
- **Zwingend:** Jede Änderung zuerst selbst im Simulator laufen lassen (Build + Start + der
  betroffene Ablauf), bevor Henning gebeten wird, etwas auf seinem eigenen Gerät zu testen.
  Ursache: ein per Kommandozeile lokal signierter Build hatte eine fehlende App-Group-Berechtigung
  (`SwiftData/DataUtilities.swift:1257: Fatal error: Unable to find App Group Container in
  Entitlements`) — ungetestet an Henning weitergegeben, auf seinem Gerät reproduziert statt vorher
  im Simulator gefunden.

## Was ein grüner Test nicht beweist (#544, 2026-10-19)

Henning meldete auf dem Mac: Titel, Unteraufgaben, Datei und Foto antworten nicht. Ein eigens dafür gebauter
Klicktest war grün, und das Ticket wurde zweimal zu früh geschlossen. Was falsch lief und was seitdem gilt:

- **Die CI-App war nicht Hennings App.** Der Mac-Job signierte ad hoc und strich alle Berechtigungen; die App lief
  ohne App Sandbox. In der Sandbox öffnet macOS die Dateiauswahl nur mit `files.user-selected.read-only`, die fehlte.
  Seitdem bekommt der Klicktest die Sandbox-Schlüssel aus `project.yml` (`scripts/mac_ci_entitlements.py`). Regel:
  Ein UI-Test läuft unter den Bedingungen des Auslieferungsbaus, soweit eine Ad-hoc-Signatur sie tragen kann; was sie
  nicht tragen kann (iCloud, Push, App-Gruppe), steht als Lücke im Test.
- **Der Test klickte nicht wie ein Mensch.** Er traf die Mitte des Accessibility-Rahmens, nach Scrollen und mit dem
  Fokus schon im Detail, und kam immer aus „Neu“. Seitdem: frischer Start je Bedienelement, Klick auf die sichtbaren
  Wörter, der Weg, den Henning nimmt.
- **„Rot zuerst“ wurde nicht am gemeldeten Stand gezeigt.** Die Definition of Done verlangte einen Test, der auf dem
  Stand vor dem Fix scheitert. Gescheitert war der erste Lauf an Fehlern des Tests selbst, und das galt als Beleg.
  Regel: Der rote Lauf muss an der Stelle scheitern, die der Nutzer meldet, mit seiner Fehlermeldung, sonst ist er
  kein Beleg.
- **Geschlossen vor der Rückmeldung.** `Closes #N` schloss das Ticket beim Merge, obwohl die Abnahme auf dem Mac über
  TestFlight lief. Danach wurde Hennings Antwort falsch als Abnahme gelesen. Regel: Verlangt die Definition of Done
  eine Rückmeldung auf dem Gerät, schreibt der PR `Refs #N`, nicht `Closes #N`, und geschlossen wird erst mit seinem
  ausdrücklichen „geht“ zu jedem gemeldeten Punkt.

## Abnahme in drei Stufen

Die Reihenfolge ist verbindlich, keine Stufe wird vorgezogen. Stufe 1 und 2 werden nie
übersprungen; Stufe 3 nur, wenn der Schnitt einen Pfad der Geräteliste berührt (`CLAUDE.md`).

1. **Tests** — `./scripts/sim.sh unit` und der betroffene UI-Test müssen grün sein.
2. **Simulator** — `./scripts/sim.sh build`, `launch`, `screenshot`: der betroffene Ablauf wird
   selbst durchgespielt und belegt. Nichts geht auf das Gerät, was hier nicht bewiesen ist.
   **Übersetzen ist nicht bauen, bauen ist nicht installieren, installieren ist nicht benutzen.** Nur das Letzte
   ist die Stufe: Die App läuft im Simulator, und der geänderte Ablauf wird als Nutzer durchgespielt (#136 ging
   gebaut und installiert raus und griff ohne Apple Intelligence nie). Der Nachweis kommt aus
   `./scripts/sim.sh test-proof <Klasse>` (Beleg `simulator-run.txt` plus Screenshots). Seit #145 Schnitt 2
   verlangt `phase8_complete` diesen frischen Beleg, sobald eine Code-Datei außerhalb von `LooseEnds/Mac/` geändert
   wurde (Plugin ab 3.42.0); ein Beleg von vor der letzten Änderung zählt nicht.
3. **Hennings Gerät** — seit 2026-10-10 über TestFlight in seiner normalen App (`CLAUDE.md`, „Stufe 3
   läuft über TestFlight“). Nichts auf seinen Geräten ohne sein wörtliches „jetzt ist ein Test möglich“.

   **Vor jeder Einladungswelle** wird die Prüfliste `docs/reference/abnahme-testflight.md` auf den Build bezogen
   durchgegangen (#176). Was Henning in einem Build bestätigt hat, steht dort mit Ticket und Buildnummer; die Lücken kommen
   gebündelt in einen Prüfblock und laufen erst nach seinem wörtlichen Satz. Der PR dazu schreibt `Refs #176`, nicht
   `Closes #176`: Das Ticket bleibt offen, bis seine Rückmeldung zum Prüfblock da ist.

Die frühere Stufe 3 (`device-status` und die Labor-App) ist abgelöst. Zur Geschichte:

Stufe 3 fuhr seit #153 keinen nachgespielten Bedienablauf mehr. Der erste echte Versuch dafür —
derselbe UI-Test wie im Simulator, aber signiert auf dem Gerät — lief am 2026-09-30 zwar grün, war
dabei aber invasiv: Er überschrieb Hennings produktive Installation (gleiche Kennung
`com.henning.looseends`), die Sperr-Vorprüfung startete die App im Vordergrund und verdrängte, was
gerade lief, und das Telefon war 5–10 Minuten exklusiv belegt und musste entsperrt bleiben. Belegt
hat er dabei nichts von dem, wofür er gebaut war: Auf dem Beweisbild
(`docs/artifacts/feat-153-geraetestufe-ui-test/screenshots/`) hatte Apple Intelligence im Testlauf
nichts gesetzt — der Lauf prüfte damit dasselbe wie der Simulator, nur invasiver. Das verletzte eine
bestehende Entscheidung, die nie gekippt, sondern beim Bauen übersehen wurde, und die Festlegung,
nie eine App auf Hennings Gerät fernzustarten.

`device-status` zeigt nur, ob und wie das Gerät verbunden ist — es baut, installiert und startet
nichts. `device-console` liest die Standardausgabe (`--console`), die App schreibt aber
ausschließlich über `Logger`, nie über `print` (#160): Das Kommando hat nie gelesen, was sein
Kommentar behauptete. Gerätelogs laufen über `xctrace`.

**Die dadurch entstehende Lücke wird benannt, nicht versteckt.** Für Apple Intelligence bleibt die
Labor-App der Messweg. Für Watch, Widgets, Share, Mikrofon und Mitteilungen gibt es auf echter
Hardware keinen automatisierten Nachweis, nur Hennings Gerätetest über TestFlight. Seit #156
tragen Gerätebauten die eigene Kennung `com.henning.looseends.probe` („LE Prüfbau“) mit eigener
App-Gruppe und eigenem iCloud-Container, Hennings Installation bleibt unberührt.

**Das Modell zwischen CI und iPhone (#530, #531).** Die CI prüft die ganze Verarbeitungskette ohne
Apple Intelligence: `StubEnricher` spielt Hängen (Timeout, `ModelDeadline`), leere Antwort, Antwort je
Notiz und Guardrail-Fehler; `FoundationModelsEnricher.draft(from:)` wird ohne Modell getestet. GitHubs
macOS-Runner sind virtuelle Maschinen, auf denen sich Apple Intelligence nach bisherigem Stand nicht
einschalten lässt. Ein Apple-Silicon-Mac mit eingeschaltetem Apple Intelligence führt dasselbe
On-Device-Modell aus: `./scripts/sim.sh real-model` startet dort `RealModelTests` (setzt
`LOOSEENDS_REAL_MODEL=1`; ohne Variable überspringt die Suite sich, sie wird nie rot; mit Variable, aber
ohne Apple Intelligence, wird der erste Test rot und nennt den Grund). Sie
prüft Eigenschaften, keine Wörter: Antwort in unter 30 s, Titel vorhanden und höchstens 12 Wörter,
mindestens 80 % der Titel behalten ein Wort der Notiz. Am Ende steht ein Satz: bestanden, fehlgeschlagen
mit Grund, übersprungen oder nicht gelaufen; `scripts/real_model_result.py` liest ihn aus dem Ergebnisbündel,
nicht aus dem Log, denn Xcode 27 schreibt die Zeilen von Swift Testing nicht mehr in die Ausgabe von xcodebuild
(2026-10-20: nach „Testing started“ kam nichts, der Lauf galt fälschlich als abgebrochen). Was weiter nur das iPhone zeigt: Speicher und
Wärme unter Last, Verhalten bei gesperrtem Gerät und das Laden der Modell-Assets nach einem
iOS-Update. Die Messreihen der Labor-App laufen weiter auf dem iPhone, bis ein Mac-Lauf dieselben
Zahlen liefert.

Was Stufe 3 findet und Stufe 2 prinzipiell nicht kann: Apple Intelligence auf dem Gerät,
CloudKit-Sync zwischen Geräten, Watch, Action Button, Widgets, Mikrofon — und alles, was an
Signierung, Provisioning und Entitlements hängt (siehe den App-Group-Absturz oben).

**TestFlight war zuerst keine Stufe dieser Kette**, weil es keinen Debugger und keine Live-Logs
gibt und Crash-Reports erst mit bis zu einem Tag Verzögerung im Xcode Organizer ankommen. Seit
2026-10-10 ist es Hennings Weg für Stufe 3, weil der Test in der echten App mehr zeigt als jeder
Prüfbau; Debugger und Live-Logs liefert weiterhin nur der Simulator.

## Der Hauptcheckout hält sich selbst aktuell

Alle Sessions arbeiten in Arbeitsordnern neben dem Hauptordner, PRs werden auf GitHub zusammengeführt —
Hennings Hauptordner blieb dabei zurück, ohne dass es jemandem auffiel. Am 2026-09-19 stand er 36
Commits hinter `origin/main` und baute noch das Grundgerüst ohne Capture-Button; Henning installierte
das aufs iPhone und fand eine App ohne (+). Es dann geradezuziehen ist mühsam: Der Worktree-Zwang des
Plugins sperrt schreibende Werkzeuge im Hauptverzeichnis, und aus einem Arbeitsordner heraus sind
Git-Befehle auf den Hauptcheckout ebenfalls gesperrt.

Deshalb erledigt das ein SessionStart-Hook, der vor allen Werkzeug-Sperren läuft:
`~/.claude/scripts/loose-ends-sync-main.sh`, eingetragen in `~/.claude/settings.json`. Er springt
nur an, wenn die Sitzung zu diesem Projekt gehört, holt `origin/main` und zieht `main` per
Fast-Forward nach, erzeugt das Xcode-Projekt neu. Steht etwas im Weg — lokale Änderungen, ein anderer
Branch, kein Netz —, bleibt alles unangetastet und der Grund steht in der Ausgabe.

Das Skript liegt außerhalb des Repos, damit es nicht davon abhängt, wie alt der Checkout gerade
ist. Auf einem neuen Rechner muss es einmal neu angelegt werden.
