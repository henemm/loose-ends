# Adversary Dialog — feat-240-schnitt-2-zustellung
Spec: docs/specs/feat-240-schnitt-2-zustellung.md
Datum: 2026-10-15

## Checkliste
- [x] AC-1: DueNotificationCenter.swift:62 ruft setNotificationCategories(NotificationCategories.all()) genau einmal; PlaceNotificationCenter.swift enthaelt keinen Aufruf; Unit-Test oneCategorySet (DueNotificationCenterTests:160) gruen; UI-Gegenprobe testButtonsKeepTomorrow 3/3 (proof-due).
- [x] AC-2: Code: nur DueNotificationCenter.swift:61 setzt delegate, didReceive:171 und willPresent:186 sind Callback-Fassungen. Test didReceiveCallsCompletionOnce (DueNotificationCenterTests.swift:~298) ruft die echte Delegate-Methode mit gebauter UNNotificationResponse; Completion genau 1x, Marke gesetzt und gespeichert vor der Completion; UI-Test AC-12 gruen.
- [x] AC-3: respond() DueNotificationCenter.swift:201 routet nur am Praefix place_, unabhaengig vom Ortszentrum (PlaceNotificationCenter.isSilent betrifft nur dessen Scheduler); Tests tapOnPlaceMarksAndOpens, dueKeepsItsPath gruen.
- [x] AC-4: markPlace:224 + taskToOpen; Tests tapOnPlaceMarksAndOpens, buttonsOnPlace (Done, Next, Tomorrow unveraendert, Marke gesetzt, gespeichert) gruen.
- [x] AC-5: willPresent:186-194; Test willPresentCompletesBeforeTheMark ruft die echte Methode: Completion synchron 1x mit [.banner,.list,.sound], Marke bei Completion false, danach gesetzt und gespeichert; willPresentDueLeavesTheMark: due_ bleibt ohne Marke.
- [x] AC-6: PlaceNotificationCenter.request(for:) :154-168 (Titel, lokalisierter Body, Kategorie PLACE, taskID, Radius TaskPlace.radius, repeats false, notifyOnEntry/Exit nach Event); PlaceNotificationCenterTests gruen; Systemlog zeigt Region 150 m, repeats NO, Kategorie PLACE.
- [x] AC-7: reconcileOnce :104 liest nur pendingPlaceIdentifiers (place_); rescheduleDue:121 filtert due_; Tests in PlaceNotificationCenterTests / DueNotificationCenterTests gruen.
- [x] AC-8: Diff gegen Handover (PlaceDelivery.diff, :114); Tests in PlaceNotificationCenterTests gruen (Suite passed).
- [x] AC-9: catch in :125 faengt add-Fehler, saveHandover (:124) wird dann uebersprungen; reschedule():116 fuehrt rescheduleDue vor dem Ortsabgleich aus; Test rescheduleRunsThePlaceReconcile gruen. Randfall F002.
- [x] AC-10: PlaceDelivery.diff(authorized:) im Aufruf :114-117, remove wird immer ausgefuehrt (:118), Merkliste nur bei authorized (:124); Tests gruen.
- [x] AC-11: askIfNeeded :131-138 setzt askedKey erst nach der Anfrage; shouldRequestAuthorization prueft hasWatched/isActive/alreadyAsked; Reconcile bei Vordergrund ueber ContentView.swift:87 (rescheduleSoon bei scenePhase .active); Tests gruen.
- [x] AC-12: PlaceNotificationTapTests testBannerWhileAppIsOpenKeepsAppAlive + testTapBannerFromHomeOpensApp gruen (proof-place/simulator-run.txt: 3 gesamt, 3 bestanden, 0 uebersprungen); Screenshot place-in-front/place-buttons geoeffnet: Banner "UI test place / You're at Post office." ueber der Liste, App im Vordergrund.
- [x] AC-13: Screenshot place-buttons zeigt Kontextmenue mit "Complete" und "Next up", kein "Tomorrow"; Screenshot place-completed: JETZT-Bereich leer, "Completed 1", Banner bleibt im Verschwinden.
- [x] AC-14: proof-due 3/3 gruen inkl. testButtonsKeepTomorrow (Tomorrow vorhanden); test-place-smoke.txt: PlaceSmokeTests 1 Test, 0 Fehler.
- [x] AC-15: Unit-Test (PlaceNotificationCenterTests ~:258, Locale de) gruen im eigenen Lauf; project.yml + Info.plist + beide InfoPlist.strings tragen NSLocationWhenInUseUsageDescription (git diff).
- [x] AC-16: mac-build.txt "Build Succeeded", macOS-Build erfolgreich; PlaceNotificationCenter.swift ganz in #if os(iOS) (Z.1/170), LooseEndsApp.swift mit #if os(iOS) und places=nil sonst.
- [x] AC-17: eigener Lauf sim-unit: "Unit-Tests bestanden", keine fehlgeschlagene Pruefung (nur 1 von 5 Messstrecken uebersprungen, vorbestehend: selfconsistency-run.json fehlt); Suiten DueNotificationCenter, PlaceDelivery, PlaceNotificationCenter, PlaceNotifications, PlaceReminders passed.
- [x] AC-18: sim-run-1.png/sim-run-2.png geoeffnet: Startbildschirm, Aufgabe "UI test place" mit Ortszeile "Post office" (Pfeilsymbol), Ansichten sichtbar, kein Absturz; Systemlog: Anfrage place_...0240 hinzugefuegt, startMonitoringForRegion. Echter Ortsausloeser im Simulator nicht belegbar (laut Spec nach AC-19-21 verlagert).
- [x] AC-19: Henning 2026-10-15, TestFlight Build 61 (main 55d3aa3): Ankommen bei geschlossener App zeigte „Du bist bei <Ort>.“ mit Titel der Aufgabe („alles wie erwartet“).
- [x] AC-20: Henning hatte Verlassen und Einmal-Prinzip in der Vorabversion (LE Prüfbau, #226 Schnitt 2b, 2026-10-07/08) positiv getestet; die Ortslogik (PlaceReminders.plan, PlaceDelivery.diff, Marke placeRemindedAt) ist unverändert übernommen, neu ist nur der Anschluss, den AC-19/AC-21 auf demselben Gerät belegen. Henning wählte am 2026-10-15 ausdrücklich den kurzen Check ohne erneuten Verlassen-Lauf.
- [x] AC-21: Henning 2026-10-15, Build 61: „Erledigt“ in der Ortsmitteilung erledigte die Aufgabe in der Liste („alles wie erwartet“).

## Dialog

### Runde 1
**Adversary:** Eigener Lauf `CLAUDE_SESSION_ID=goose240adv ./scripts/sim.sh sim-unit` gruen (Ausgabe: docs/artifacts/feat-240-schnitt-2-zustellung/adversary-unit-run.txt; Kopie nach /tmp wurde vom secret_egress_guard blockiert, ebenso die Sperrdatei /tmp/loose-ends-testlauf.lock; es lag keine Sperre vor). Messberichte wurden zurueckgesetzt. Code gelesen: PlaceNotificationCenter.swift komplett, DueNotificationCenter-Diff, LooseEndsApp-Diff. Geprueft: kein try? das schluckt, kein print, Logger genutzt; keine Funktion > 50 Zeilen; Plattformcode in #if os(iOS); genau ein setNotificationCategories-Aufruf im Produktcode; willPresent captured den nicht-Sendable completionHandler nicht im Task (Swift 6 ok); didReceive-Completion kommt nach dem MainActor-Task (#295-Muster). Angriffe: place_ bei stillem Ortszentrum (respond haengt nicht am Ortszentrum, ok); DUE_TOMORROW auf place_ (respond liefert Marke, keine Aenderung, ok); Antwort ohne taskID (respond/markPlace tolerant, Tests der Schnitt-1-Bausteine); zwei Geraete (Marke placeRemindedAt reist ueber CloudKit, Merkliste je Geraet).
**Implementierer:** (nicht beteiligt; Kontextisolation)
Findings siehe unten. Early-Agreement-Skepsis: AC-2 und AC-5 verlangen im Nachweis einen Unit-Test ueber die echten Delegate-Methoden; grep nach willPresent/didReceive/completion in LooseEndsTests ergibt keinen Treffer.

### Runde 2
**Adversary:** Zweiter Durchgang gegen Randfaelle und Belege. (a) add-Fehler: ein dauerhaft fehlschlagender Eintrag blockiert in :120-122 alle folgenden Anfragen und das Speichern der Merkliste in jedem Lauf (F002). (b) Hintergrund/Vordergrund: askedKey erst nach Anfrage gesetzt (:136-137), Vordergrundwechsel loest reschedule aus (ContentView.swift:87). (c) Ort entfernt / Aufgabe erledigt: diff() nimmt place_-Anfragen zurueck (Schnitt-1-Tests), erledigte wiederholte Aufgabe wird ueber PlaceReminders.plan neu eingeplant (Test completionArmsARepeatAgain gruen). (d) zweiter setNotificationCategories-Aufruf: keiner im Produktcode (grep). (e) Belege: Screenshots einzeln geoeffnet und beschrieben (siehe AC-12/13/18). Der Systemlog zeigt in diesem Simulator sogar erfolgreiches add ohne 2003, der Fehlerpfad ist nur per Unit-Test belegt. (f) Beleg-Kopf der Simulator-Belege nennt head a38ba09 (RED-Commit) bei ungestagten Aenderungen; die Dateihashes im Beleg gehoeren zum Arbeitsstand, kein Widerspruch. Kein weiterer Bruch gefunden.
**Implementierer:** (nicht beteiligt)

### Runde 3
**Adversary:** F001 nachgeprueft. Die neuen Tests (DueNotificationCenterTests.swift:~255-345) rufen `fixture.center.userNotificationCenter(.current(), didReceive:/willPresent:)` direkt auf, mit UNNotification/UNNotificationResponse aus NSKeyedUnarchiver-Coder + KVC; die Kennung/taskID der Nachbauten wird zugesichert, die Tests sind also nicht trivial. Gedanklicher Mutationstest: (a) async-Fassung von didReceive/willPresent: der Aufruf mit Trailing-Closure kompiliert nicht, Test faellt. (b) willPresent ruft Completion spaet (nach Marken-Task): Zusicherung `count == 1` direkt nach dem Aufruf bzw. `markSetAtCompletion == [false]` schlaegt fehl. (c) didReceive ruft Completion vor der Arbeit: Marke waere bei Completion nil, Zusicherung nach Continuation faellt; doppelte Completion wuerde die Continuation doppelt fortsetzen (Absturz). (d) willPresent setzt nie die Marke: waitForMark laeuft ab, Zusicherung faellt. (e) due_ setzt Marke: willPresentDueLeavesTheMark faellt. Schwaeche, akzeptiert: Oeffnen der Aufgabe wird in didReceive-Test nicht zugesichert (ContentView konsumiert OpenTaskRequest im Testhost); belegt durch tapOnPlaceMarksAndOpens (synchron) und UI-Test AC-12. Belege: test-green-output.txt 623 Tests, die drei neuen Tests dort gruen (Z.215-217); due-suite-3x.txt 3x Suite DueNotificationCenter passed. F002 ist als #418 ausgelagert.
**Implementierer:** (nicht beteiligt)
F001: erledigt. F002: ausgelagert nach #418, LOW, entspricht dem Wortlaut von AC-9.

### Runde 4
**Adversary:** Stand nach Zusammenfuehrung mit origin/main a371718 (#414). DueNotificationCenter.swift gelesen und gegen origin/main gediffed. (1) Routing: didReceive (254-275) berechnet isPlace aus dem Praefix `place_`; Carry-Pfad nur bei `!isPlace`. Kennungen sind disjunkt (`carry_`, `due_`, `place_`), Aktionswerte disjunkt (CARRY_*, DUE_*), eine place_-Mitteilung kann nie in applyCarry laufen; eine Carry-/Abendmitteilung geht nie in respond->markPlace (respond faellt ohne place_-Praefix in apply, und Carry-Aktionen werden vorher abgefangen). Carry-Antworten haben keine taskID, present() prueft das Praefix und ist fuer carry_/due_ ein No-op. (2) completionHandler: didReceive ruft ihn genau einmal nach der if/else-Weiche (273), beide Zweige ohne Early-Return; willPresent ruft ihn genau einmal vor dem Marken-Task (285). (3) Carry-Verhalten gegenueber origin/main: Diff zeigt nur die Weiche `!isPlace`, rescheduleDue (Carry-Plan, stale-Filter auf due_ und carry_, Badge) unveraendert, Kategorien carryCategory/eveningCategory unveraendert, nur jetzt in einem Aufruf. reschedule() = rescheduleDue() + places?.reconcile(). (4) grep setNotificationCategories in LooseEnds/Shared: ein Produktionsaufruf (DueNotificationCenter.swift:62), Rest Protokoll und System-Wrapper. (5) Funktionslaengen alle unter 50 Zeilen (laengste: didReceive 22, applyCarry 18); kein `try?` in LooseEnds/Notifications. (6) Belege: test-green-output.txt (08:46, nach Merge) 645 Zeilen gruen, 0 fehlgeschlagen, enthaelt den umgeschriebenen Test "Activating sets the categories once: DUE with Tomorrow, PLACE without, and both carry categories" (Z.243) und die #414-Tests (Z.236, 240). proof-place und proof-due: head f0448063fd5c, Basis a371718, je 3/3 Passed; Screenshots geoeffnet: Ort-Banner "UI test place / You're at Post office." mit Knoepfen Complete und Next up (ohne Tomorrow) und die Aufgabendetails nach Tipp (Place Post office, Arrive/Leave); Faellig-Banner "UI test reminder / Due today" mit Complete, Next up, Tomorrow. mac-build.txt: Build Succeeded. (7) Eigener Unit-Lauf: nicht ausgefuehrt, weil zwei fremde `xcodebuild test`-Laeufe (Sitzungen wf-bestand-25, 409-adv) aktiv waren; ersatzweise der Lauf test-green-output.txt, der nach dem Merge entstand. adversary-unit-run.txt stammt von vor dem Merge (07:49) und ist nicht Beleg fuer diesen Stand. Mutationsgedanke: Weiche `!isPlace` entfernen, dann liefe place_-Antwort mit Aktion DUE_* nicht in Carry (Werte disjunkt), faende aber bei einem Tipp (Default-Aktion) auf eine Abendmitteilung nie statt, da Kategorie CARRY_EVENING nur auf carry_ liegt; der Schutz ist doppelt, kein Befund.
**Implementierer:** (nicht beteiligt)
Keine neuen Findings. F001 und F002 aus Runde 3 unveraendert.

### Runde 5
**Adversary:** Gerätebefund des PO nach Merge (PR #431, 55d3aa3) und TestFlight Build 61 (Lauf 38726974949, „Was testen“ mit drei Prüfschritten). Henning bestätigte den kurzen Check: Ankommen bei geschlossener App meldet sich, „Erledigt“ wirkt. Code der drei geprüften Dateien seit Runde 4 unverändert (Merge von main b63e6d2/e28dcb1 berührt sie nicht). Validierungslauf nach Abgleich mit main: 666 Unit grün, 0 rot (validate-unit-run.txt); CI zu #431 grün (Build, Unit macOS, UI Smoke). AC-20 stützt sich auf den früheren Gerätetest derselben Ortslogik, ausdrücklich vom PO so gewählt. Kein neuer Befund.
**Implementierer:** (nicht beteiligt)

### Findings

Finding:
  ID: F001
  Severity: MEDIUM
  Category: spec_violation
  Code reference: LooseEnds/Notifications/DueNotificationCenter.swift:186
  Description: willPresent (186-194) und didReceive (171) sind korrekt als Callback-Methoden gebaut, die Completion kommt in willPresent vor dem Marken-Task. Kein Test ruft diese Delegate-Methoden mit Completion-Handler auf; die Tests rufen nur respond() und present() direkt.
  Spec requirement: AC-2 und AC-5 — Nachweis per Unit-Test, der die Delegate-Methoden mit Completion-Handlern aufruft und die Completion zaehlt, bzw. Completion vor gespeicherter Marke.
  Conflict: Der geforderte Nachweis fehlt; die Reihenfolge Completion vor Marke ist nur durch Code-Review belegt. (UNNotification/UNNotificationResponse sind schwer zu konstruieren; UI-Test AC-12 deckt den Absturz #295 ab.)
  Remediation: Test ergaenzen (Notification per NSKeyedArchiver/KVC bauen) oder Spec-Nachweis fuer AC-2/AC-5 per Entscheidung auf Review + UI-Test herabsetzen.

Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: LooseEnds/Notifications/PlaceNotificationCenter.swift:120
  Description: Die add-Schleife bricht beim ersten Fehler ab (try await in der Schleife, catch auerhalb) und speichert die Merkliste nicht. Schlaegt ein bestimmter Eintrag dauerhaft fehl, werden alle spaeteren nie hinzugefuegt, und jeder Lauf wiederholt dasselbe.
  Spec requirement: AC-9 — Fehler bei add bricht nichts; naechster Lauf versucht es erneut.
  Conflict: Spec ist wortgetreu erfuellt (Merkliste ungeschrieben, Wiederholung), aber ein einzelner dauerhafter Fehler blockiert die uebrigen Orte (Head-of-Line).
  Remediation: Fehler je Anfrage fangen und nur erfolgreiche Eintraege in die Merkliste uebernehmen; kein Muss fuer diesen Schnitt.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

### Confirmations

Confirmation:
  AC: AC-6
  Code reference: LooseEnds/Notifications/PlaceNotificationCenter.swift:154
  Evidence: request(for:) baut Kategorie PLACE, taskID, lokalisierten Body, 150-m-Region, repeats false, notifyOnEntry/Exit nach Event; Systemlog bestaetigt.
  Status: CONFIRMED

Confirmation:
  AC: AC-16
  Code reference: LooseEnds/App/LooseEndsApp.swift:33
  Evidence: Ortszentrum nur unter #if os(iOS), sonst nil; macOS-Build erfolgreich (mac-build.txt).
  Status: CONFIRMED

Confirmation:
  AC: AC-1
  Code reference: LooseEnds/Notifications/DueNotificationCenter.swift:62
  Evidence: ein einziger setNotificationCategories-Aufruf mit beiden Kategorien.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: LooseEnds/Notifications/DueNotificationCenter.swift:273
  Evidence: didReceive ruft completionHandler genau einmal nach der place-/Carry-/Faellig-Weiche; willPresent (285) genau einmal vor dem Marken-Task; Tests gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-12
  Code reference: LooseEnds/App/LooseEndsApp.swift:39
  Evidence: DueNotificationCenter wird mit places-Reconciler erzeugt und aktiviert; UI-Tests proof-place/proof-due 3/3 auf Stand f044806.
  Status: CONFIRMED

## Verdict
AC-1 bis AC-21 bewiesen; AC-19/AC-21 am Gerät (Build 61), AC-20 über den früheren Gerätetest der unveränderten Ortslogik (PO-Entscheidung 2026-10-15).
Tests: 645 Unit gruen, 0 fehlgeschlagen; UI proof-place 3/3, proof-due 3/3.

VERDICT: VERIFIED

## Geprüfte Dateien

- sha256:3101dce7d575fcaa1dd28cc17532811a8b5c5e338e8af581b55b7a03b7d9d06e  LooseEnds/App/LooseEndsApp.swift
- sha256:2ff8b7d356311352498a919c8782586615e467cd2569e5c046a8c52b6f6eb841  LooseEnds/Notifications/DueNotificationCenter.swift
- sha256:e686a05fd75399858a17ad9956083597bf053f41d32e77c9cdfe6fb5133c268e  LooseEnds/Notifications/PlaceNotificationCenter.swift

## Prüfbasis

- base: a371718bc3a71a4dafeee2ebb7a9a47a175aff1d
- blob:b62cfefe3e700b0acda201641183c1c9ecab8160  LooseEnds/App/LooseEndsApp.swift
- blob:0f15ca6ab896a7b5b59ea8fab542bbbaec313ffa  LooseEnds/Notifications/DueNotificationCenter.swift
- blob:c2c149484efb99049a5655c092e811f12d91a165  LooseEnds/Notifications/PlaceNotificationCenter.swift
