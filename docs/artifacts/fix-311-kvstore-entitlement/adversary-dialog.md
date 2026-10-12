# Adversary Dialog — fix-311-kvstore-entitlement
Spec: docs/specs/fix-311-kvstore-entitlement.md
Datum: 2026-10-12 10:26

## Checkliste
- [x] **AC-1 Quelle:** Given `project.yml` / When `xcodegen generate` läuft / Then entspricht `LooseEnds/LooseEnds.entitlements` der eingecheckten Fassung (`git diff` leer), und der Schlüssel `com.apple.developer.ubiquity-kvstore-identifier` mit dem Wert `$(TeamIdentifierPrefix)$(CFBundleIdentifier)` steht in beiden.
- [x] **AC-2 Test:** Given der Skripttest / When er auf dem Stand vor der Änderung läuft / Then schlägt er mit dem Schlüsselnamen fehl; nach der Änderung besteht er. Er läuft in der CI im Schritt „Script tests“.
- [x] **AC-3 Archivprüfung:** Given ein Archiv, dessen Haupt-App den Schlüssel nicht trägt / When der Schritt „Verify the archive“ läuft / Then bricht er mit einer Fehlermeldung ab, die den Schlüssel nennt, vor „Upload to TestFlight“. Given ein Archiv mit Schlüssel / Then bleibt der Schritt grün. Die Prüflogik ist an einer gebauten App belegt.
- [x] **AC-4 Signierung:** Given der Stand mit dem Schlüssel / When der TestFlight-Workflow läuft / Then signiert die Cloud- Signierung die Haupt-App mit dem Schlüssel, die Archivprüfung (AC-3) ist grün und der Bau erscheint als VALID. Verweigert sie den Schlüssel, wird der Rückfall (Alternative 3) neu bewertet; der Fix wird nicht mit abgeschwächter Prüfung ausgeliefert.
- [x] **AC-5 Nichts sonst:** Der Diff berührt nur die drei genannten Dateien; die Berechtigungen von Watch, Widget und Share sind unverändert; alle bestehenden Tests grün.
- [x] **AC-6 Gerät:** Nach Hennings ausdrücklicher Freigabe: Uhrzeit auf dem iPhone ändern, auf dem zweiten Gerät (Mac oder iPad) steht nach kurzer Zeit dieselbe Uhrzeit (#311 Schritt 3). #311 wird erst nach seiner Bestätigung geschlossen.

## Dialog

### Runde 1
**Adversary:**
Eigene Läufe (nichts geglaubt):
- `python3 -m unittest scripts/test_entitlements_sync.py -v`: 3/3 OK. Voller CI-Aufruf (`discover -s scripts -p 'test_*.py'`, frische venv mit pyyaml~=6.0): 94 Tests, OK, 0 übersprungen.
- `./scripts/sim.sh generate`, danach Statusabfrage der Versionsverwaltung: keine der vier `.entitlements`-Dateien geändert (nur project.yml und testflight.yml). AC-1 belegt.
- Mutationen gegen die Funktionen des Tests (declared/differences): project.yml ohne Schlüssel (Vorzustand) -> "LooseEnds com.apple.developer.ubiquity-kvstore-identifier: nur in der Datei, fehlt in project.yml"; Schlüssel nur in project.yml -> "nur in project.yml, fehlt in der Datei" (Gegenrichtung greift); Wert true gegen "true" -> gemeldet; Listenwert verschieden -> gemeldet. Abgedeckt: LooseEnds, Watch, Widgets, Share. Lab/Tests haben keine `entitlements`, werden korrekt übergangen; kein Ziel nutzt CODE_SIGN_ENTITLEMENTS in settings.
- Archivprüfung: Schritt "Verify the archive" steht in testflight.yml Z. 94, "Upload to TestFlight" Z. 211; der Schritt endet mit `[ "$fail" = 0 ]` und hat kein `shell:`, also GitHubs Standard `bash -e` ohne pipefail, kein SIGPIPE-Fehlbefund. `find -name '*.app'` findet verschachtelte Apps, Auswahl über CFBundleIdentifier. grep -qF auf `<key>…</key>` ist an beiden Enden verankert (Teilname oder Wert trifft nicht). Lokaler Beleg (archive-check-local.txt): mit Schlüssel grün, ohne Schlüssel Abbruch mit Schlüsselname, ohne App Abbruch.

Befunde (kein BROKEN):
- F001 LOW: `differences` vergleicht mit `!=`; in Python gilt `1 == True`, eine Datei mit `<integer>1</integer>` gegen `true` in project.yml bliebe unbemerkt. Heute ohne Folge (keine Ganzzahl-Werte).
- F002 LOW/Hinweis: Der Simulator-Bau (CODE_SIGNING_ALLOWED=NO) zeigt gar keine Berechtigungen; der lokale Beleg für AC-3 nutzt eine ad hoc nachsignierte Kopie, nicht das echte Cloud-Signatur-Archiv. Die Logik ist belegt, nicht das Verhalten am echten Archiv (AC-4).

AC-4 und AC-6 sind vor Auslieferung nicht beweisbar. Verbindlich verlangt die Spec: Definition of Done "erster TestFlight-Lauf nach dem Zusammenführen grün, Archivprüfung zeigt den Schlüssel im Protokoll" und "Rückmeldung zu Schritt 3 schließt #311", PR mit `Refs #311`. Verschieben ist zulässig, solange #311 offen bleibt und der Beleg (Step-Summary-Zeile "vorhanden", Buildnummer VALID, Hennings Rückmeldung nach "jetzt ist ein Test möglich") nachgereicht wird.

Nachfragen / geforderte Beweise für Runde 2:
1. Wie wird sichergestellt, dass AC-4/AC-6 nach dem Merge nicht untergehen (Ticket #311 bleibt offen, `Refs` statt `Closes`, Hinweis im PR)? Bitte PR-Text/Plan nennen.
2. F001: Absicht oder Korrektur (Typvergleich mit `type(a) is type(b)`)? Begründung, falls unverändert.
3. Bitte belegen, dass der Schritt im echten Lauf mit `$APPS`-Archiv aus `xcodebuild archive` (Entwicklungssignatur, nicht Export) den Schlüssel überhaupt sehen kann; wenn nicht belegbar, als Risiko in AC-4 festhalten.
**Implementierer:**

### Runde 2
**Adversary:**
- F001 behoben, selbst geprüft: `same()` (Typgleichheit, rekursiver Listenvergleich) in scripts/test_entitlements_sync.py:30-36, genutzt in Z. 47; neuer Test `test_integer_one_is_not_true` (Z. 73-75) meldet True gegen 1, auch als Liste. Eigener Lauf: 4/4 OK. Gegenrichtung und Vorzustand wie in Runde 1 weiterhin gemeldet.
- Nachfrage 1: ausreichend, wenn `Refs #311` (nie `Closes`), PR-Abschnitt "Offen nach dem Zusammenführen" und der Kommentar in #311 tatsächlich so entstehen (Auflage für den Abschluss).
- Nachfrage 3: kein Lauf-Beleg, nur Argumentation. Sie trägt für die Drift (Schlüssel fehlt in der Datei, also im Archiv); sie beweist nicht, dass das Entwicklungsprofil den Schlüssel im Archiv trägt. Ein falsches "FEHLT" stoppt den Lauf vor dem Upload und schadet nur als roter Lauf; die Spec verbietet das Abschwächen. Akzeptiert als Restrisiko, nicht als Beweis.
- AC-3-Lauf der Shell-Logik stammt vom Orchestrator (mein Shell-Zugriff war gesperrt); dass der Schritt ohne `shell:` und damit ohne pipefail läuft, ist von mir am Code belegt.
- Bewertung AC-4/AC-6: Die Spec (Definition of Done) verlangt beides ausdrücklich nach dem Zusammenführen; vorher unmöglich. Verschieben mit offenem #311 ist zulässig, kein Defekt. Bedingungen: `Refs`, #311 offen bis Hennings Rückmeldung nach seinem wörtlichen "jetzt ist ein Test möglich"; verweigert die Signierung den Schlüssel, gilt der Rückfall (Alternative 3), nie eine abgeschwächte Prüfung.
**Implementierer:** Antworten und Belege wie vom Orchestrator übermittelt.

### Runde 3 (nach dem Zusammenführen, 2026-10-12)
**Adversary:**
- AC-4 nachgereicht: TestFlight-Lauf 38226509728 vom Zweig des PR #358; die Archivprüfung zeigt im Protokoll `| com.henning.looseends | com.apple.developer.ubiquity-kvstore-identifier | vorhanden |`, der Lauf endet grün, Apple meldet Build 48 als VALID. Die Cloud-Signierung vergibt den Schlüssel, der Rückfall (Alternative 3) ist nicht nötig; das Restrisiko aus Runde 2 ist damit am echten Archiv widerlegt.
- AC-6 nachgereicht: Henning hat Build 48 auf seinen Geräten nach eigenem „jetzt ist ein Test möglich“ geprüft (Uhrzeit auf dem iPhone ändern, zweites Gerät zeigt dieselbe Uhrzeit, Aufgabe ohne Uhrzeit meldet „Heute fällig“ zur eingestellten Zeit) und meldet: „alles positiv getestet.“
- Auflagen aus Runde 2 erfüllt: PR #358 mit `Refs #311`, Abschnitt „Offen nach dem Zusammenführen“ vorhanden, #311 bis zu Hennings Rückmeldung offen.
**Implementierer:** Belege wie genannt; kein Code seit Runde 2 geändert.

### Bestätigungen
Confirmation AC-4: Code reference: .github/workflows/testflight.yml:160 (echter Archivlauf 38226509728: Zeile „vorhanden“ für die Haupt-App, Build 48 VALID). CONFIRMED
Confirmation AC-6: Code reference: project.yml:58 (Henning, nach „jetzt ist ein Test möglich“: Uhrzeit-Abgleich iPhone → zweites Gerät „alles positiv getestet“). CONFIRMED
Confirmation AC-1: Code reference: project.yml:58 (Schlüssel mit Wert $(TeamIdentifierPrefix)$(CFBundleIdentifier) im Ziel LooseEnds; generate lässt alle .entitlements unverändert). CONFIRMED
Confirmation AC-2: Code reference: scripts/test_entitlements_sync.py:47 (typgenauer Vergleich, rot im Vorzustand mit Schlüsselname, 95/95 grün im CI-Aufruf). CONFIRMED
Confirmation AC-3: Code reference: .github/workflows/testflight.yml:160 (entitled() Z. 145-158 setzt fail=1, Schritt endet mit [ "$fail" = 0 ] vor Upload Z. 211). CONFIRMED
Confirmation AC-5: Code reference: project.yml:58 (Code-Diff nur drei Dateien, andere Ziele unverändert, Tests grün). CONFIRMED
AC-4 und AC-6: nach dem Zusammenführen nachgewiesen (Runde 3).

Confirmation:
  AC: AC-1
  Code reference: project.yml:58
  Evidence: Schlüssel mit Wert $(TeamIdentifierPrefix)$(CFBundleIdentifier) im Ziel LooseEnds; generate lässt alle vier .entitlements unverändert
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: scripts/test_entitlements_sync.py:47
  Evidence: typgenauer Vergleich, rot im Vorzustand mit Schlüsselname, 95/95 grün im CI-Aufruf
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: .github/workflows/testflight.yml:160
  Evidence: entitled() (Z. 145-158) setzt fail=1, Schritt endet mit [ "$fail" = 0 ] vor Upload (Z. 211)
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: project.yml:58
  Evidence: Code-Diff nur drei Dateien, andere Ziele unverändert, Tests grün
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

═══════════════════════════════════════
VERDICT: VERIFIED
═══════════════════════════════════════
Tests: 95 passed, 0 failed, 0 übersprungen (Skripttests, CI-Aufruf)
Edge cases: geprüft, keiner gebrochen (F001 behoben)
Regressions: keine gefunden
Checklist: 6/6 bewiesen. AC-1, AC-2, AC-3, AC-5 vor dem Zusammenführen; AC-4 (Lauf 38226509728, Zeile „vorhanden“, Build 48 VALID) und AC-6 (Hennings Geräte-Rückmeldung) in Runde 3.

## Geprüfte Dateien

- sha256:3daffc5b9c7e79b3076d9b4e3047146d0dd595ed7c407b979c29a2f7e8e56850  .github/workflows/testflight.yml
- sha256:4f92589d62e714f7493702e3b6ed0966aa388c792f3cd99ab35978b7e0b52233  project.yml
- sha256:815d780afb4a12f801f842e53d928015a0814c1cdce8960e8a5b02b93688e7fd  scripts/test_entitlements_sync.py

## Prüfbasis

- base: badaa159428a3cf96d4d58083879f6aef60c3691
- blob:53d722959699fa1dcdcc93a8b8c9622242829f4d  .github/workflows/testflight.yml
- blob:c74626ad04beceb88e4914f7d7f63fa358e15137  project.yml
- blob:ef02f5b2ec2956c87194006a22bde650f4f59d0c  scripts/test_entitlements_sync.py
