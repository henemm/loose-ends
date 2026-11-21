# Adversary Dialog — feat-625-s3-fragebogen
Spec: docs/specs/feat-625-schnitt-3-fragebogen.md
Datum: 2026-11-21 15:06

## Checkliste
- [x] **AC-1:** GIVEN `docs/reference/app-store-datenschutzangaben.md` WHEN sie gelesen wird THEN hat sie die fünf `##`-Abschnitte „Stand heute“, „Antworten mit Konto“, „Bewusst nicht angegeben“, „Zeitpunkt und Ablauf“, „Quellen“ in dieser Reihenfolge, und „Stand heute“ nennt das Store-Etikett „Data Not Collected“ samt dem Satz, dass es app-weit gilt, solange der Konto-Schalter aus ist.
- [x] **AC-2:** GIVEN der Abschnitt „Antworten mit Konto“ WHEN er gelesen wird THEN enthält er genau eine Tabelle mit der Kopfzeile `Manifest-Schlüssel | Apple-Typ (ASC, englisch) | Verknüpft | Tracking | Zweck | Beleg im Code` und genau drei Zeilen für UserID, DeviceID und OtherUserContent mit Verknüpft `ja`, Tracking `nein` und dem Zweck `NSPrivacyCollectedDataTypePurposeAppFunctionality`; die Apple-Typen stehen auf Englisch (deutsche Begriffe nur als „vermutlich“).
- [x] **AC-3:** GIVEN der Abschnitt „Bewusst nicht angegeben“ WHEN er gelesen wird THEN nennt er je einen eigenen Punkt mit Grund für Name/E-Mail, Standort, Kontakte, Fotos/Dateien, Rohtext/Notizen außerhalb der Abschrift, Absturz- und Leistungsdaten (nur Apple), keine Analyse, privates iCloud und IP-Adresse; der IP-Punkt nennt „kein eigener Typ“, die 14 Tage im nginx-Protokoll und das Apple-Zitat zur IP-Adresse wörtlich.
- [x] **AC-4:** GIVEN der Abschnitt „Zeitpunkt und Ablauf“ WHEN er gelesen wird THEN sagt er, dass erst mit dem Schalter-Schnitt und im selben Zug wie die Einreichung eingetragen wird (nie vorher, weil die Antworten app-weit gelten und sofort wirken), dass es nur im ASC-Web geht (keine API), dass Claude die Seite in Hennings Browser öffnet und Henning sich nur anmeldet, und dass nur nach Hennings ausdrücklichem Ja zum Wortlaut eingetragen wird; „Quellen“ nennt `https://developer.apple.com/support/app-privacy-on-the-app-store`.
- [x] **AC-5:** GIVEN `scripts/test_app_store_datenschutzangaben.py` und die echte Vorlage WHEN der Test läuft THEN sind Menge der Schlüssel, Verknüpft, Tracking und Zwecke der Tabelle gleich `ACCOUNT_TYPES` aus `scripts/privacy_manifest.py` und der Test ist grün.
- [x] **AC-6:** GIVEN eine im Speicher mutierte Kopie des Vorlagentextes mit fehlender Zeile, zusätzlicher Zeile, doppelter Zeile, geändertem Verknüpft-Wert, geändertem Tracking-Wert oder geändertem Zweck WHEN der Gleichlauf-Vergleich läuft THEN schlägt er jeweils fehl und die Meldung nennt den betroffenen Schlüssel.
- [x] **AC-7:** GIVEN ein Vorlagentext ohne den Abschnitt „Antworten mit Konto“, ohne Tabelle darin, mit abweichender Kopfzeile oder mit einem Wert außer `ja`/`nein` WHEN `parse_types` läuft THEN wirft es einen verständlichen Fehler (kein stilles Leerergebnis, das den Vergleich bestehen ließe).
- [x] **AC-8:** GIVEN der Ablauf der Entwicklung WHEN der Test vor Anlage der Vorlage läuft THEN ist er rot (Beleg `red.txt`), und nach Anlage der Vorlage läuft `python3 -m unittest discover -s scripts -p 'test_*.py'` grün mit dem neuen Test sichtbar enthalten (Beleg `green.txt`).
- [x] **AC-9:** GIVEN `docs/reference/datenschutz-entwurf.md` WHEN der Abschnitt „Beleg im Code“ gelesen wird THEN enthält er genau eine neue Zeile, die sagt, dass die Fragebogen-Vorlage `docs/reference/app-store-datenschutzangaben.md` der Liste `ACCOUNT_TYPES` in `scripts/privacy_manifest.py` folgt und der Test `scripts/test_app_store_datenschutzangaben.py` das hält; die Abschnitte vor „Beleg im Code“ (öffentlicher Text) sind unverändert (Diff).
- [x] **AC-10:** GIVEN der Diff des PR WHEN er geprüft wird THEN enthält er genau die drei Pfade `docs/reference/app-store-datenschutzangaben.md`, `scripts/test_app_store_datenschutzangaben.py`, `docs/reference/datenschutz-entwurf.md` plus den Belegordner, keine Datei unter `LooseEnds/`, `Shared/`, `server/`, `.github/`, weder `project.yml` noch eine `Info.plist`, und `LEAccountEnabled` ist in `project.yml` weiterhin `false` (Beleg `schalter.txt`).
- [x] **AC-11:** GIVEN die Abnahme WHEN sie begründet wird THEN lautet der Satz im Bericht „Kein Pfad der Geräteliste berührt.“, die Abnahme endet nach Stufe 2 mit der Begründung, dass kein App-Code und keine Oberfläche geändert wird und deshalb kein Simulator-Durchlauf einen Nachweis erbrächte, und es gibt keinen Lauf auf Hennings Geräten.

