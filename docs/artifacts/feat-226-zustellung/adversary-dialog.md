# Adversary Dialog — feat-226-zustellung
Spec: docs/specs/feat-226-schnitt-2a-uebergabe.md
Datum: 2026-10-07 09:51

## Checkliste
- [x] **AC-1:** **Neue Ortsaufgabe wird übergeben:** Given eine aktive Aufgabe mit Ort, leere Merkliste, keine offene Anfrage, Freigabe da / When `diff` läuft / Then enthält `add` genau diese Aufgabe, und die neue Merkliste hat einen Eintrag mit Fingerabdruck und Titel.
- [x] **AC-2:** **Zweite Änderung erzeugt keine zweite Erinnerung:** Given derselbe Stand wie in 1, die Anfrage ist inzwischen nicht mehr offen (ausgelöst), der Eintrag steht in der Merkliste / When die Aufgabe geändert wurde (z. B. eine Notiz) und `diff` läuft / Then ist `add` leer, und der Eintrag bleibt.
- [x] **AC-3:** **Offene Anfrage bleibt in Ruhe:** Given Eintrag mit gleichem Fingerabdruck und gleichem Titel, Anfrage offen / When `diff` läuft / Then sind `add`, `remove` und `updateContent` leer und die Merkliste unverändert.
- [x] **AC-4:** **Anderer Ort ersetzt die Anfrage:** Given offene Anfrage und Eintrag / When Koordinate oder Ereignis geändert werden (und einmal nur der Name) / Then steht der Bezeichner in `remove` **und** die Aufgabe in `add`, und der Eintrag trägt den neuen Fingerabdruck. War die Anfrage nicht mehr offen, entsteht nur `add`.
- [x] **AC-5:** **Wiederkehrende Aufgabe ist nach dem Abhaken wieder scharf:** Given wiederkehrende Aufgabe (wöchentlich) mit Ort, ausgelöste Anfrage, Eintrag / When `TaskActions.complete` das `dueDate` weitergerückt hat / Then enthält `add` die Aufgabe. Given eine **nicht** wiederkehrende Aufgabe, deren `dueDate` sich ändert / Then bleibt der Fingerabdruck gleich und `add` ist leer.
- [x] **AC-6:** **Ausgefallene Aufgabe wird zurückgenommen, zurückgekehrte erinnert wieder:** Given Eintrag und offene Anfrage / When die Aufgabe erledigt, geparkt oder ihr Ort entfernt wird, oder sie bei 21 offenen Aufgaben auf Rang 21 fällt / Then steht ihr Bezeichner in `remove` (nur wenn offen) und der Eintrag fehlt in der neuen Merkliste. When sie wiederhergestellt wird / Then steht sie wieder in `add`.
- [x] **AC-7:** **Titeländerung ersetzt nur den Inhalt:** Given Eintrag, Anfrage offen / When der Titel sich ändert / Then steht die Aufgabe in `updateContent`, `add` und `remove` sind leer, der Eintrag trägt den neuen Titel. Given die Anfrage ist nicht mehr offen / Then sind alle drei Listen leer und der Eintrag bleibt unverändert.
- [x] **AC-8:** **Ohne Freigabe kommt nichts an, geht nichts verloren:** Given `authorized == false`, Aufgabe mit Ort, keine Anfrage / When `diff` läuft / Then sind `add` und `updateContent` leer und kein Eintrag wurde hinzugefügt. When danach `authorized == true` / Then steht die Aufgabe in `add`. Given `authorized == false` und eine erledigte Aufgabe mit offener Anfrage / Then steht ihr Bezeichner trotzdem in `remove`.
- [x] **AC-9:** **Bezeichner bleibt `place_<uuid>`:** Given eine Aufgabe im Plan / When `diff` läuft / Then entspricht jeder Bezeichner in `add` und `remove` `"place_" + id.uuidString`, und `git diff` zeigt keine Änderung an `Shared/Notifications/PlaceReminders.swift`.
- [x] **AC-10:** **Verwaiste Anfragen verschwinden:** Given eine offene Anfrage `place_<uuid>` ohne Aufgabe im Plan und ohne Eintrag, und eine offene Anfrage `due_<uuid>` / When `diff` läuft / Then steht nur die `place_`-Anfrage in `remove`.
- [x] **AC-11:** **Neuinstallation erzeugt keine Doppelanlage:** Given Merkliste leer, Aufgabe im Plan, ihre Anfrage ist offen / When `diff` läuft / Then ist `add` leer und die neue Merkliste hat den Eintrag. Given dieselbe Aufgabe ohne offene Anfrage / Then steht sie in `add`.
- [x] **AC-12:** **Stabil:** Given dieselbe Eingabe / When `diff` zweimal läuft, und einmal mit umgekehrter Reihenfolge der Aufgaben / Then sind alle Ergebnisse gleich (alle Listen sortiert), und der `Handover` kodiert zu byte-gleichem JSON.
- [x] **AC-13:** **Fingerabdruck ohne Kollision:** Given zwei Orte, die sich in der sechsten Nachkommastelle unterscheiden / Then gleicher Fingerabdruck; Given ein Name mit `|` darin / Then bleibt der Fingerabdruck von einem Ort mit anderen Feldern verschieden.
- [x] **AC-14:** **Regression:** Given `./scripts/sim.sh unit` / Then bleiben alle bestehenden Tests grün (`PlaceReminders`, `DueReminders` unverändert).

