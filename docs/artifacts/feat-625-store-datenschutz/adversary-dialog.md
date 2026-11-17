# Adversary Dialog — feat-625-store-datenschutz
Spec: docs/specs/feat-625-schnitt-1-datenschutztext.md
Datum: 2026-11-17 10:28

## Checkliste
- [x] **AC-1:** GIVEN `docs/reference/datenschutz-entwurf.md` WHEN der deutsche Abschnitt „Wenn du die Verbindung zu Claude nutzt“ gelesen wird THEN steht der Absatz „Deine offenen Aufgaben für Claude.“ nach „Was unser Dienst speichert.“ und vor „Aufträge aus Claude.“ im oben freigegebenen Wortlaut, und er enthält die Aussagen: Abschrift der offenen Aufgaben, Senden nur bei Anmeldung (auch ohne verbundenes Claude), die genannten Felder, der Titel kann den Anfang des Textes enthalten, nicht dabei Rohtext, Notizen, Anhänge, Orte, erledigte Aufgaben und Änderungsverlauf, Auslöser Start, Rückkehr und Änderungen, nur die neueste Abschrift wird behalten, Zweck Claude, Abmelden lässt die Abschrift stehen.
- [x] **AC-2:** GIVEN der Absatz aus AC-1 WHEN er mit `Shared/Services/TranscriptCodec.swift` (`Entry`, `Transcript`) und `server/src/transcripts.ts` (`shape`, `privacy`) verglichen wird THEN nennt er kein Feld, das dort fehlt, und verschweigt keines, das dort steht; die Aussage „nicht dabei: Text, Notizen, Anhänge, Orte, erledigte Aufgaben, Verlauf“ hat im Code jeweils keinen Gegenbeleg (Beleg `aussagen.txt`: je Aussage Datei und Fundstelle).
- [x] **AC-3:** GIVEN der Entwurf WHEN der Absatz „Kennung dieser Installation.“ gelesen wird THEN steht er nach „Aufträge aus Claude.“ im freigegebenen Wortlaut und nennt: zufällige Kennung, einmal von der App erzeugt, im Schlüsselbund dieses Geräts, nicht über iCloud abgeglichen, kein Hardware-Merkmal, mitgeschickt beim Abholen von Aufträgen und Melden des Ergebnisses, vom Dienst an Auftrag und Ergebnis vermerkt, bleibt bis zur Kontolöschung.
- [x] **AC-4:** GIVEN der Absatz „Löschen.“ im Entwurf WHEN er gelesen wird THEN nennt er, dass „Konto löschen“ auch die Abschrift der Aufgaben, Aufträge und Ergebnisse entfernt (Wortlaut oben), und alle übrigen Sätze des Absatzes („Konto löschen“, „Vorhandene Sicherungen laufen innerhalb von 30 Tagen aus“, „Abmelden“) sind unverändert.
- [x] **AC-5:** GIVEN der Abschnitt „English“ im Entwurf WHEN er mit dem deutschen verglichen wird THEN enthält Abschnitt 4 die zwei neuen Absätze und den geänderten Löschsatz im oben angegebenen englischen Wortlaut, ohne Zusätze und Kürzungen und ohne die Nummerierung zu ändern; die Statuszeile des englischen Abschnitts nennt die Freigabe des Nachtrags und die Veröffentlichung; „Last updated“ trägt das Veröffentlichungsdatum.
- [x] **AC-6:** GIVEN der Entwurf WHEN „Beleg im Code“ gelesen wird THEN stehen nach der Zeile „Aufträge aus Claude …“ die dreizehn Zeilen der Beleg-Tabelle oben (Felder, offen = nicht erledigt, Titel aus Rohtext, Senden nur mit Anmeldung, Auslöser, nur neueste, Zweck, Abmelden, Löschen, Kennung, Kennung nur bei Aufträgen, Vermerk am Auftrag, Löschung mit dem Konto), und jede Dateiangabe nennt eine Datei, die im Repo existiert (Beleg `belege-pfade.txt`: Pfadliste mit Existenzprüfung).
- [x] **AC-7:** GIVEN der Entwurf WHEN „Offen, nicht belegt“ und der Statuskopf gelesen werden THEN ist der Punkt „Aufgabenübertragung zum Dienst: nicht beschrieben, weil sie nicht gebaut ist …“ ersetzt durch einen Punkt „Weckruf (Push-Token)“: der Dienst kann je Gerät einen Push-Token speichern (Migration 008, `server/src/devices.ts`), die App hat den Kern (`DeviceRegistration`), ruft ihn aber noch nicht auf, im Text nicht beschrieben, der Absatz dazu kommt mit #795 S5c-2 und ändert Text und Seite erneut; der Statuskopf nennt die Freigabe des Nachtrags (Datum der Spec-Freigabe, beim Umsetzen eingetragen) und die Veröffentlichung (Datum und Website-PR, nach dem Merge eingetragen).
- [x] **AC-8:** GIVEN `scripts/test_datenschutz_text.py` (weiterhin ein `unittest.TestCase`) WHEN der CI-Befehl `python -m unittest discover -s scripts -p 'test_*.py'` läuft THEN ist es grün, und das Verbot `test_no_transcript_in_account_section` ist umgedreht: der Konto-Abschnitt muss je Sprache die Abschrift nennen (de „Abschrift“, en „transcript“) und die Negativ-Aussagen enthalten (de „Rohtext“ und „Notizen“, en „raw text“ und „notes“); die neuen Kernsätze beider Absätze und des Löschsatzes stehen als wörtliche Anker in `ANCHORS` (und damit auch in der Live-Prüfung), und `STALE` enthält zusätzlich „weil sie nicht gebaut ist“, damit der überholte „Offen“-Punkt nicht zurückkehrt.
- [x] **AC-9:** GIVEN das umgebaute Prüfskript und der unveränderte Entwurf WHEN es läuft THEN ist es rot, und der Beleg `red.txt` zeigt die fehlenden Aussagen (Abschrift im Konto-Abschnitt de und en, „Rohtext“/„raw text“, die neuen Anker, den vorhandenen „nicht gebaut“-Punkt); nach der Änderung des Entwurfs zeigt `green.txt` den grünen Lauf des CI-Befehls.
- [x] **AC-10:** GIVEN die Gegenprobe-Tests in `CheckerTests` WHEN sie laufen THEN sind sie grün und belegen: ein Konto-Abschnitt ohne „Abschrift“ wird als unvollständig gefangen, einer mit „Abschrift“ aber ohne „Rohtext“ ebenfalls, einer mit beidem nicht, und der Satz „weil sie nicht gebaut ist“ wird als veraltet gefangen; der bisherige Test `test_transcript_found_in_section` bleibt als Hilfsprobe der Abschnittssuche erhalten.
- [x] **AC-11:** GIVEN `CLAUDE.md` WHEN der Datenschutz-Absatz unter „Build“ gelesen wird THEN nennt er zusätzlich, dass der Text seit dem Veröffentlichungsdatum die Abschrift der offenen Aufgaben und die Kennung dieser Installation beschreibt (Verweis auf diese Spec), dass der Weckruf-Absatz mit #795 S5c-2 folgt und `LEAccountEnabled` bis #625 aus bleibt; die übrigen Sätze des Absatzes bleiben unverändert (Diff).
- [x] **AC-12:** GIVEN die Freigabe des Wortlauts und der gemergte `loose-ends`-PR WHEN der PR im Repo `henemm/henemm-website` die Seiten `content/legal/loose-ends/privacy-policy/_index.md` und `…/privacy-policy-en/_index.md` ändert THEN enthalten beide die Änderungen aus AC-1, AC-3, AC-4 bzw. AC-5 im freigegebenen Wortlaut, das Datum „Stand“ bzw. „Last updated“ ist das Veröffentlichungsdatum, und die Seiten enthalten nicht die Abschnitte „Beleg im Code“ und „Offen, nicht belegt“; erst danach wird der Website-PR gemergt.
- [x] **AC-13:** GIVEN der gemergte und ausgelieferte Website-PR WHEN `curl -sS -o seite.html -w '%{http_code}'` die URLs `https://www.henemm.com/legal/loose-ends/privacy-policy/` und `https://www.henemm.com/legal/loose-ends/privacy-policy-en/` abruft THEN ist der Code je 200, und das Prüfskript (Aufruf mit `DATENSCHUTZ_LIVE=1`) ist grün: Kernaussagen, alle Anker aus AC-8, Abschnittstitel, keine veralteten Sätze, keine internen Abschnitte; Beleg `live.txt` mit Codes und Treffern. Die bei Apple gesetzte Datenschutz-URL bleibt unverändert (Repo-Variable `ASC_PRIVACY_POLICY_URL` und `PRIVACY_URL_EN` ohne Diff).
- [x] **AC-14:** GIVEN die veröffentlichten Seiten (beide Sprachen) und der Entwurf WHEN die Abschnitte verglichen werden THEN stimmen die Kernsätze der neuen und geänderten Absätze nach Normalisierung der Anführungszeichen wörtlich überein (Beleg `vergleich.txt`).
- [x] **AC-15:** GIVEN der Diff beider PRs WHEN er geprüft wird THEN enthält er weder `project.yml` noch `LooseEnds/Info.plist` noch `LooseEnds/PrivacyInfo.xcprivacy` noch `scripts/test_asc_what_to_test.py` noch Dateien unter `LooseEnds/`, `Shared/`, `server/`, und `LEAccountEnabled` ist in `project.yml` weiterhin `false` (Beleg `schalter.txt`: Diff-Dateiliste und Zeile aus `project.yml`).
- [x] **AC-16:** GIVEN der Schnitt ändert nur `docs/`, `scripts/`, `CLAUDE.md` und das Website-Repo WHEN die Abnahme begründet wird THEN lautet der Satz im Bericht „Kein Pfad der Geräteliste berührt. Reiner Text, keine App-Änderung; Stufe 2 an den Live-Seiten belegt.“, und Stufe 2 ist das Öffnen beider Live-Seiten im Browser samt Screenshot je Sprache (`live-de.png`, `live-en.png`), geöffnet und beschrieben. Es gibt keinen App-Lauf und nichts auf Hennings Geräten.

