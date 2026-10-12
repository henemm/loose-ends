---
entity_id: fix-311-kvstore-entitlement
type: bugfix
created: 2026-10-12
updated: 2026-10-12
status: draft
workflow: fix-311-kvstore-entitlement
---

# Spec: #311 — Uhrzeit der Mitteilung gleicht sich zwischen Geräten nicht ab (Schlüssel fehlt in den TestFlight-Bauten)

## Approval

- [ ] Approved (Henning)

## Purpose

Henning (Issue #311, 2026-10-10): Die Uhrzeit für Aufgaben ohne Fälligkeitszeit „muss einstellbar sein“ und auf allen
Geräten gleich gelten (PO-Entscheidung: Abgleich über iCloud). Gerätetest Build 29 (2026-10-11): Die Mitteilung kommt an.
Prüfschritt 3 („Uhrzeit auf dem iPhone ändern, auf dem Mac steht nach kurzer Zeit dieselbe Uhrzeit“) ist offen.

**Hat es bisher funktioniert?** Nicht belegt. Der Abgleich wurde nie bestätigt. Die Einstellung selbst wirkt lokal; dass der
Abgleich in TestFlight-Bauten seit Build 29 nicht greift, folgt aus dem Ablauf (siehe Root Cause), nicht aus einer Messung
am Archiv. Es ist also keine belegte Verschlechterung.

### Root Cause (belegt, nachgestellt)

`DueNotificationCenter` gleicht die Uhrzeit über `NSUbiquitousKeyValueStore` ab
(`LooseEnds/Notifications/DueNotificationCenter.swift:39, 59–63, 250–256`). Das System lässt den Speicher nur zu, wenn die
App den Schlüssel `com.apple.developer.ubiquity-kvstore-identifier` trägt (Apple-Forum:
https://developer.apple.com/forums/thread/741162).

Der Schlüssel steht seit c846dcf (#313) in der eingecheckten `LooseEnds/LooseEnds.entitlements`, aber **nicht** in
`project.yml` (Ziel `LooseEnds`, `entitlements.properties`, Z. 49–59). Diese Datei wird bei jedem `xcodegen generate` aus
`project.yml` neu geschrieben (XcodeGen: `project.yml` ist die Quelle). Der TestFlight-Workflow generiert vor dem Archiv
(`.github/workflows/testflight.yml`, „Generate project“), sein Prüfschritt kennt keine Berechtigungen.

Nachgestellt (2026-10-12, frischer Arbeitsordner auf `main`): `./scripts/sim.sh generate`, danach
`git diff LooseEnds/LooseEnds.entitlements` — genau die zwei Zeilen des Schlüssels sind gelöscht, sonst ändert sich nichts.
Hennings Hauptordner zeigt dieselbe Abweichung (`M LooseEnds/LooseEnds.entitlements`).

Vergleich aller Ziele (`project.yml` gegen eingecheckte Dateien): Watch, Widgets, Share stimmen überein, nur `LooseEnds`
weicht ab, und zwar um diesen einen Schlüssel.

### Signierrisiko (geklärt, Rest offen)

Beim Widget hat die Cloud-Signierung der CI eine neue iCloud-Fähigkeit nicht vergeben können (#312). Hier ist es anders:
Die lokal abgelegten Profile für `com.henning.looseends` (iOS und Mac) enthalten den Schlüssel bereits
(`XK87E2B3VR.*`), die Profile des Widgets ohne iCloud nicht. Der Schlüssel hängt an der iCloud-Fähigkeit der Haupt-Kennung,
die besteht. **Nicht belegt:** das App-Store-Profil, das die Cloud-Signierung beim Archiv erzeugt. Das zeigt der erste
TestFlight-Lauf nach der Änderung (AC-4).

### Lösung

1. `project.yml`: unter `entitlements.properties` des Ziels `LooseEnds` die Zeile
   `com.apple.developer.ubiquity-kvstore-identifier: $(TeamIdentifierPrefix)$(CFBundleIdentifier)`.
   Die erzeugte Datei entspricht danach der eingecheckten; `LooseEnds.entitlements` selbst bleibt unverändert.
2. Neuer Skripttest `scripts/test_entitlements_sync.py` (läuft in der CI im ersten, billigen Schritt „Script tests“):
   liest `project.yml` und jede dort genannte `.entitlements`-Datei und verlangt, dass die Schlüssel und Werte beider
   Seiten gleich sind. Ändert künftig jemand eine Seite allein, wird die CI rot, bevor Xcode startet.
3. `testflight.yml`, Schritt „Verify the archive“: nach den Bundle-Prüfungen liest `codesign -d --entitlements :-` die
   signierten Berechtigungen der Haupt-App im Archiv; fehlt der Schlüssel, bricht der Schritt ab, **vor** dem Upload.

Regelweg-Vermerk (Regeln vor Modell): Kein Modell beteiligt; Konfiguration und Prüfung.

## Source

- **Geändert:** `project.yml` (eine Zeile)
- **Neu:** `scripts/test_entitlements_sync.py`
- **Geändert:** `.github/workflows/testflight.yml` (Prüfschritt)

## Scope

### Affected Files

| Datei | Änderung | Beschreibung |
|---|---|---|
| `project.yml` | MODIFY | Schlüssel `com.apple.developer.ubiquity-kvstore-identifier` beim Ziel `LooseEnds` |
| `scripts/test_entitlements_sync.py` | CREATE | `project.yml` gegen die eingecheckten `.entitlements`-Dateien, je Ziel gleiche Schlüssel und Werte |
| `.github/workflows/testflight.yml` | MODIFY | Archivprüfung: signierte Berechtigungen der Haupt-App enthalten den Schlüssel |

Geschätzt **+60 / −0 LoC**, 3 Dateien, innerhalb der Scoping-Limits.

**Geräteliste berührt:** `project.yml`, `LooseEnds/LooseEnds.entitlements` (durch den Schlüssel wirksam, Datei selbst
unverändert). Stufe 3 (TestFlight, Hennings Geräte) ist Pflicht, **nur nach seinem wörtlichen „jetzt ist ein Test
möglich“**.

**Side-Effects:** Die App bekommt zur Laufzeit den iCloud-Key-Value-Speicher (Mac und iOS, dieselbe Berechtigungsdatei).
Keine Änderung an Info.plist, AppStorage-Schlüsseln, Datenmodell oder Texten. Widget, Share und Watch bekommen den Schlüssel
nicht. Hennings Hauptordner zeigt danach kein geändertes `LooseEnds.entitlements` mehr.

### Nicht in diesem Ticket

- Erzeugte Berechtigungsdateien aus der Versionsverwaltung nehmen (beseitigt die Klasse „zwei Quellen“ ganz, fasst aber
  alle Ziele an; als Folge-Ticket denkbar).
- Die Einstellung als Datensatz im Datenmodell statt im Key-Value-Speicher (nur Rückfall, siehe Alternativen).
- Alle übrigen offenen Punkte von #311 (Schritt 1 und 2 der Prüfung sind unabhängig davon).

## Test Plan

### Automated Tests (TDD RED zuerst)

`scripts/test_entitlements_sync.py` (`unittest`, PyYAML wie `test_ci_xcode27.py`):

- `test_every_target_matches_its_committed_entitlements`: für jedes Ziel mit `entitlements.path` in `project.yml` sind die
  Schlüssel und Werte aus `entitlements.properties` gleich dem Inhalt der Datei. **RED vor dem Fix:** `LooseEnds` meldet
  den Schlüssel `com.apple.developer.ubiquity-kvstore-identifier` als „nur in der Datei“. **GRÜN nach dem Fix.**
- `test_mismatch_is_reported`: eine nachgebaute Abweichung (Schlüssel nur in der Datei, Wert verschieden, Schlüssel nur
  in `project.yml`) wird je mit Schlüsselnamen gemeldet. Belegt, dass der Vergleich nicht stumm grün bleibt.
- `test_kvstore_key_is_declared_for_the_app`: das Ziel `LooseEnds` trägt den Schlüssel in `project.yml`
  (nutzt dieselbe Lesefunktion; hält die Absicht fest, nicht nur die Gleichheit).

Archivprüfung (`testflight.yml`) hat keinen Unit-Test; ihre Logik wird lokal an einer Simulator-App belegt:
`codesign -d --entitlements :-` auf eine mit `./scripts/sim.sh build` gebaute App zeigt den Schlüssel nach dem Fix,
nicht vor dem Fix (Beleg im Artefaktordner). Ob die Cloud-Signierung ihn im echten Archiv erhält, zeigt AC-4.

Bestehende Skripttests und der volle Lauf `./scripts/sim.sh unit` bleiben grün.

### Abnahme (Stufen)

1. **Tests:** `python3 -m unittest scripts/test_entitlements_sync.py` rot (vorher), grün (nachher); `./scripts/sim.sh unit`
   grün.
2. **Simulator:** `./scripts/sim.sh generate`, danach `git diff LooseEnds/LooseEnds.entitlements` leer;
   `./scripts/sim.sh build`, Berechtigungen der gebauten App ausgelesen (Schlüssel vorhanden). Der Abgleich zwischen zwei
   Geräten ist im Simulator nicht darstellbar.
3. **Gerät (Pflicht, `project.yml` und `*.entitlements` stehen auf der Geräteliste):** über TestFlight. Erst wenn Henning
   wörtlich „jetzt ist ein Test möglich“ geschrieben hat. Dann bekommt er Buildnummer und Prüfschritte; seine Rückmeldung
   schließt den Punkt.

## Acceptance Criteria

- **AC-1 Quelle:** Given `project.yml` / When `xcodegen generate` läuft / Then entspricht `LooseEnds/LooseEnds.entitlements`
  der eingecheckten Fassung (`git diff` leer), und der Schlüssel `com.apple.developer.ubiquity-kvstore-identifier` mit dem
  Wert `$(TeamIdentifierPrefix)$(CFBundleIdentifier)` steht in beiden.
- **AC-2 Test:** Given der Skripttest / When er auf dem Stand vor der Änderung läuft / Then schlägt er mit dem Schlüsselnamen
  fehl; nach der Änderung besteht er. Er läuft in der CI im Schritt „Script tests“.
- **AC-3 Archivprüfung:** Given ein Archiv, dessen Haupt-App den Schlüssel nicht trägt / When der Schritt „Verify the
  archive“ läuft / Then bricht er mit einer Fehlermeldung ab, die den Schlüssel nennt, vor „Upload to TestFlight“. Given ein
  Archiv mit Schlüssel / Then bleibt der Schritt grün. Die Prüflogik ist an einer gebauten App belegt.
- **AC-4 Signierung:** Given der Stand mit dem Schlüssel / When der TestFlight-Workflow läuft / Then signiert die Cloud-
  Signierung die Haupt-App mit dem Schlüssel, die Archivprüfung (AC-3) ist grün und der Bau erscheint als VALID. Verweigert
  sie den Schlüssel, wird der Rückfall (Alternative 3) neu bewertet; der Fix wird nicht mit abgeschwächter Prüfung
  ausgeliefert.
- **AC-5 Nichts sonst:** Der Diff berührt nur die drei genannten Dateien; die Berechtigungen von Watch, Widget und Share
  sind unverändert; alle bestehenden Tests grün.
- **AC-6 Gerät:** Nach Hennings ausdrücklicher Freigabe: Uhrzeit auf dem iPhone ändern, auf dem zweiten Gerät (Mac oder
  iPad) steht nach kurzer Zeit dieselbe Uhrzeit (#311 Schritt 3). #311 wird erst nach seiner Bestätigung geschlossen.

## Dependencies

| Komponente | Beschreibung |
|---|---|
| XcodeGen | erzeugt `.entitlements` aus `project.yml` |
| Cloud-Signierung der CI (ASC-Schlüssel) | muss das Profil der Haupt-App mit dem Schlüssel erzeugen |
| `DueNotificationCenter` | einziger Nutzer von `NSUbiquitousKeyValueStore`, unverändert |
| PyYAML | wie in `test_ci_xcode27.py`, in der CI-venv vorhanden |

Keine neue Abhängigkeit.

## Risiken

- **Signierung (mittel):** Das App-Store-Profil der Cloud-Signierung könnte den Schlüssel nicht tragen. Gegenmittel:
  Archivprüfung stoppt vor dem Upload, Rückfall auf Alternative 3. Ein fehlgeschlagener Lauf lädt nichts hoch.
- **Wert des Schlüssels (niedrig):** `$(TeamIdentifierPrefix)$(CFBundleIdentifier)` folgt der Kennung, auch bei der
  Prüfkennung (`BUNDLE_ID_SUFFIX`). Das Profil lässt `XK87E2B3VR.*` zu, der Wert passt darunter.
- **Test zu streng (niedrig):** Falls XcodeGen künftig weitere Schlüssel selbst in die Datei schreibt, würde der Vergleich
  rot. Gegenmittel: heute stimmen alle drei übrigen Ziele überein; der Test nennt die abweichenden Schlüssel, die
  Anpassung ist lokal.
- **Der Simulator ersetzt den Abgleich nicht:** Zwei echte Geräte sind nötig (AC-6).

## Alternativen

- **Erzeugte Berechtigungsdateien nicht mehr einchecken:** beseitigt die Ursachenklasse, größerer Eingriff (alle Ziele,
  Hooks und Skripte, die sie lesen). Als Folge-Ticket denkbar. Kippt keine ADR.
- **Einstellung als Datensatz im vorhandenen Datenmodell:** braucht keine Berechtigung, aber eine Schemaänderung in
  CloudKit Production (additiv; `mac-schema-init` und Deploy) und kippt die Entscheidung vom 2026-10-10 (Key-Value-Speicher,
  neue Berechtigung). Nur Rückfall, falls AC-4 scheitert.
- **Nur lokal je Gerät, ohne Abgleich:** kippt die Festlegung „auf allen Geräten gleich“. Verworfen.
- **Stattdessen im CI nur `git diff --exit-code` nach `generate`:** läuft im teureren Job und verlangt, dass erzeugte
  Dateien eingecheckt bleiben; der Skripttest läuft zuerst, ohne Xcode, und nennt den Schlüssel. Verworfen.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — Grund: Fehlerbehebung an Konfiguration und CI-Prüfung, keine Architekturentscheidung

## Definition of Done

- AC-1 bis AC-6 erfüllt; `test_entitlements_sync.py` zuerst rot (Schlüssel im Protokoll), dann grün; alle bestehenden Tests
  grün.
- Der erste TestFlight-Lauf nach dem Zusammenführen ist grün, die Archivprüfung zeigt den Schlüssel im Protokoll.
- `./scripts/sim.sh generate` hinterlässt kein geändertes `LooseEnds.entitlements`.
- Geräteabnahme nur nach Hennings wörtlichem „jetzt ist ein Test möglich“; Rückmeldung zu Schritt 3 schließt #311.
- Der PR verweist mit `Refs #311` (nicht `Closes`).
- Abschlussbericht ohne Git-Vokabular: Der Abgleich der Mitteilungs-Uhrzeit ist jetzt Teil der TestFlight-Fassung;
  Henning soll die Uhrzeit auf dem iPhone ändern und prüfen, ob sie auf dem zweiten Gerät erscheint.

## Changelog

- 2026-10-12: Initiale Spec für #311 (Schlüssel in `project.yml`, Skripttest, Archivprüfung).
