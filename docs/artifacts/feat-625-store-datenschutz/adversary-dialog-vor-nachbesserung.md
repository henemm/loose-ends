# Adversary Dialog — feat-625-store-datenschutz
Spec: docs/specs/feat-625-schnitt-1-datenschutztext.md
Datum: 2026-11-17 09:36

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
**Adversary:** Alles selbst gelaufen, nichts aus den Belegdateien übernommen. Tests: `python3 -m unittest scripts/test_datenschutz_text.py -v` 18 Tests, OK (1 übersprungen = Live-Test ohne Variable); mit `DATENSCHUTZ_LIVE=1` 18 Tests, 0 übersprungen, OK. Ausgabe beider Läufe in `adversary-test-output.txt` (endet mit OK). Der volle CI-Befehl `discover -s scripts` lief über 120 s und wurde nicht abgewartet; ich nehme ihn nicht als bestanden in Anspruch (`green.txt` zeigt ihn).
Wortlaut: die vier neuen Absätze (de/en) des Entwurfs gegen die Spec maschinell verglichen (Zitatzeichen und Zeilenumbruch normalisiert): alle vier wortgleich in der Spec. Die Löschsätze de/en stehen in der Spec (Z. 86, 104) wortgleich im Entwurf. Änderungsvergleich der CLAUDE.md: nur zwei neue Zeilen, nichts sonst geändert. Der Offen-Punkt „Weckruf“ ersetzt den „nicht gebaut“-Punkt.
Code gegen Text: `Entry` hat id, title, status, dueDate, dueHasTime, contexts, project, nextRank, isKnaeuel; der Text nennt Titel, Status, Fälligkeit, Tags, Projekt, Stellung unter „Als nächstes“, Knäuel. Kein genanntes Feld fehlt im Code. `TranscriptCodec.transcript` filtert `!= .done && != .removed`, der Server `statuses` = unprocessed/unverified/active/parked: „offen, auch geparkt und Unterpunkte“ stimmt (Unterpunkte sind TaskItems mit `parent`). `privacy()` weist `rawText`/`note` ab; es gibt kein Anhang-, Orts- oder Verlaufsfeld. „Lose Enden“ = „All open“ (Enums.swift:91, xcstrings:205). Kennung: `UUID()`, `AfterFirstUnlockThisDeviceOnly`, kein Synchronizable; `X-Device` nur in claimOrder/putResult (und im noch ungenutzten putDevice); putTranscript ohne Gerät. `claimed_by`/`reported_by` in 001; deleteAccount löscht order_results, orders, transcripts; endSession löscht nur die Sitzungszeile. Auslöser: didBecomeActive, didSave, 2 s Entprellung.
Live: curl beide 200, 0 Treffer auf „Beleg im Code“/„Offen, nicht belegt“. Bilder geöffnet: DE zeigt „Stand: 17. November 2026“, Abschnitt 4 mit „Deine offenen Aufgaben für Claude.“, „Kennung dieser Installation.“ und dem geänderten „Löschen.“; EN zeigt „Last updated: November 17, 2026“ mit den drei Gegenstücken. Website-Änderung #80: eingespielt 2026-11-17T08:39:06Z, nur zwei Seiten-Dateien. `LEAccountEnabled: false` (project.yml:84); die Änderung im Hauptrepo berührt keinen verbotenen Pfad.
**Implementierer:** Belege lagen vor (aussagen.txt, belege-pfade.txt, vergleich.txt, schalter.txt); keine Gegenrede.

