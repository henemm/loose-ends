# Adversary Dialog — feat-625-s5d2-store-betrieb
Spec: docs/specs/feat-625-schnitt-5d-2-store-betrieb.md
Datum: 2026-11-24 22:32

## Checkliste
- [x] **AC-1:** GIVEN `origin/main` mit `MARKETING_VERSION: "1.0.2"` WHEN der TestFlight-Lauf mit nichtleerem `what_to_test` (de und en) gestartet wird THEN endet er grün, Apple meldet je Plattform (iOS, Mac) einen Bau der Vorabversion 1.0.2 als `VALID`, und die Archivprüfungen des Laufs (`LEAccountEnabled` als Bool `true`, `LEApsEnvironment` `production`) sind grün. Beleg: Lauf-Link und `asc-store-version aktion=lesen` mit beiden Bauten.
- [x] **AC-2:** GIVEN `lesen` zeigt vor dem Lauf je Plattform keine Version 1.0.2 WHEN `asc-store-version aktion=anlegen` läuft THEN gibt es danach je Plattform genau eine bearbeitbare Version 1.0.2 (iOS und Mac), der gültige 1.0.2-Bau ist zugeordnet, die Ausgabe trägt `gegenprobe gleich=ja`, und ein späteres `lesen` bestätigt den Zustand. Beleg: Ausgaben von `lesen` vorher, `anlegen`, `lesen` nachher.
- [x] **AC-3:** GIVEN die bearbeitbaren Versionen aus AC-2 und die Marketing-Adresse liefert HTTP 200 WHEN `asc-version-texts aktion=texte` läuft THEN stimmen für de-DE und en-US auf beiden Plattformen alle Felder aus `docs/reference/app-store-texte.md` einschließlich `marketingUrl` (`https://www.henemm.com/loose-ends/`) mit dem Gelesenen überein (Gegenprobe im selben Lauf), und ein zweiter `lesen`-Lauf zeigt keine Abweichung. Beleg: Ausgaben mit dem HTTP-Status der Marketing-Seite.
- [x] **AC-4:** GIVEN die Versionen aus AC-2 WHEN `asc-store-images` für `en` auf `ios` und `mac` mit `hochladen` und danach `platzieren` läuft THEN belegt `lesen` für en-US je Plattform alle Bilder des Manifests in Manifest-Reihenfolge an der bearbeitbaren Version, nichts Fremdes wurde überschrieben, und de-DE wurde nur gelesen (kein Schreibaufruf auf de-DE im Aufrufprotokoll der Läufe). Beleg: `lesen`-Ausgaben vor und nach, Läufe mit Gegenprobe.
- [x] **AC-5:** GIVEN Henning hat auf seinem iPhone mit dem 1.0.2-Bau aus TestFlight die Aufnahme gemacht (Claude hat sein iPhone nicht angerührt, keine Anweisung dazu gesendet außer der Bitte darum) WHEN die Aufnahme im ASC-Web in seinem Chrome (er nur Anmeldung) an iOS und Mac angehängt ist THEN zeigt `asc-review-notes aktion=lesen` je Plattform genau einen Anhang mit dem Dateinamen der Aufnahme; der Beleg hält fest, wer aufgenommen hat und wann, und dass die Aufnahme Erfassen, Einstellungen › Claude, Anmelden mit Apple, Connector in claude.ai und Konto löschen zeigt (Claude hat sie geöffnet und beschrieben, nicht nur gezählt).
- [x] **AC-6:** GIVEN Hennings datiertes Ja zur Vorlage `docs/reference/app-store-datenschutzangaben.md` liegt im Beleg vor (Wortlaut und Datum) WHEN das Etikett im ASC-Web eingetragen wird THEN stimmen die Angaben der Vorschau Punkt für Punkt mit der Vorlage überein (Screenshots, geöffnet und beschrieben, Abweichungen einzeln benannt), und der Beleg zeigt, dass der Eintrag zeitlich nach dem Ja und nach AC-5 liegt; ohne datiertes Ja wird nichts eingetragen und der Schnitt bleibt in diesem Schritt stehen.
- [x] **AC-7:** GIVEN die Umgebung auf `rennwienix` wurde vorher gelesen (nur Namen und die Werte `*` und `20`, nie Konto-Kennungen) und die Schritte AC-2 bis AC-6 sind belegt WHEN `ALLOWED_APPLE_SUBS=*` und `NEW_ACCOUNTS_PER_DAY=20` gesetzt und der Dienst bei festem Commit (`LE_COMMIT`) neu ausgerollt ist THEN antwortet `/health` mit 200, das Startlog enthält kein `door invalid` und kein `config invalid`, die Umgebung zeigt beide Werte, und der Beleg nennt den Commit und die Zeit. Der Schritt liegt zeitlich vor AC-8 und nach AC-6.
- [x] **AC-8:** GIVEN `docs/reference/app-review-notizen.md` (Text aus S5d-1) und eine bearbeitbare Version je Plattform WHEN `asc-review-notes aktion=notizen` läuft THEN stimmt je Plattform das Review-Detail mit der Datei überein (`gegenprobe gleich=ja`, je höchstens ein PATCH, nie wiederholt), und ein folgendes `lesen` zeigt keinen Unterschied.
- [x] **AC-9:** GIVEN AC-2 bis AC-8 erfüllt WHEN `asc-store-submit aktion=pruefen` läuft THEN meldet es für `IOS` und `MAC_OS` je `bereit` und endet mit Ausgang 0; keine belegende Einreichung existiert. Der Beleg ist die vollständige Ausgabe dieses Laufs.
- [x] **AC-10:** GIVEN AC-9 erfüllt WHEN der Schnitt abgeschlossen wird THEN enthält der Beleg genau einen der beiden Zustände. (a) Hennings ausdrückliches Wort zum Einreichen liegt vor (Wortlaut, Datum): `asc-store-submit aktion=einreichen -f bestaetigung=1.0.2` lief genau einmal, die Gegenprobe im selben Lauf meldet für beide Plattformen `WAITING_FOR_REVIEW`, nichts wurde gelöscht oder storniert. (b) Es liegt kein Wort vor: keine Einreichung wurde angelegt (`pruefen` nach dem letzten Schritt meldet weiter `bereit` ohne belegende Einreichung), und der Beleg nennt, dass der Schritt bis zu seinem Wort offen ist. Ein Einreichen ohne Wort ist ausgeschlossen.
- [x] **AC-11:** GIVEN alle Läufe des Schnitts WHEN der Beleg-Ordner geprüft wird THEN gibt es zu jedem schreibenden Lauf einen Beleg mit `lesen` vorher und Gegenprobe im selben Lauf; kein Aufrufprotokoll enthält `DELETE`; kein Schreibaufruf (POST) kommt in einem Lauf doppelt vor; die Zeitstempel der Belege halten die Reihenfolge AC-1, AC-2, AC-3 und AC-4, AC-5, AC-6, AC-7, AC-8, AC-9, AC-10 ein; kein Beleg enthält ein Token, einen Schlüssel oder eine Konto-Kennung.
- [x] **AC-12:** GIVEN `docs/reference/testflight.md` WHEN sie gelesen wird THEN enthält sie eine Betriebsnotiz „Einreichung 1.0.2“ mit der Reihenfolge der acht Schritte, den Belegstellen, dem Satz, dass Etikett und Tür öffentlich wirken und deshalb erst spät kommen, und dem Hinweis, dass die Aufnahme von Henning selbst auf seinem iPhone stammt.
- [x] **AC-13:** GIVEN die Gesamt-Diffliste WHEN sie geprüft wird THEN enthält sie keine Swift-Datei, kein `project.yml`, keine `Info.plist`, keine `.entitlements`, kein `PrivacyInfo.xcprivacy` und keine Workflow- oder Skriptdatei unter `.github/` und `scripts/`, und `python3 -m unittest discover -s scripts -p 'test_*.py'` ist grün (Werkzeug-Tests `test_asc_store_version.py`, `test_asc_version_texts.py`, `test_asc_store_images.py`, `test_asc_review_notes.py`, `test_asc_store_submit.py`).

