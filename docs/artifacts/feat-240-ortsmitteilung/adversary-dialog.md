# Adversary-Dialog feat-240-ortsmitteilung

### Runde 1
Befunde der ersten Runde, jeweils mit der Antwort des Orchestrators und der Wertung in Runde 2:
- F001 (HIGH): `respond` lieferte bei `place_` auch dann true, wenn die Marke schon gesetzt war. Behoben (`wasUnmarked`), Test secondAnswerChangesNothing.
- F002 (HIGH): `place_` + `DUE_TOMORROW` verschob die Aufgabe. Behoben (Guard in `respond`), Tests tomorrowOnPlaceDoesNotMove und tomorrowOnDueMoves.
- F003 (LOW, vorher MEDIUM): `place_` auf einer erledigten oder geparkten Aufgabe, z. B. doppeltes `DUE_DONE`. Akzeptiert, Begründung unten.
- F004 (MEDIUM): Test für `due_` + `DUE_DONE` fehlte. Behoben (completeOnDueDoesNotMark).
- F005 (LOW): Aktions-Titel stehen doppelt (`DueNotificationCenter` und `NotificationCategories`). Laut Spec bis Schnitt 2 akzeptiert.
- N1: watchOS- und macOS-Bau. Belegt, siehe AC-8.
- N2: Tomorrow am Ort. Behoben, siehe F002.
- N3: true bei gesetzter Marke. Behoben, siehe F001.

### Runde 2

Testlauf, selbst ausgeführt: `./scripts/sim.sh sim-unit PlaceNotificationsTests > docs/artifacts/feat-240-ortsmitteilung/adversary-run2.txt`. Exit 0, „Test Succeeded“.
- xcresult `Test-LooseEnds-2026.10.14_08-54-33-+0200.xcresult`: totalTestCount 17, passedTests 17, failedTests 0, skippedTests 0, result Passed.
- Die Testdatei enthält genau 17 @Test.
- Messstrecken: 1 von 5 übersprungen (SelfConsistencyReportTests, `selfconsistency-run.json` fehlt). Betrifft diesen Schnitt nicht, ist aber „nicht gemessen“.

Scope, `git status --short`: geändert nur `LooseEndsTests/PlaceNotificationsTests.swift`, neu `Shared/Notifications/PlaceNotifications.swift` und Artefakte unter `docs/artifacts/feat-240-ortsmitteilung/`. Keine Änderung an `Info.plist`, `project.yml`, Entitlements, Messberichten oder `DueNotificationCenter`.

Code reference: Shared/Notifications/PlaceNotifications.swift:10
Code reference: Shared/Notifications/PlaceNotifications.swift:11
Code reference: Shared/Notifications/PlaceNotifications.swift:43
Code reference: Shared/Notifications/PlaceNotifications.swift:50
Code reference: Shared/Notifications/PlaceNotifications.swift:55
Code reference: Shared/Notifications/PlaceNotifications.swift:60
Code reference: Shared/Notifications/PlaceNotifications.swift:68
Code reference: Shared/Notifications/PlaceNotifications.swift:77
Code reference: Shared/Notifications/PlaceNotifications.swift:81
Code reference: Shared/Notifications/PlaceNotifications.swift:82
Code reference: Shared/Notifications/PlaceNotifications.swift:84
Code reference: Shared/Notifications/PlaceNotifications.swift:93
Code reference: Shared/Notifications/PlaceReminders.swift:28
Code reference: Shared/Notifications/DueReminders.swift:87
Code reference: LooseEndsTests/PlaceNotificationsTests.swift:31
Code reference: LooseEndsTests/PlaceNotificationsTests.swift:149
Code reference: LooseEndsTests/PlaceNotificationsTests.swift:169
Code reference: LooseEndsTests/PlaceNotificationsTests.swift:202

Prüfung der Behebungen:
- F001: Zeile 81 `let wasUnmarked = tasks.first { $0.id == id }?.placeRemindedAt == nil`, Zeile 82 `changed = PlaceReminders.markDelivered(...) && wasUnmarked`. `markDelivered` gibt true zurück, sobald die Aufgabe existiert, und überschreibt eine vorhandene Marke nicht. Zweite Antwort liefert false, die erste Marke bleibt (Test Zeile 149 prüft `marked == first`). Unbekannte Aufgabe: false (badTaskIDChangesNothing).
- F002: Zeile 84 `if let actionRaw, let action = ..., !(isPlace && action == .tomorrow)`. Bei `place_` wird `.tomorrow` übersprungen, nur die Marke bleibt. Auf `due_` greift der Guard nicht (tomorrowOnDueMoves).
- F004: Test Zeile 202 prüft status == .done und placeRemindedAt == nil.
- Zusätzlicher Randfall `place_` + `DUE_DONE` bei schon gesetzter Marke: Marke zählt nicht als Änderung, `handle` liefert true, Rückgabe true, der Aufrufer speichert, die Marke wird nicht überschrieben. Kein eigener Test (Testlücken-Hinweis, kein Bruch).
- Randfall `place_` + `DUE_NEXT` mit gesetztem `nextRank`: `handle` ist No-op, liefert aber true, also überflüssiges Speichern. Harmlos, Bestandsverhalten.

