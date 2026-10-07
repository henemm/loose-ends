# Adversary Dialog — feat-226-zustellung
Spec: docs/specs/feat-226-schnitt-2a-uebergabe.md
Datum: 2026-10-07 09:47

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
- [ ] **AC-13:** **Fingerabdruck ohne Kollision:** Given zwei Orte, die sich in der sechsten Nachkommastelle unterscheiden / Then gleicher Fingerabdruck; Given ein Name mit `|` darin / Then bleibt der Fingerabdruck von einem Ort mit anderen Feldern verschieden.
- [x] **AC-14:** **Regression:** Given `./scripts/sim.sh unit` / Then bleiben alle bestehenden Tests grün (`PlaceReminders`, `DueReminders` unverändert).

## Dialog

### Runde 1
**Adversary:**
Lauf selbst: `./scripts/sim.sh unit PlaceDeliveryTests` (docs/artifacts/feat-226-zustellung/adversary-test-output.txt): 14 Tests in Suite PlaceDelivery bestanden, 0 fehlgeschlagen, 0 übersprungen, Test Succeeded. Belege gelesen: test-red-output.txt bricht mit 'cannot find type PlaceDelivery' (echtes RED), test-green-full-output.txt: voller macOS-Lauf Test Succeeded inkl. Suites PlaceReminders, DueReminders (AC-14). Der Diff gegen origin/main für PlaceReminders.swift ist leer; der Arbeitsbaum enthält als Code nur PlaceDelivery.swift und PlaceDeliveryTests.swift, kein `try?`, `diff` hat 33 Zeilen.

Confirmation:
  AC: AC-1
  Code reference: Shared/Notifications/PlaceDelivery.swift:420
  Evidence: Kein Eintrag und nicht offen -> action() liefert .add (Zeile 446), Eintrag wird in Zeile 432 mit Fingerabdruck und Titel gesetzt; Test newTaskIsHandedOver.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: Shared/Notifications/PlaceDelivery.swift:447
  Evidence: Gleicher Fingerabdruck, nicht offen: action() endet in .keep (Zeile 448), kein add, Eintrag bleibt; Test secondChangeDoesNotRemindAgain prüft add leer und Merkliste gleich.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: Shared/Notifications/PlaceDelivery.swift:448
  Evidence: offen und Titel gleich -> .keep, remove kommt nur aus withdrawn (Zeile 453-456) und ist für beobachtete Aufgaben leer; Test openRequestStaysUntouched.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: Shared/Notifications/PlaceDelivery.swift:447
  Evidence: anderer Fingerabdruck: offen -> .replace (remove.insert plus add, Zeile 427-429), nicht offen -> .add ohne remove. Kein Pfad erzeugt remove bei nicht offener Anfrage. Test otherPlaceReplacesRequest prüft Breite, Ereignis, Name je offen und ausgelöst. Auch (Eintrag + offen + geänderter Zyklus) läuft über denselben Zweig, kein Gegenpfad gefunden.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: Shared/Notifications/PlaceDelivery.swift:395
  Evidence: Zyklus nur bei repeatRule != nil UND dueDate != nil, sonst '-'; repeatRule ohne dueDate ergibt '-', stabil. Test repeatingTaskIsArmedAgain benutzt echtes TaskActions.complete und prüft, dass die Einmal-Aufgabe mit geändertem dueDate nicht in add steht.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: Shared/Notifications/PlaceDelivery.swift:411
  Evidence: kept filtert Einträge auf plan.watched; withdrawn (Zeile 453) nimmt offene place_-Bezeichner ohne Plan-Eintrag. Rang-21-Test: Eintrag tasks[19] fällt durch die zugefügte 'Neueste' aus watched, remove == [tasks[19]], Eintrag fehlt in der Merkliste (withLast.unwatched wird nur für tasks[20] geprüft). Der Aufbau ist umständlich, beweist aber den Rangverlust samt Merklisten- und Anfrage-Rücknahme. Rückkehr: Test droppedTaskIsWithdrawn (done, parked) und Ort entfernt; add nach restore bewiesen.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: Shared/Notifications/PlaceDelivery.swift:448
  Evidence: offen und Titel anders -> .updateContent, Eintrag mit neuem Titel (Zeile 430, 432); nicht offen -> .keep. Test titleChangeOnlyReplacesContent.
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: Shared/Notifications/PlaceDelivery.swift:414
  Evidence: guard authorized gibt vor jeder Schleife zurück: add/updateContent leer, entries nur gefiltertes kept (kein Neuzugang, kein adopt), remove aus withdrawn bleibt. Test withoutAuthorizationNothingIsNoted. Ungetestet, aber im Code geschlossen: unauthorized plus offene Anfrage einer beobachteten Aufgabe vermerkt nichts.
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: Shared/Notifications/PlaceDelivery.swift:455
  Evidence: Bezeichner stammen aus Reminder.identifier bzw. Präfix place_; Diff für PlaceReminders.swift gegen origin/main leer; Test identifiersKeepPrefix.
  Status: CONFIRMED

Confirmation:
  AC: AC-10
  Code reference: Shared/Notifications/PlaceDelivery.swift:455
  Evidence: hasPrefix(PlaceReminders.identifierPrefix) filtert due_ aus; Test orphanedRequestsDisappear.
  Status: CONFIRMED

Confirmation:
  AC: AC-11
  Code reference: Shared/Notifications/PlaceDelivery.swift:446
  Evidence: Kein Eintrag und offen -> .adopt (kein add, aber Eintrag in Zeile 432); ohne offene Anfrage -> add. Test reinstallDoesNotDoubleRequest. Nur nach dem authorized-Guard erreichbar.
  Status: CONFIRMED