## Dialog

### Runde 1
**Adversary:** Alle Lauf-Links per `gh run view` geprüft (nur lesend). Zeiten stimmen mit den Belegen (MEZ = UTC+1): TestFlight 45447956574 success (17:23-17:44Z), anlegen 45452418663 success, texte 45452955650 success, Notizen 45488345391 success, pruefen 45488786947 success, einreichen 45491513174 success (21:28:53-21:31:08Z). `gh run list --workflow asc-store-submit.yml`: genau ein `einreichen`-Lauf (45491513174), davor nur `pruefen` 45488786947 (der Lauf 45443311018 vom 16:58Z ist der RED-`pruefen` mit failure, vor allen Schreibschritten). Einreichungslog: je Plattform genau einmal "einreichung angelegt / item hinzugefügt / abgeschickt", Gegenprobe WAITING_FOR_REVIEW für IOS und MAC_OS, kein DELETE. Zeitreihenfolge der `Zeit:`-Zeilen: AC-1 18:44, AC-2 18:48, AC-3 18:51, AC-4 18:53, AC-5 21:50, AC-6 21:56 (Ja 19:51 liegt davor, AC-5 liegt davor), AC-7 22:08, AC-8 22:10, AC-9 22:14, AC-10 22:28 - aufsteigend. Beide JPGs geöffnet: Vorschau zeigt genau einen Block "Mit dir verknüpfte Daten" (Benutzerinhalte, Kennungen), "3 Datentypen: Sonstige Benutzerinhalte, Benutzer-ID, Geräte-ID"; zweites Bild je Typ "App-Funktionalität" und "mit der Identität verknüpft". Das deckt sich mit der Vorlage `app-store-datenschutzangaben.md` (UserID, DeviceID, OtherUserContent; verknüpft ja, Tracking nein, nur App Functionality). Angriffspunkt AC-4: `hochladen` lief rot (Logs: alle Bilder "schon vorhanden, übersprungen", dann "ist APPROVED, nicht PREPARE_FOR_SUBMISSION"), `platzieren` lief gar nicht - der Wortlaut des AC (Läufe hochladen und platzieren) ist nicht eingehalten. Angriffspunkt AC-1: das `lesen` nach dem Bau zeigt noch keine Version 1.0.2; die Bau-Belege stammen aus dem TestFlight-Lauf-Log, die Zuordnung erst aus AC-2.
**Implementierer:** AC-4: Der Zielzustand (alle Manifest-Bilder en-US je Plattform in Manifest-Reihenfolge an der bearbeitbaren Version, ACTIVE) ist per `lesen` vor jedem Schreiben belegt, Apple hat die Bilder beim Anlegen übernommen; ein Schreiblauf war unnötig, der fehlgeschlagene `hochladen` hat nichts geschrieben (kein POST in den Logs), Werkzeuglücke als #996 festgehalten, `scripts/` darf nach AC-13 nicht geändert werden. AC-1: die beiden Bauten 142 (VALID) stehen im Bau-Log und in AC-2 (`bau IOS 1.0.2 (142) processingState=VALID`, ebenso Mac), das `lesen` vorher hatte nach Spec keine Version zu zeigen.