## Dialog

### Runde 1
**Adversary:** Ich unterstelle, dass die Vorlage vom Code abweicht und der Test Mutationen durchlässt. Test selbst gelaufen (`PYTHONPATH=scripts python3 -m unittest test_app_store_datenschutzangaben -v`, Ausgabe `docs/artifacts/feat-625-s3-fragebogen/adversary-test-output.txt`): 15 Tests, OK.
Beweise je AC:
- AC-1: Überschriften in Reihenfolge, „Data Not Collected“ und „app-weit“ in Stand heute. Code reference: docs/reference/app-store-datenschutzangaben.md:11
- AC-2: genau eine Tabelle, Kopfzeile wörtlich, drei Zeilen ja/nein/AppFunctionality, englische Typen. Code reference: docs/reference/app-store-datenschutzangaben.md:24
- AC-3: neun Punkte plus IP-Punkt mit „kein eigener Typ“, „14 Tage“, Apple-Zitat wörtlich (Test `test_ip_point_quotes_apple_and_names_retention`). Code reference: docs/reference/app-store-datenschutzangaben.md:60
- AC-4: Schalter-Schnitt, selber Zug wie Einreichung, nur ASC-Web, Browser, ausdrückliches Ja; URL in Quellen. Code reference: docs/reference/app-store-datenschutzangaben.md:66
- AC-5: `test_table_equals_account_types` grün gegen ACCOUNT_TYPES. Code reference: scripts/test_app_store_datenschutzangaben.py:157
- AC-6: sechs Mutationstests, jeder prüft, dass der Schlüssel in der Meldung steht. Code reference: scripts/test_app_store_datenschutzangaben.py:172
- AC-7: vier Tests mit assertRaisesRegex. Code reference: scripts/test_app_store_datenschutzangaben.py:206
- AC-8: red.txt: 15 Tests, FileNotFoundError, FAILED (errors=15); green.txt: 788 Tests OK (skipped=1), 15 Erwähnungen des neuen Tests. Code reference: scripts/test_app_store_datenschutzangaben.py:143
- AC-9: +1 Zeile in „Beleg im Code“, Hunk bei Zeile 144 (nach dem öffentlichen Text), nichts davor geändert. Code reference: docs/reference/datenschutz-entwurf.md:147
- AC-10: gestagt nur die erlaubten Pfade (plus Belege); gegenüber origin/main zusätzlich Workflow-Unterlagen und der Test (erlaubt); project.yml `LEAccountEnabled: false`. Code reference: project.yml:86
- AC-11: keine App-/Geräte-Datei berührt (nichts unter LooseEnds/, Shared/, server/, .github/).
Aussagen der Vorlage gegen den Code: `requestedScopes = []` stimmt (LooseEnds/Views/AccountSection.swift:177); `transcripts.ts:103` weist rawText/note ab; `device_tokens` hängt per `ON DELETE CASCADE` am Konto (008_device_tokens.sql), deleteAccount löscht das Konto, also stimmt „samt Gerätetoken“; alle 15 Pfade der Beleg-Spalten existieren; kein `import Contacts`, kein `NSContactsUsageDescription`, keine `packages` in project.yml; `rotate 14` ist im Beleg #615 S4e belegt; der Vertrag enthält „keinen Rohtext, keine Notiz“.
**Implementierer:** (nicht anwesend, Kontextisolation)