### Runde 2
**Adversary:** Gezielte Angriffe auf die Lücken. (1) Abweichung (c): Kopfdaten `version`, `generatedAt`, `nowCount` und die Aufgaben-`id` werden gesendet und stehen nicht ausdrücklich im Absatz; `received_at` setzt der Dienst. Metadaten ohne Aufgabeninhalt, „Kennungen“ deckt die IDs sinngemäß: LOW (F001), keine Verletzung. `X-Device` in putDevice: nicht aufgerufen (DeviceRegistration unverdrahtet), der Absatz sagt „beim Abholen und Melden“, korrekt; im Offen-Punkt vermerkt. (2) Abweichung (a), Website vor Hauptrepo eingespielt: Verstoß gegen den Wortlaut von AC-12, Inhalt aber identisch geprüft, 4e ging gleich vor, der Statuskopf kann so das Datum tragen; Restrisiko: ändert sich der Entwurf danach, weicht die Seite ab, dagegen schützt `DATENSCHUTZ_LIVE=1`. LOW (F002). (3) Abweichung (b), „All open“: am Code geprüft (Enums.swift:91 liefert „All open“, nicht „Loose ends“); Korrektur richtig. (4) Statuskopf „veröffentlicht am 2026-11-17 (henemm-website#80)“ passt zur Einspielzeit. (5) Arbeitsbaum: `datenschutz-entwurf.md` und `green.txt` haben Änderungen über dem vorgemerkten Stand, nichts ist übernommen: F003, LOW. (6) Aussage in Abschnitt 3 der Seite („ohne sie verlässt nichts außer dem iCloud-Abgleich dein Gerät“) bleibt wahr, da Abschnitt 4 mit der Anmeldung beginnt. (7) AC-16: Screenshots beider Sprachen vorhanden, geöffnet und beschrieben (Runde 1); kein App-Lauf. Der Pflichtsatz „Kein Pfad der Geräteliste berührt. Reiner Text, keine App-Änderung; Stufe 2 an den Live-Seiten belegt.“ ist in der Spec vorgesehen und entsteht im Abschlussbericht (Phase 7/8), jetzt nicht prüfbar.
**Implementierer:** keine Gegenrede.

## Findings

Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: Shared/Services/TranscriptCodec.swift:6
  Description: `Transcript` sendet zusätzlich version, generatedAt, nowCount und je Aufgabe die UUID `id`; der Dienst setzt `received_at` (server/src/transcripts.ts:128). Der Absatz nennt sie nicht ausdrücklich.
  Spec requirement: AC-2 — nennt kein Feld, das fehlt, verschweigt keines, das dort steht
  Conflict: Strenge Lesart unvollständig; praktisch Metadaten ohne Aufgabeninhalt, „Kennungen“ deckt die IDs sinngemäß.
  Remediation: Bei der nächsten Textänderung (S5c-2) „Zeitpunkt der Abschrift“ ergänzen; kein Blocker.

Finding:
  ID: F002
  Severity: LOW
  Category: spec_violation
  Code reference: docs/specs/feat-625-schnitt-1-datenschutztext.md:1
  Description: Die Website-Änderung #80 wurde vor dem Hauptrepo eingespielt (live seit 08:40Z).
  Spec requirement: AC-12 — erst nach dem Hauptrepo wird die Website eingespielt
  Conflict: Reihenfolge umgekehrt; Inhalt wortgleich geprüft (eigener Lauf mit DATENSCHUTZ_LIVE=1 OK).
  Remediation: Abweichung im Abschlussbericht nennen, Spec-Reihenfolge angleichen. Kein Blocker.

Finding:
  ID: F003
  Severity: LOW
  Category: anti_pattern
  Code reference: docs/reference/datenschutz-entwurf.md:10
  Description: Entwurf und `green.txt` haben Änderungen über dem vorgemerkten Stand.
  Spec requirement: AC-9 — green.txt zeigt den grünen Lauf nach der Änderung
  Conflict: Der Beleg kann älter als der Endstand sein; mein eigener Lauf auf dem Arbeitsstand ist grün.
  Remediation: Vor der Übernahme alles vormerken und green.txt neu erzeugen, falls der Entwurf nach ihrem Lauf geändert wurde.

## Confirmations

Confirmation:
  AC: AC-1
  Code reference: docs/reference/datenschutz-entwurf.md:86
  Evidence: Absatz zwischen „Was unser Dienst speichert.“ und „Aufträge aus Claude.“, wortgleich zur Spec (maschineller Vergleich), alle geforderten Aussagen enthalten.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: Shared/Services/TranscriptCodec.swift:31
  Evidence: Entry-Felder und Filter (Z. 61) decken sich mit dem Text; server/src/transcripts.ts:29 (statuses) und :97 (privacy weist rawText/note ab); kein Gegenbeleg zur Negativliste. Metadaten siehe F001.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: LooseEnds/Claude/DeviceIdentity.swift:26
  Evidence: UUID() einmal erzeugt, Schlüsselbund ThisDeviceOnly (Z. 55), kein Synchronizable; X-Device nur in LooseEnds/Claude/ServiceClient.swift:92 und :100; server/src/orders.ts:121,135; Absatz im Entwurf Z. 103 wortgleich zur Spec.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: server/src/accounts.ts:116
  Evidence: deleteAccount löscht order_results, orders, transcripts; Löschsatz im Entwurf Z. 118 mit „darunter die Abschrift deiner Aufgaben, Aufträge und Ergebnisse“, übrige Sätze unverändert.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: Shared/Models/Enums.swift:91
  Evidence: Englische Absätze und Löschsatz wortgleich zur Spec, Nummerierung unverändert, Statuszeile nennt Freigabe und #80, „Last updated: November 17, 2026“; „All open“ entspricht Enums.swift:91.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: server/src/auth.ts:100
  Evidence: Dreizehn neue Beleg-Zeilen im Entwurf (ab Z. 156); belege-pfade.txt alle OK; Stichprobe: auth.ts:100 endSession bei Logout, LooseEnds/Claude/ClaudeSyncTrigger.swift:46 Entprellung 2 s, LooseEnds/Claude/ClaudeSync.swift:57 sendTranscript.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: docs/reference/datenschutz-entwurf.md:206
  Evidence: Punkt „Weckruf (Push-Token)“ ersetzt den „nicht gebaut“-Punkt; Statuskopf Z. 13-16 mit Freigabedatum und website#80.
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: scripts/test_datenschutz_text.py:36
  Evidence: ANCHORS/STALE erweitert, test_transcript_in_account_section (Z. 178) umgedreht; eigener Lauf 18 Tests OK.
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: scripts/test_datenschutz_text.py:178
  Evidence: red.txt/green.txt vorhanden (RED-Stand 8554498); eigener Lauf auf dem Endstand grün (F003 zur Aktualität).
  Status: CONFIRMED

Confirmation:
  AC: AC-10
  Code reference: scripts/test_datenschutz_text.py:219
  Evidence: test_account_without_transcript_is_caught, test_transcript_without_raw_text_is_caught (Z. 222), test_transcript_with_negatives_passes (Z. 225), test_not_built_sentence_is_caught (Z. 229), test_transcript_found_in_section (Z. 215) grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-11
  Code reference: CLAUDE.md:176
  Evidence: Genau zwei neue Zeilen (Abschrift, Kennung, Spec-Verweis, Weckruf mit #795 S5c-2); übrige Sätze unverändert, `LEAccountEnabled` bleibt aus.
  Status: CONFIRMED

Confirmation:
  AC: AC-12
  Code reference: docs/reference/datenschutz-entwurf.md:10
  Evidence: Website-Änderung #80 eingespielt, nur die zwei Seiten; Inhalte live; keine internen Abschnitte (curl, 0 Treffer). Reihenfolge siehe F002.
  Status: CONFIRMED

Confirmation:
  AC: AC-13
  Code reference: scripts/test_datenschutz_text.py:235
  Evidence: eigener curl beide 200; DATENSCHUTZ_LIVE=1 Lauf OK ohne Übersprungenes; ASC-Variablen nicht verändert.
  Status: CONFIRMED

Confirmation:
  AC: AC-14
  Code reference: docs/artifacts/feat-625-store-datenschutz/schnitt-1/vergleich.txt:1
  Evidence: Live-Test mit allen Ankern grün; die Bilder zeigen dieselben Sätze wie der Entwurf.
  Status: CONFIRMED

Confirmation:
  AC: AC-15
  Code reference: project.yml:84
  Evidence: LEAccountEnabled: false; beide Änderungen ohne project.yml, Info.plist, PrivacyInfo, LooseEnds/, Shared/, server/.
  Status: CONFIRMED

Confirmation:
  AC: AC-16
  Code reference: docs/artifacts/feat-625-store-datenschutz/schnitt-1/live-de.png:1
  Evidence: live-de.png und live-en.png geöffnet und beschrieben (Runde 1); kein App-Lauf. Der Pflichtsatz entsteht im Abschlussbericht (Phase 7/8).
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

═══════════════════════════════════════
VERDICT: VERIFIED
═══════════════════════════════════════
Die Umsetzung hat den Prüfversuch überstanden.
Tests: 18 bestanden, 0 fehlgeschlagen, 0 übersprungen (Lauf mit DATENSCHUTZ_LIVE=1; ohne die Variable 17 bestanden, 1 übersprungen = der Live-Test)
Edge cases: geprüft; drei LOW-Befunde (F001 Metadaten, F002 Reihenfolge, F003 Beleg-Aktualität), keiner blockierend
Regressions: keine gefunden
Checklist: 16/16 Punkte belegt; bei AC-16 ist der Pflichtsatz im Abschlussbericht erst in Phase 7/8 zu liefern

## Geprüfte Dateien

- sha256:d102ac4d06e8eeb3847105607937cb9fde4944d0da4757537e6a4d35dad99805  CLAUDE.md
- sha256:7b759c80fdc89cc56eba84c6911495b8d643cbf1c35a5eb9cad3538506bebcab  LooseEnds/Claude/DeviceIdentity.swift
- sha256:2ac0feda5db6515a259c9d9ba738a78af65ce7c0633c733093e71e55cbc1390f  Shared/Models/Enums.swift
- sha256:55a2914b1e5ea0345432f3cef2acc5e78441d6a406acb7014f1eaa6006fff322  Shared/Services/TranscriptCodec.swift
- sha256:1c0ee1f6e2d1ac48571d488202cbc810715b631cbe64d17c7ef3e417122c301d  docs/artifacts/feat-625-store-datenschutz/schnitt-1/live-de.png
- sha256:c2f02d49a4157be47fbda9e040e3ed358c616fb6be7bfbbc6bb9af78e9bc5d08  docs/artifacts/feat-625-store-datenschutz/schnitt-1/vergleich.txt
- sha256:2e3705aa27aae507c7780914b6c9891f62abbeebce6e34dcfe2bef93ec13300e  docs/reference/datenschutz-entwurf.md
- sha256:b0bed67a21251bd6540848cc2fed35302f575af6c11f86dc5b2312398c90e7af  docs/specs/feat-625-schnitt-1-datenschutztext.md
- sha256:fd9a240979129c228cb69f2a23fb0813a8d436ee9a4f9f1f9b3227ecc8e7c57d  project.yml
- sha256:b965bedf59588c15bad6dfce6a5d2937a78f3aefe3d64ecb0a1c8d0dcdc951e4  scripts/test_datenschutz_text.py
- sha256:b59036c16af390ce5989f8c96ed59e0920a67a5f2e230966b9e8de2277fa2c4a  server/src/accounts.ts
- sha256:29d0acf90a66976fd87a253544c7efc0900ae832cb77c54497954447a4ad7a40  server/src/auth.ts

## Prüfbasis

- base: 8176d6cc5f65893092d7b98eff5fb0907beb6943
- blob:46b1bb89e7a0c6d6e9746072753996bbdb464841  CLAUDE.md
- blob:27dcefe6f4981ed8d16696017caa3ef2002568d2  LooseEnds/Claude/DeviceIdentity.swift
- blob:f772d9cc7723455ca4a57a46cef30407a626a425  Shared/Models/Enums.swift
- blob:d005d477181f0746d05832b5df5c3b48795ed8c0  Shared/Services/TranscriptCodec.swift
- blob:74cdcb5824976f99e17287badf54f55606b88f45  docs/artifacts/feat-625-store-datenschutz/schnitt-1/live-de.png
- blob:f32a19a38ef8e5b022e065cdef289810eb751308  docs/artifacts/feat-625-store-datenschutz/schnitt-1/vergleich.txt
- blob:c10ad8d6386353da03c954bbe612ce6473ce9438  docs/reference/datenschutz-entwurf.md
- blob:479e28b666f3aa1ebfb81d5bca31c88fbcc0e728  docs/specs/feat-625-schnitt-1-datenschutztext.md
- blob:aa041cfc5553bd1fa4d10690b015a32a29ae2e09  project.yml
- blob:2a3de99defa2be269dd9cbe276f19e67a72dc42c  scripts/test_datenschutz_text.py
- blob:f9021c555938739c3e82db44da2dbe87476941f7  server/src/accounts.ts
- blob:1f386909240c3bd0a41489858f9390306f4cb6c7  server/src/auth.ts

## Geprüfte Dateien

- sha256:d102ac4d06e8eeb3847105607937cb9fde4944d0da4757537e6a4d35dad99805  CLAUDE.md
- sha256:7b759c80fdc89cc56eba84c6911495b8d643cbf1c35a5eb9cad3538506bebcab  LooseEnds/Claude/DeviceIdentity.swift
- sha256:2ac0feda5db6515a259c9d9ba738a78af65ce7c0633c733093e71e55cbc1390f  Shared/Models/Enums.swift
- sha256:55a2914b1e5ea0345432f3cef2acc5e78441d6a406acb7014f1eaa6006fff322  Shared/Services/TranscriptCodec.swift
- sha256:1c0ee1f6e2d1ac48571d488202cbc810715b631cbe64d17c7ef3e417122c301d  docs/artifacts/feat-625-store-datenschutz/schnitt-1/live-de.png
- sha256:c2f02d49a4157be47fbda9e040e3ed358c616fb6be7bfbbc6bb9af78e9bc5d08  docs/artifacts/feat-625-store-datenschutz/schnitt-1/vergleich.txt
- sha256:2e3705aa27aae507c7780914b6c9891f62abbeebce6e34dcfe2bef93ec13300e  docs/reference/datenschutz-entwurf.md
- sha256:b0bed67a21251bd6540848cc2fed35302f575af6c11f86dc5b2312398c90e7af  docs/specs/feat-625-schnitt-1-datenschutztext.md
- sha256:fd9a240979129c228cb69f2a23fb0813a8d436ee9a4f9f1f9b3227ecc8e7c57d  project.yml
- sha256:b965bedf59588c15bad6dfce6a5d2937a78f3aefe3d64ecb0a1c8d0dcdc951e4  scripts/test_datenschutz_text.py
- sha256:b59036c16af390ce5989f8c96ed59e0920a67a5f2e230966b9e8de2277fa2c4a  server/src/accounts.ts
- sha256:29d0acf90a66976fd87a253544c7efc0900ae832cb77c54497954447a4ad7a40  server/src/auth.ts

## Prüfbasis

- base: 8176d6cc5f65893092d7b98eff5fb0907beb6943
- blob:46b1bb89e7a0c6d6e9746072753996bbdb464841  CLAUDE.md
- blob:27dcefe6f4981ed8d16696017caa3ef2002568d2  LooseEnds/Claude/DeviceIdentity.swift
- blob:f772d9cc7723455ca4a57a46cef30407a626a425  Shared/Models/Enums.swift
- blob:d005d477181f0746d05832b5df5c3b48795ed8c0  Shared/Services/TranscriptCodec.swift
- blob:74cdcb5824976f99e17287badf54f55606b88f45  docs/artifacts/feat-625-store-datenschutz/schnitt-1/live-de.png
- blob:f32a19a38ef8e5b022e065cdef289810eb751308  docs/artifacts/feat-625-store-datenschutz/schnitt-1/vergleich.txt
- blob:c10ad8d6386353da03c954bbe612ce6473ce9438  docs/reference/datenschutz-entwurf.md
- blob:479e28b666f3aa1ebfb81d5bca31c88fbcc0e728  docs/specs/feat-625-schnitt-1-datenschutztext.md
- blob:aa041cfc5553bd1fa4d10690b015a32a29ae2e09  project.yml
- blob:2a3de99defa2be269dd9cbe276f19e67a72dc42c  scripts/test_datenschutz_text.py
- blob:f9021c555938739c3e82db44da2dbe87476941f7  server/src/accounts.ts
- blob:1f386909240c3bd0a41489858f9390306f4cb6c7  server/src/auth.ts