## Dialog

### Runde 1
**Adversary:** Fix fuer F001 gezielt angegriffen. Eigener Lauf `sim.sh unit PlaceDeliveryTests` (adversary-test-output.txt): 14 Swift-Testing-Tests gruen, 0 rot, 0 uebersprungen (die "Executed 0 tests"-Zeile ist die XCTest-Huelle, die Tests laufen unter "Test run started"). Gelesen: test-red-f001-output.txt (rot an PlaceDeliveryTests.swift:302 und :303, genau die zwei neuen Erwartungen), test-green-output.txt, test-green-full-output.txt (Test Succeeded, 0 Fehlschlaege, 0 Skips). Scratchpad-Skript fp.swift vergleicht altes `%.5f` mit neuem `(x*1e5).rounded()/1e5 + 0.0` ueber 400023 Werte (23 Grenzwerte, 200000 gleichverteilte in -180...180, 200000 nahe Fuenfstellen-Rastern), je -O und -Onone:
- 0 negative Nullen in der neuen Form ("-0.00000" tritt nie auf; -1e-6, -4e-6, -0.0 ergeben "0.00000"; das Vorzeichen von nz ist minus, nz+0.0 ist plus: `+ 0.0` wirkt und wird auch mit -O nicht wegoptimiert, weil (-0)+(+0)=+0 nach IEEE keine Identitaet ist).
- Gewoehnliche Koordinaten: 53.55 -> "53.55000", 9.93 -> "9.93000" vor und nach dem Fix gleich. Gleich sind auch +-90, +-180 sowie alle 400000 Zufallswerte. Nur 7 Abweichungen: -1e-6, -4e-6, -0.0 (gewollt, Vorzeichen weg), +-5e-6 (alt "0.00000"/"-0.00000", neu "0.00001"/"-0.00001": Halbwerte, beide Formen sind je Zahl deterministisch, fuer den Fingerabdruck harmlos) und +-1e300 (ausserhalb jedes Breiten-/Laengenbereichs; unendlich/NaN erzeugen keine negative Null).
- Dieselbe Zahl ergibt immer denselben String (reine Funktion des Double; Locale en_US_POSIX gesetzt).
Dateien: Vergleich von PlaceReminders.swift gegen origin/main ist leer; neu/geaendert nur PlaceDelivery.swift (neu) und PlaceDeliveryTests.swift (M) plus Doku/Belege; `diff` ist 33 Zeilen, keine Funktion ueber 50; kein `try?` (einziger Treffer "Entry?" als Typ). Randfaelle diff: leere Merkliste/leerer Plan, doppelte Aufgaben-ID (uniquingKeysWith), nicht-place_ Bezeichner unberuehrt, ohne Freigabe nur remove.
**Implementierer:** Fix liegt in PlaceDelivery.swift:38-40, Test fingerprintHasNoCollision ergaenzt um -0.000001/0.000001 und -0.000004/0.000004.

### Runde 2
**Adversary:** Nachfassen auf neue Fehler durch den Fix. (a) Verschiebt die Vorab-Rundung die Sechste-Stelle-Regel (AC-13)? Nein: Werte, die sich in der sechsten Stelle unterscheiden, landen bei gleicher fuenfter Stelle im selben Raster; die Skriptlaeufe zeigen keine Abweichung zum alten Verhalten ausser den Halbwerten. (b) Ueberlauf bei Grenzwerten: 180*1e5 = 1.8e7, weit unter der Double-Praezisionsgrenze, +-90/+-180 exakt. (c) AC-5 (Zyklus als Sekunde, unveraendert Z.41-44) und AC-12 (Sortierung in `changes`, Z.105-117, unveraendert) sind vom Fix nicht beruehrt; die Tests dazu sind im eigenen Lauf gruen. (d) Alle uebrigen ACs im eigenen Lauf gruen (14 Tests, AC-1 bis AC-13; AC-14 durch den vollen Lauf). Kein neuer Befund; der Early-Agreement-Verdacht ist durch die 400k-Werte-Gegenprobe und das rote Vorher-Protokoll entkraeftet.
**Implementierer:** Keine weiteren Aenderungen noetig.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