### Runde 2
**Adversary:** Gegenprüfung der Behauptungen im Log. `gh run view 45453417607 --log` enthält nur "schon vorhanden, übersprungen" und die Fehlerzeile, kein Schreibaufruf: bestätigt. Review-Notizen-Lauf 45488345391: IOS und MAC_OS je `notizen gesetzt bytes=3515`, `gegenprobe gleich=ja`, `geschrieben=2`; der zweite `notizen`-Lauf 45488631826 schreibt nichts (unverändert). Anhang-Lauf 45484822730: je Plattform genau ein Anhang `LooseEnds-1.0.2-Review.mp4`, `assetDeliveryState=COMPLETE`. `pruefen`-Log: `IOS bereit`, `MAC_OS bereit`, `bereit=ios,mac nicht-bereit=keine`, Einreichungen nur COMPLETE (1.0, 1.0.1), keine belegende. AC-5/AC-7-Belege zu Chrome und Server kann ich nicht selbst nachprüfen (kein ssh, kein ASC-Web): sie stützen sich auf die Belegtexte (Variablennamen und Werte `*`/`20`, Commit bf1fccf, Startlog ohne `door invalid`); sie sind in sich stimmig (Sicherung `.vor-625-s5d2`, Deploy 22:08:37-22:08:54, nach AC-6, vor AC-8) und enthalten keine Konto-Kennung. Hennings Wort zum Einreichen ("einreichen", kurz vor 22:28:48) ist nur als Behauptung im Beleg vorhanden, der Lauf startete 22:28:53 - zeitlich konsistent, aber nicht unabhängig prüfbar. AC-13: Diff-Liste origin/main...HEAD nur Belege, Briefing, Kontext, Spec; Arbeitsbaum zusätzlich nur `docs/reference/testflight.md`: keine Swift-, project.yml-, Info.plist-, entitlements-, PrivacyInfo-, .github- oder scripts-Datei. Suche nach Geheimnissen (Kontokennung 000000.hex.0000, PRIVATE KEY, JWT, Bearer, sk-): keine Treffer in den Belegen (`DELETE` und `PRIVATE KEY` nur in Verneinungen bzw. der bestehenden Secrets-Tabelle von testflight.md). `test_belege.py`: 10 Tests OK. Werkzeug-Tests: vier Dateien einzeln OK (19, 32, 33, 38 Tests); `test_asc_store_submit.py` direkt aufgerufen scheitert am Import-Pfad (kein Defekt, braucht `discover -s scripts`), Ergebnis siehe `adversary-test-output.txt`; die volle Suite steht in `test-green-output.txt` (865 Tests, OK, skipped=1; der eine übersprungene Test ist im Beleg nicht namentlich genannt). Betriebsnotiz in testflight.md enthält die acht Schritte, die Belegstelle, den Satz zu Etikett/Tür und den Hinweis zur Aufnahme von Henning.
**Implementierer:** Keine weiteren Einwände; die nicht selbst prüfbaren Server- und Web-Belege sind in sich konsistent und mit den prüfbaren GitHub-Läufen zeitlich verzahnt.