Confirmation:
  AC: AC-12
  Code reference: Shared/Notifications/PlaceDelivery.swift:465
  Evidence: add/updateContent nach identifier, remove aus Set sortiert, Einträge nach uuidString sortiert; Dictionary-Reihenfolge schlägt nicht durch. Test resultIsStable (vorwärts, wiederholt, umgekehrt, JSON byte-gleich). Pending-Reihenfolge ist als Set bedeutungslos. Doppelte TaskItems gleicher id im Array: erster gewinnt (Zeile 417), nur bei abweichenden Zyklen reihenfolgeabhängig, außerhalb des Vertrags.
  Status: CONFIRMED

Confirmation:
  AC: AC-14
  Code reference: LooseEndsTests/PlaceDeliveryTests.swift:1
  Evidence: Voller macOS-Lauf test-green-full-output.txt: Test Succeeded, PlaceReminders und DueReminders grün; eigener Lauf der Suite grün.
  Status: CONFIRMED
**Implementierer:** keine Antwort im Rahmen dieser Prüfung.

### Runde 2
**Adversary:**
Angriff auf AC-13: String(format: "%.5f") erhält das Vorzeichen bei Werten, die auf null runden. Selbst ausgeführt (swiftc, en_US_POSIX): -0.000001 -> "-0.00000", 0.000001 -> "0.00000", -0.000004 -> "-0.00000". Zwei Orte, die sich nur jenseits der fünften Stelle unterscheiden, haben damit verschiedene Fingerabdrücke, sobald die Koordinate um 0 liegt (Nullmeridian: London, Ostküste Spaniens, Westfrankreich; Äquator). Folge: Replace/add, also eine zweite Erinnerung. Der Test fingerprintHasNoCollision prüft nur 53.550001 gegen 53.550004 und fängt es nicht.

Finding:
  ID: F001
  Severity: MEDIUM
  Category: spec_violation
  Code reference: Shared/Notifications/PlaceDelivery.swift:393
  Description: longitude/latitude werden mit String(format: "%.5f", ...) formatiert; ein negativer Wert, der auf null rundet, ergibt "-0.00000", der positive "0.00000".
  Spec requirement: AC-13 — zwei Orte, die sich in der sechsten Nachkommastelle unterscheiden, haben gleichen Fingerabdruck.
  Conflict: Eingabe place(longitude: -0.000001) gegen place(longitude: 0.000001) (Breite je 53.55, Name, Ereignis gleich) liefert verschiedene Fingerabdrücke ("...|-0.00000|..." gegen "...|0.00000|...").
  Remediation: Wert vor der Formatierung runden und negative Null normalisieren, z. B. let v = (x * 1e5).rounded() / 1e5; dann v + 0.0 verwenden (-0.0 + 0.0 ist 0.0), dann formatieren; Test mit longitude -0.000001 gegen 0.000001 ergänzen.

Weitere Angriffe ohne Befund: Rundung bei ...5 ist deterministisch (gleiche Eingabe gleiche Ausgabe); Gebietsschema ist über Locale en_US_POSIX fest (Zeile 391-393, nicht eigens getestet); Name mit '|' kollisionsfrei, weil der Name zuletzt steht und die Felder davor kein '|' enthalten. Unauthorized plus offene Anfrage beobachteter Aufgabe: Code kehrt vor adopt zurück. Fehlt eine Aufgabe in `tasks`, aber im Plan, wird der Zyklus '-' (Zeile 421): außerhalb des Vertrags, da der Aufrufer beide Listen aus derselben Quelle bildet (Hinweis, kein Befund).

Confirmation:
  AC: AC-1
  Code reference: Shared/Notifications/PlaceDelivery.swift:432
  Evidence: Runde 2 erneut geprüft: Eintrag trägt Fingerabdruck und Titel des Reminders.
  Status: CONFIRMED
**Implementierer:** keine Antwort im Rahmen dieser Prüfung.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`). Keine verdächtigen Zeilen angehängt.

## Verdict
═══════════════════════════════════════
VERDICT: BROKEN
═══════════════════════════════════════
Finding F001: Fingerabdruck unterscheidet -0.00000 von 0.00000 (AC-13)
  Severity: MEDIUM
  Evidence: Shared/Notifications/PlaceDelivery.swift:393
  Reproduction: Orte mit longitude -0.000001 und 0.000001 (sonst gleich) in PlaceDelivery.fingerprint vergleichen; sie sind verschieden, sollen gleich sein.
Tests: 14 passed, 0 failed, 0 übersprungen (PlaceDelivery); voller Lauf grün
Checklist: 13/14 points proven (AC-13 disproven)

## Geprüfte Dateien

- sha256:c0a63cf6463178e679ffcca0d1e590ca4f4a614ae46502d9820ede5d4639bb62  LooseEndsTests/PlaceDeliveryTests.swift
- sha256:553e3f1ae7ab1f3a686f6a9821df072e5a2c7cd5080cabdb9a2725ed2b203ab7  Shared/Notifications/PlaceDelivery.swift

## Prüfbasis

- base: 8d0304ceac3b33f848d862fa69533f7520d7135a
- blob:839eaa215cccb287db4be9211d75fa0784920cc6  LooseEndsTests/PlaceDeliveryTests.swift
- blob:2d0a89365a6b9601934f12bb18bf36fd47507ccc  Shared/Notifications/PlaceDelivery.swift