## Dialog

### Runde 1
**Adversary:** Ich prüfe die Nachbesserung. Der Satz „Außerdem steht darin, wann die Abschrift erstellt wurde.“ steht in `docs/reference/datenschutz-entwurf.md` nach „…nur als Kennungen.“ und vor „Der Titel entsteht“; das ist die Stelle der Spec (Zeile 78). Der englische Satz steht nach „…as identifiers only.“ (Spec Zeile 96). `git diff` zeigt genau zwei Hunks, keine weiteren Sätze, keine Änderung der Nummerierung. Im Deutschen ist ein Zeilenumbruch verschoben (nach „steht“ und vor „Der Titel entsteht“); Markdown-Fließtext, die Anker-Prüfung normalisiert Leerraum. Ist er durch den Code gedeckt? `Transcript.generatedAt` (Shared/Services/TranscriptCodec.swift:8), `generatedAt` im Dienst (server/src/transcripts.ts:17, 119, 131), Vertrag Zeile 25 „Zeitpunkt der Berechnung“. Der Satz ist belegt. Ich versuche zu brechen: Anker `scripts/test_datenschutz_text.py:48` und `:70` stehen wörtlich in `ANCHORS`; die Entwurfstests laufen grün (18 Tests, 1 übersprungen = Live-Test, Beleg `adversary-test-output.txt`). Der Live-Lauf mit `DATENSCHUTZ_LIVE=1` meldet genau die zwei neuen Anker als fehlend, nichts sonst. Der vorbereitete Website-Diff (zwei Dateien, `git status --short` zeigt nur diese) ist zeichengleich zum Entwurf (gleiche Umbrüche, gleiche Position); „Stand“/„Last updated“ bleibt 17.11.2026, es ändert sich also kein Datum, siehe F002. Statuskopf: er nennt die Veröffentlichung „henemm/henemm-website#80“ (Zeilen 16 und 228) und gilt für den neuen Satz noch nicht (F001).
**Implementierer:** Der Satz ist durch Freigabe (Changelog 2026-11-17) und Code gedeckt; der Website-Diff liegt vor, wird erst nach dem Merge dieses PR gemergt (AC-12).