Checkliste:
- [x] AC-1: `NotificationCategories.all()` liefert zwei Kategorien: DUE mit done, next, tomorrow und PLACE mit done, next. Test categoriesCarryBothRows prüft Anzahl und Kennungen per `==`, grün.
- [x] AC-2: `isAuthorized` lautet `fullAccuracy && (whenInUse || always)`. Test authorizationDecision deckt alle Kombinationen ab, grün.
- [x] AC-3: `shouldRequestAuthorization` verknüpft vier Bedingungen mit UND. Test askingDecision verletzt jede einzeln, grün.
- [x] AC-4: `respond` (Zeilen 68-88). Tests grün: Tippen, DUE_DONE, DUE_NEXT, due_ ohne Marke, ungültige, fehlende und unbekannte ID mit false, unbekannte Aktion, planDoesNotMark, dazu F001, F002, F004.
- [x] AC-5: `pendingPlaceIdentifiers` filtert nach Präfix. Test prefixFilter prüft `== ["place_" + id]`, grün.
- [x] AC-6: `isSilent` lautet `runningTests || (uiTesting && !arguments.contains(testArgument))`. Test silence deckt alle fünf Fälle ab, grün.
- [x] AC-7: `ReconcileGate`: `end()` setzt `running = false` und gibt per `defer` das Rerun-Flag einmal zurück. Test gateOneRerun grün.
- [x] AC-8: Die Datei wird für Widgets, Watch, Share und App übersetzt (`test-green-sim-output.txt`), macOS-Bau „Build Succeeded“ (`mac-build.txt`), iOS-Bau `sim-build.txt`. Der volle Bestandslauf (`test-green-output.txt`) ist grün; keine Bestandsdatei angefasst.
- [x] AC-9: `simulator-start.png` geöffnet: Listenansicht am 14. Oktober, Kopfzeile mit Einstellungen und Plus, „1 zum Durchsehen“, Abschnitt „Jetzt“, „Passt gerade“, „Alle Ansichten“. Die App startet normal; nichts Neues zu sehen, denn dieser Schnitt schließt nichts an.

Findings mit Status:
- F001: behoben (Code Zeile 81-82, Test Zeile 149).
- F002: behoben (Code Zeile 84, Tests Zeile 169 und 189).
- F003: akzeptiert, LOW. In diesem Schnitt ruft keine Produktionsstelle `respond` auf; `DueReminders.handle` und `TaskActions.complete` verhalten sich auf erledigten Aufgaben für `due_` identisch (Bestand); die Marke auf einer nicht offenen Aufgabe ist folgenlos, weil `PlaceReminders.plan` mit `isOpen` filtert. Reales Risiko erst in Schnitt 2 (liegengebliebene Ortsmitteilung nach Erledigen auf anderem Gerät): der Anschluss prüft vor `respond` auf `isOpen`, als AC in die Spec von Schnitt 2.
- F004: behoben (Test Zeile 202).
- F005: akzeptiert laut Spec bis Schnitt 2.
- Hinweis: kein Test für `place_` + `DUE_DONE` bei schon gesetzter Marke; blockiert nicht.

## Verdict
**VERIFIED**

Begründung: alle neun ACs sind mit Code und grünem Lauf (17 von 17, selbst ausgeführt) belegt, die in Runde 1 gefundenen Brüche sind behoben und per Test abgesichert, der Scope bleibt bei den zwei Dateien der Spec.

## Geprüfte Dateien

- sha256:247f37e8ab358cae34eb8dc01ffdd91808534417ece91aa4324fd11bfd736567  LooseEndsTests/PlaceNotificationsTests.swift
- sha256:19228d41828ba16d451dae2b3c9178098d23d1995089ae6b5042c70cfe351627  Shared/Notifications/DueReminders.swift
- sha256:081ed5b5ea217b48ecbc2f36a5ce4c40ede2b0f0a1334fb7877c88e89940a4c1  Shared/Notifications/PlaceNotifications.swift
- sha256:aa089d7c00844977026e7a9667263d4379f95579d4b0986571bc1e68e3ddd48d  Shared/Notifications/PlaceReminders.swift

## Prüfbasis

- base: 28777a71c41e38564cb2dd6ea01c59670e631de4
- blob:9670b1ec43037a337fc7d10b9f3f95f47de5b182  LooseEndsTests/PlaceNotificationsTests.swift
- blob:dd28d5abf3f08431c5c6b9f2e16fc1e68389f6ee  Shared/Notifications/DueReminders.swift
- blob:087968e9877324415251bf48cc32b14e550b0b64  Shared/Notifications/PlaceNotifications.swift
- blob:412184830284b2b75015f0236d2cc1a49d9830ae  Shared/Notifications/PlaceReminders.swift