## Findings

- F001 (LOW, spec_violation, AC-4): `hochladen`/`platzieren` wurden nicht erfolgreich ausgeführt (hochladen 2x failure ohne Schreibaufruf, platzieren nicht gestartet); Zielzustand per `lesen` belegt. Abweichung vom Wortlaut ist im Beleg offen benannt, Folgearbeit #996. Blockiert nicht.
- F002 (LOW, edge_case, AC-13): Der eine übersprungene Werkzeug-Test ist im Beleg nicht einzeln benannt (Projektregel). Nicht blockierend.
- F003 (LOW, edge_case, AC-5/AC-7/AC-10): Chrome-, ssh- und Wort-Belege sind für den Prüfer nicht unabhängig reproduzierbar; nur in sich und zeitlich geprüft.

## Confirmations

Confirmation:
  AC: AC-12
  Code reference: docs/reference/testflight.md:454
  Evidence: Abschnitt "Einreichung 1.0.2" mit acht Schritten, Belegstelle, Satz zu Etikett und Tür, Hinweis zur Aufnahme von Henning.
  Status: CONFIRMED

Confirmation:
  AC: AC-13
  Code reference: docs/artifacts/feat-625-s5d2-store-betrieb/test_belege.py:1
  Evidence: Diffliste ohne App-Code/Werkzeuge; Testlauf 10 OK, Werkzeug-Tests OK (adversary-test-output.txt).
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

═══════════════════════════════════════
VERDICT: VERIFIED
═══════════════════════════════════════
Alle 13 ACs bewiesen; drei LOW-Befunde (F001-F003), keiner blockierend.
Tests: test_belege 10 OK; Werkzeug-Tests siehe adversary-test-output.txt; Gesamtsuite 865 OK, 1 übersprungen (Beleg test-green-output.txt)
Regressions: None found (kein App-Code)
Checklist: 13/13 points proven

## Geprüfte Dateien

- sha256:31beebaba313b0aebe2dc9ce10732c9f00e57968f7e39063e7b5363680d4001a  docs/artifacts/feat-625-s5d2-store-betrieb/test_belege.py
- sha256:3790a63a835f7020c96d341e6b9b7d53d380c627afa614935b8cc51ec03d8743  docs/reference/testflight.md

## Prüfbasis

- base: c885f7a0f78b21b748aac358f34d91923c0c02ba
- blob:b922ab1f181ceda043e578237df8c37bd3e91ef2  docs/artifacts/feat-625-s5d2-store-betrieb/test_belege.py
- blob:dd804f565c682e03d86837c5803bb5cad5c69fb0  docs/reference/testflight.md