### Runde 2
**Adversary:** Frühe Einigkeit ist verdächtig, deshalb die Gegenprobe. (a) Übrige ACs: AC-1 bis AC-11, AC-15, AC-16 nur am Arbeitsbaum geprüft; `git diff` gegen HEAD berührt nur den Entwurf, kein `project.yml`, nichts unter `LooseEnds/`, `Shared/`, `server/`; die Belege der ersten Runde liegen unter `schnitt-1/` (aussagen.txt, belege-pfade.txt, schalter.txt, live-de.png, live-en.png). (b) `green.txt` (742 OK, 1 übersprungen) wurde um 10:27 beendet, nach der letzten Änderung des Entwurfs (10:19) und des Prüfskripts (10:17); mein eigener Lauf des Entwurfstests ist ebenfalls grün. (c) AC-2: `generatedAt` war der Befund F001 der Vorrunde; jetzt genannt, Feld `version` und `nowCount` sind durch „Kennungen“ und die Ordnungsaussage nur sinngemäß gedeckt (kein Blocker, siehe F003). (d) AC-13/AC-14: die Live-Seiten tragen den neuen Satz nicht; `DATENSCHUTZ_LIVE=1` ist rot für beide Sprachen (nur die zwei neuen Anker). Das ist die von AC-12 geforderte Reihenfolge, aber der Nachweis von AC-13 (grüner Live-Lauf) und AC-14 (wörtlicher Vergleich der veröffentlichten Seiten) für den neuen Satz fehlt bis nach der Veröffentlichung. Für den alten Wortlaut sind beide in der Vorrunde belegt.
**Implementierer:** AC-13 und AC-14 werden nach Merge beider PRs mit neuem `live.txt` und `vergleich.txt` nachgezogen.