### Runde 2
**Adversary:** Eigene Mutationen im Speicher (Skript im Scratchpad): leerer Zweck, zusätzlicher Zweck, Schlüssel-Tippfehler (`DeviceId`), zweite Tabelle im Abschnitt, „Ja“ groß. Alle fallen auf (Zweck weicht ab; „nicht in ACCOUNT_TYPES“ plus „fehlt“; Fehler bei Spaltenzahl; Fehler bei „Ja“). Kein stilles Leerergebnis; eine Tabelle nur mit Kopfzeile liefert [] und scheitert an den „fehlt“-Befunden.
Restschwächen (nicht blockierend): (a) „genau eine Tabelle“ aus AC-2 wird nur indirekt geprüft (jede `|`-Zeile des Abschnitts wird gelesen, eine zweite Tabelle wirft). (b) Die Gerätetoken-Aussage hängt am Cascade der Migration, nicht an einer expliziten DELETE-Zeile; sie bleibt wahr. (c) green.txt hat 1 übersprungenen Test der Gesamtsuite (fremd, die 15 neuen liefen). (d) Die Auslegung „privates CloudKit nicht erhoben“ ist als Auslegung gekennzeichnet; Freigabe durch den PO vor dem Eintragen, nicht Teil dieses Schnitts.
Skepsis: jede AC durch Lesen plus eigenen Lauf belegt, nicht auf Aussagen des Implementierers gestützt. Code reference: scripts/privacy_manifest.py:16
**Implementierer:** (nicht anwesend)

## Confirmations

Confirmation:
  AC: AC-1
  Code reference: docs/reference/app-store-datenschutzangaben.md:11
  Evidence: fünf Abschnitte in Reihenfolge, Data Not Collected, app-weit
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: docs/reference/app-store-datenschutzangaben.md:24
  Evidence: Tabelle mit Kopfzeile und drei Zeilen
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: docs/reference/app-store-datenschutzangaben.md:37
  Evidence: Auslassungspunkte mit Grund, IP-Zitat
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: docs/reference/app-store-datenschutzangaben.md:66
  Evidence: Zeitpunkt und Ablauf, Quelle
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: scripts/test_app_store_datenschutzangaben.py:157
  Evidence: Gleichlauf gegen ACCOUNT_TYPES grün
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: scripts/test_app_store_datenschutzangaben.py:172
  Evidence: sechs Mutationstests nennen den Schlüssel
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: scripts/test_app_store_datenschutzangaben.py:206
  Evidence: vier Formfehler werfen TemplateError
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: docs/artifacts/feat-625-s3-fragebogen/green.txt:2009
  Evidence: Suite OK, neuer Test enthalten; red.txt 15 Fehler
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: docs/reference/datenschutz-entwurf.md:147
  Evidence: genau eine neue Zeile nach dem öffentlichen Text
  Status: CONFIRMED

Confirmation:
  AC: AC-10
  Code reference: project.yml:86
  Evidence: LEAccountEnabled false, nur erlaubte Pfade
  Status: CONFIRMED

Confirmation:
  AC: AC-11
  Code reference: docs/reference/app-store-datenschutzangaben.md:1
  Evidence: nur Doku, kein App- oder Geräte-Pfad
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: VERIFIED
Tests: 15 passed, 0 failed, 0 übersprungen (neuer Test); Gesamtsuite laut green.txt 788 OK, 1 fremd übersprungen
Edge cases: eigene Mutationen alle erkannt
Regressions: None found
Checklist: 11/11 points proven (AC-11 nur diffseitig)

## Geprüfte Dateien

- sha256:9241f63d3ce7e2f226aa7ba8be70027929853211abcf5395bd4c8ac0a295f139  docs/artifacts/feat-625-s3-fragebogen/green.txt
- sha256:fd7e1f57bfb06bb02c18e436a238fab20e04c2a0636e0c47aa4e71fe6c2489f7  docs/reference/app-store-datenschutzangaben.md
- sha256:c692955124ebfab534ba6a4c312d246c903a818c2dbed5ebc3eb7b5c7b8455a4  docs/reference/datenschutz-entwurf.md
- sha256:76723455325bd9f1043ceed36f6c30b79b8c724f899cb87301114a5eda91f201  project.yml
- sha256:cd814ae2f92a467ad99dce96343c3871301e6046b4de3c781de96f814e365678  scripts/test_app_store_datenschutzangaben.py

## Prüfbasis

- base: ec5707ab99acb0845f1a7beea1e4aea2ba638ce2
- blob:28e4a1654e81dbf19ef47e7c74e3986e000ff8a2  docs/artifacts/feat-625-s3-fragebogen/green.txt
- blob:899f42492a8c6d642cf82844789b11c93b65845a  docs/reference/app-store-datenschutzangaben.md
- blob:20f8fb7dd9d041874c25f4854c42a2922f86671c  docs/reference/datenschutz-entwurf.md
- blob:d398b6ffd451eae24842b9223b8d794f988c85f8  project.yml
- blob:bfd63a8c7733791ce24b12d97fbe1096a4c7813c  scripts/test_app_store_datenschutzangaben.py