Confirmation:
  AC: AC-1
  Code reference: Shared/Notifications/PlaceDelivery.swift:93
  Evidence: Kein Eintrag und nicht offen ergibt .add, Eintrag wird in Z.79 notiert; Test gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: Shared/Notifications/PlaceDelivery.swift:95
  Evidence: Gleicher Abdruck, nicht offen ergibt .keep; Notizaenderung beeinflusst den Abdruck nicht. Test gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: Shared/Notifications/PlaceDelivery.swift:95
  Evidence: Offen, gleicher Titel und Abdruck ergibt .keep; withdrawn trifft die Kennung nicht. Test gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: Shared/Notifications/PlaceDelivery.swift:94
  Evidence: Anderer Abdruck: offen ergibt .replace (remove plus add), nicht offen nur .add; Name im Abdruck (Z.45). Test gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: Shared/Notifications/PlaceDelivery.swift:42
  Evidence: Zyklus nur bei repeatRule und dueDate; Test mit TaskActions.complete und Einmalaufgabe gruen, vom Fix unberuehrt.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: Shared/Notifications/PlaceDelivery.swift:58
  Evidence: Eintraege ausserhalb plan.watched gefiltert, offene Kennungen via withdrawn entfernt; Rueckkehr ergibt Regel 1. Zwei Tests (inkl. Rang 21) gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: Shared/Notifications/PlaceDelivery.swift:95
  Evidence: Offen und anderer Titel ergibt .updateContent, nicht offen .keep. Test gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: Shared/Notifications/PlaceDelivery.swift:61
  Evidence: guard authorized: add/updateContent leer, remove bleibt, Eintraege unveraendert. Test gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: Shared/Notifications/PlaceDelivery.swift:102
  Evidence: Praefix PlaceReminders.identifierPrefix; PlaceReminders.swift gegen origin/main unveraendert (Vergleich leer). Test gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-10
  Code reference: Shared/Notifications/PlaceDelivery.swift:102
  Evidence: hasPrefix place_ und nicht in watched ergibt remove; due_ wird nie beruehrt. Test gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-11
  Code reference: Shared/Notifications/PlaceDelivery.swift:93
  Evidence: Ohne Eintrag, offen ergibt .adopt (Eintrag Z.79, kein add); ohne offene Anfrage .add. Test gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-12
  Code reference: Shared/Notifications/PlaceDelivery.swift:112
  Evidence: Alle Listen sortiert, Eintraege nach uuidString; Eingabereihenfolge irrelevant; JSON byte-gleich im Test gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-13
  Code reference: Shared/Notifications/PlaceDelivery.swift:39
  Evidence: F001 behoben: erst runden, + 0.0 entfernt negative Null; Skript: 0 negative Nullen in 400023 Werten, -O und -Onone; Name zuletzt (Z.45). Test gruen (vorher rot).
  Status: CONFIRMED

Confirmation:
  AC: AC-13
  Code reference: LooseEndsTests/PlaceDeliveryTests.swift:302
  Evidence: Neue Erwartungen fuer Rundung auf negative Null; in test-red-f001-output.txt rot, jetzt gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-14
  Code reference: Shared/Notifications/PlaceDelivery.swift:7
  Evidence: Voller Lauf test-green-full-output.txt: Test Succeeded, 0 Fehlschlaege, 0 Skips; PlaceReminders.swift unveraendert.
  Status: CONFIRMED

## Verdict

═══════════════════════════════════════
VERDICT: VERIFIED
═══════════════════════════════════════
Der Fix fuer F001 haelt. Kein neuer Befund.
Tests: 14 bestanden (PlaceDeliveryTests), voller Lauf gruen, 0 fehlgeschlagen, 0 uebersprungen
Edge cases: negative Null, +-90/+-180, Halbwerte, 400023 Vergleichswerte alt gegen neu
Regressions: None found
Checklist: 14/14 points proven

## Geprüfte Dateien

- sha256:5be597518718650e006ccaf2f9a0dc6c0842d4df9325e15b5b68220d2a5a1229  LooseEndsTests/PlaceDeliveryTests.swift
- sha256:ca879537029032352f74dccc5dbaea5ce832ea6abca90fecf08506ca116683db  Shared/Notifications/PlaceDelivery.swift

## Prüfbasis

- base: 8d0304ceac3b33f848d862fa69533f7520d7135a
- blob:3a156a9aba696a758d832a6c4c6685a093ae61e7  LooseEndsTests/PlaceDeliveryTests.swift
- blob:4d92eb33ecdc61f9d45ae169cafa670663bfade7  Shared/Notifications/PlaceDelivery.swift