## Findings

Finding:
  ID: F001
  Severity: LOW
  Category: spec_violation
  Code reference: docs/reference/datenschutz-entwurf.md:16
  Description: Der Statuskopf (und der englische, Zeile 228) nennt die Veröffentlichung „am 2026-11-17 (henemm/henemm-website#80)“. Der neue Satz zum Zeitpunkt der Abschrift ist dort nicht enthalten; er erscheint erst mit dem nächsten Website-PR.
  Spec requirement: AC-7 — der Statuskopf nennt Freigabe und Veröffentlichung (Datum und Website-PR, nach dem Merge eingetragen)
  Conflict: Solange der Website-PR nicht gemergt ist, ist der Kopf für den neuen Satz unvollständig. Auch jetzt ist er nicht falsch für die übrigen Absätze.
  Remediation: Nach dem Website-Merge im Kopf beider Sprachen den Satz und die neue PR-Nummer nachtragen.

Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: docs/reference/datenschutz-entwurf.md:230
  Description: „Last updated: November 17, 2026“ bleibt gleich, obwohl sich der Text am selben Tag erneut ändert; die Website-Seiten tragen dasselbe Datum.
  Spec requirement: AC-12 — Datum „Stand“ bzw. „Last updated“ ist das Veröffentlichungsdatum
  Conflict: Ist erfüllt, solange der Website-PR am 2026-11-17 live geht; wird er später gemergt, stimmt das Datum nicht mehr.
  Remediation: Datum bei Merge nach dem 17.11. in Entwurf und beiden Seiten anpassen.

Finding:
  ID: F003
  Severity: LOW
  Category: edge_case
  Code reference: scripts/test_datenschutz_text.py:48
  Description: Der Anker deckt nur den Satz zu `generatedAt`; `version` und `nowCount` werden nicht ausdrücklich genannt (nur „Kennungen“ und Ordnungsaussage).
  Spec requirement: AC-2 — kein Feld verschweigen
  Conflict: Strenge Lesart; keine personenbezogenen Daten, vom PO freigegeben.
  Remediation: Kein Blocker; beim Weckruf-Nachtrag (#795 S5c-2) prüfen.

## Confirmations

Confirmation:
  AC: AC-1
  Code reference: docs/reference/datenschutz-entwurf.md:86
  Evidence: Absatz an der richtigen Stelle, inklusive neuem Satz (Zeile 90), wortgleich zur Spec Zeile 78.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: Shared/Services/TranscriptCodec.swift:8
  Evidence: `generatedAt` ist im Code (auch server/src/transcripts.ts:17) und jetzt im Text genannt; der Befund F001 der Vorrunde ist behoben.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: docs/reference/datenschutz-entwurf.md:92
  Evidence: Absatz „Kennung dieser Installation.“ im Diff unverändert, Prüfskript grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: docs/reference/datenschutz-entwurf.md:92
  Evidence: Löschsatz nicht im Diff berührt, Anker im Prüfskript grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: docs/reference/datenschutz-entwurf.md:283
  Evidence: Englischer Satz „It also states when the transcript was created.“ an der Stelle der Spec Zeile 96, Nummerierung unverändert.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: docs/reference/datenschutz-entwurf.md:1
  Evidence: Beleg-Tabelle im Diff nicht berührt; Belege der Vorrunde (`schnitt-1/belege-pfade.txt`) gelten.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: docs/reference/datenschutz-entwurf.md:16
  Evidence: Punkt „Weckruf“ und Statuskopf vorhanden; Kopf nennt die Veröffentlichung von #80, für den neuen Satz siehe F001 (LOW).
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: scripts/test_datenschutz_text.py:48
  Evidence: Beide neuen Sätze (Zeilen 48 und 70) stehen als wörtliche Anker in `ANCHORS`.
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: scripts/test_datenschutz_text.py:70
  Evidence: RED-Commit ab81ccd, danach grün; `green.txt` (742 OK, 1 übersprungen) ist nach der letzten Änderung beendet; eigener Lauf `adversary-test-output.txt` 18 Tests OK.
  Status: CONFIRMED

Confirmation:
  AC: AC-10
  Code reference: scripts/test_datenschutz_text.py:121
  Evidence: `missing_anchors` normalisiert und fängt fehlende Anker; die Gegenprobe-Tests laufen grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-11
  Code reference: CLAUDE.md:1
  Evidence: Absatz seit der Vorrunde unverändert; nicht Teil der Nachbesserung.
  Status: CONFIRMED

Confirmation:
  AC: AC-12
  Code reference: docs/reference/datenschutz-entwurf.md:90
  Evidence: Der vorbereitete Website-Diff (beide `_index.md`, nur der neue Satz, zeichengleich zum Entwurf, keine internen Abschnitte) erfüllt AC-12 am Diff; der Merge folgt erst nach dem loose-ends-PR.
  Status: CONFIRMED

Confirmation:
  AC: AC-15
  Code reference: scripts/test_datenschutz_text.py:1
  Evidence: Nur Entwurf und Prüfskript geändert; nichts unter `LooseEnds/`, `Shared/`, `server/`, kein `project.yml`.
  Status: CONFIRMED

Confirmation:
  AC: AC-16
  Code reference: docs/reference/datenschutz-entwurf.md:1
  Evidence: Reiner Text; Screenshots der Vorrunde `schnitt-1/live-de.png`, `live-en.png`; Satz „Kein Pfad der Geräteliste berührt.“ bleibt gültig.
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

AC-13 und AC-14 sind für den neuen Satz derzeit nicht belegbar und im Live-Lauf rot (nur die zwei neuen Anker), weil AC-12 den Website-Merge erst nach dem loose-ends-Merge erlaubt. Das ist keine Fehlimplementierung, aber ein offener Nachweis.

═══════════════════════════════════════
VERDICT: AMBIGUOUS
═══════════════════════════════════════
Ambiguous findings (require human review):
  AC-13/AC-14: Live-Seiten tragen den neuen Satz noch nicht (DATENSCHUTZ_LIVE=1 meldet genau die zwei neuen Anker); belegbar erst nach Merge beider PRs mit neuem live.txt und vergleich.txt.

Proven points: 14/16 (AC-13 und AC-14 für den neuen Satz offen; für den früheren Wortlaut live belegt)
Tests: 18 passed (Entwurfstests), 0 failed, 1 übersprungen (Live-Test ohne DATENSCHUTZ_LIVE=1); volle Suite laut green.txt 742 OK, 1 übersprungen
Edge cases: Nur LOW-Befunde F001 bis F003
Regressions: None found
Recommendation: Nach beiden Merges live.txt und vergleich.txt neu erzeugen, Statuskopf nachtragen, dann VERIFIED

## Geprüfte Dateien

- sha256:82a2fa573fc85a0199a3941377f8d9cb00aaa1bb6f3a019e0034ee5dbe83dbfc  CLAUDE.md
- sha256:55a2914b1e5ea0345432f3cef2acc5e78441d6a406acb7014f1eaa6006fff322  Shared/Services/TranscriptCodec.swift
- sha256:97977c8a253a0b7c74e4a62776dc780c8d7133bf4fc230877b1d52d4295e73c6  docs/reference/datenschutz-entwurf.md
- sha256:3a94ab26f4e83a3853216a42c3905723b6167d423703733f40186aea67ffcd8e  scripts/test_datenschutz_text.py

## Prüfbasis

- base: 822a2957f48e69bf2a57d72ba1ec205db9e5c808
- blob:21d6b66f0c7c6ab54daed4ae19b9e25f5dfb03bb  CLAUDE.md
- blob:d005d477181f0746d05832b5df5c3b48795ed8c0  Shared/Services/TranscriptCodec.swift
- blob:c1f4e53023aa13e2508db7bb21dfb6028990b022  docs/reference/datenschutz-entwurf.md
- blob:bd1a3fd0b1974b9b8b957847ceff0f1e5aa99804  scripts/test_datenschutz_text.py
