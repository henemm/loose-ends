# Adversary Dialog — feat-1000-s3-neu-aufraeumen
Spec: docs/specs/feat-1000-schnitt-3a-regeln-und-ansicht-neu.md
Datum: 2026-11-27 07:06

## Checkliste
- [x] **AC-1:** `ViewKind` hat keinen Fall `new`; eine gespeicherte Ansicht mit Rohwert `"new"` liest sich als „Als nächstes“ (Tests 1, 2).
- [x] **AC-2:** Im Code gibt es kein `isInNew`, `needsLook`, `canConfirm`, `reviewReason`, `ReviewReason` und `confirmReview` mehr; `grep -rnE "isInNew|needsLook|canConfirm|reviewReason|ReviewReason|confirmReview" Shared LooseEnds LooseEndsWatch LooseEndsWidgets LooseEndsTests` findet nichts (Codeprüfung in der Validierung).
- [x] **AC-3:** Eine frisch erfasste Aufgabe steht ohne Zutun in „Lose Enden“ und zählt in „Jetzt“ wie eine aktive (Test 3).
- [x] **AC-4:** Alle übrigen Unit- und UI-Tests bestehen (Test 4).
- [x] **AC-5:** Simulatordurchlauf auf dem iPhone: Satz über die Schreibzeile erfasst, die Aufgabe steht sofort in der Liste, der Index zeigt keinen Eintrag „Neu“; Beleg über `./scripts/sim.sh test-proof InboxDrawerSmokeTests`, Screenshot geöffnet und beschrieben.

## Dialog

### Runde 1
**Adversary:** Beweis je AC verlangt. Eigene Prüfung: grep nach `isInNew|needsLook|canConfirm|reviewReason|ReviewReason|confirmReview` in Shared, LooseEnds, LooseEndsWatch, LooseEndsWidgets, LooseEndsTests liefert keinen Treffer (rc=1). Keine `.new`-/`"new"`-Verwendung mehr ausser in den Tests ViewKindWithoutNewTests und StartViewsTests, die das Fehlen pruefen. ViewKind wird in Watch, Widgets, Share, WatchWidgets nirgends benutzt, es gibt keine weiteren erschoepfenden switches ausser denen im Diff (TaskListView-Leersatz, ViewKind.titleKey/symbol, RowKeyAction). Unit-Lauf test-green-output.txt: 0 Zeichen ✘, 105 XCTest ohne Fehler, Suite "No view New (#1000 S3a)" bestanden, 3 von 6 Messstrecken uebersprungen (Korpusdateien fehlen, vor der Aenderung ebenso, kein Bezug). Gefundene Randfaelle: (a) Der geloeschte ReviewTrayTests pruefte auch Verhalten, das gelten muss: Markieren als gesehen. Das bleibt in RevisionServiceTests.markSeen (Marker weg, zweiter Lauf 0) und wurde nur um die New-Zeilen gekuerzt; `confirmedBeforeEnrichmentStillRuns` in EnrichmentTests ruft jetzt markSeen und setzt active von Hand, die Koordinator-Regel (aktive Aufgabe ohne processedAt bekommt ihren Lauf) bleibt geprueft. (b) Kommentare, die nun Falsches behaupten: ViewRules.swift:334 nennt "New" als Ansicht, die top level bleibt; TaskItem.swift:183 "keeps no task in New"; SidebarView.swift:5 "inbox bar while anything waits in New" (aus S1, nicht aus S3a); GuessedProjects.swift:13/17/29 Geschichte. (c) Katalogschluessel "Nothing to look over." und "New" bleiben im Katalog; die Spec ordnet das Schnitt 3b zu.
**Implementierer:** Siehe diff: Entfernungen sind rein subtraktiv; Rohwert "new" liest SavedView.kind zu .next (Test 2 bestanden).

### Runde 2
**Adversary:** Gegenprobe auf Schwaechen der Belege. Test 3 setzt captured.nextRank selbst und prueft Set(open) und nowCount gleich vor/nach Statuswechsel: geprueft in ViewKindWithoutNewTests.swift, die Zahl 2 ist festgelegt, also nicht tautologisch. Die Aussage "ohne Zutun in Lose Enden" haengt an ViewRules.tasks(.open), das keinen Statusfilter auf unprocessed hat (Diff entfernt nur den case .new). Simulator: adversary-screenshot.png zeigt die Startseite, Index Als naechstes, Faellig, Etiketten, Projekte, Lose Enden, Erledigt ohne "Neu", Jetzt 0 (leerer Zustand, daher kein Erfassungsnachweis). Den Erfassungsnachweis liefert simulator-run/A6A2168E-...png: Liste "All open" mit "Reifen wechseln" und "Mama anrufen" mit Tag Phone, beide ohne Sichtungsmarke und ohne Zwischenschritt; InboxDrawerSmokeTests 3 von 3 bestanden, 0 uebersprungen, head 532891a (RED-Commit; der Lauf deckt die vorgemerkten Aenderungen, Stand 07:07 vor Gruenlauf 07:02 bis 07:08 – gleicher Arbeitsbaum). Offen bleibt AC-4 UI-Tests im Ganzen: laut Auftrag erst in der CI; lokal nur Unit-Lauf. Keine Regression durch geaenderte Signaturen: keine Aufrufer der entfernten Symbole mehr (grep).
**Implementierer:** Kommentare sind laut Spec ausdruecklich kein Drive-by (ViewRules-Kommentar zu dailyViews bleibt als Geschichte); Aufraeumen folgt in 3b.

### Findings

Finding:
  ID: F001
  Severity: LOW
  Category: anti_pattern
  Code reference: Shared/Models/ViewRules.swift:334
  Description: Kommentar nennt "New" als Ansicht, die top level bleibt; die Ansicht gibt es nicht mehr.
  Spec requirement: AC-2 — keine Sichtungsregel/Ansicht Neu mehr im Code
  Conflict: Falsche Dokumentation in der geaenderten Datei, kein Verhaltensfehler.
  Remediation: "(New, Old, Waiting)" zu "(Old, Waiting)" aendern, in 3b mitnehmen.

Finding:
  ID: F002
  Severity: LOW
  Category: anti_pattern
  Code reference: Shared/Models/TaskItem.swift:183
  Description: Kommentar "keeps no task in New" und SidebarView.swift:5 "inbox bar while anything waits in New" beschreiben Entfallenes.
  Spec requirement: AC-2
  Conflict: Veraltete Kommentare; SidebarView-Text stammt schon aus Schnitt 1.
  Remediation: In Schnitt 3b beim Aufraeumen anpassen.

### Confirmations

Confirmation:
  AC: AC-1
  Code reference: Shared/Models/Enums.swift:88
  Evidence: ViewKind enthaelt elf Faelle ohne new, titleKey/symbol ohne new; Tests 1 und 2 bestanden (ViewKindWithoutNewTests).
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: Shared/Models/ViewRules.swift:8
  Evidence: ReviewReason, needsLook, isInNew, canConfirm, reviewReason und case .new entfernt; grep leer. TaskActions.confirmReview entfernt (Shared/Services/TaskActions.swift:89 ist nun park), RowKeyAction.spaceCompletes ohne .new (Shared/Models/RowKeyAction.swift:43), Leersatz ohne .new (LooseEnds/Views/TaskListView.swift:322).
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: Shared/Models/ViewRules.swift:336
  Evidence: tasks(for:) hat keinen Status-/Sichtungsfilter fuer .open; Test 3 bestanden, nowCount gleich 2 vor und nach Statuswechsel.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: LooseEnds/Views/TaskListView.swift:322
  Evidence: Der Unit-Lauf ist gruen (0 ✘, "Test Succeeded"); der switch ist erschoepfend und kompiliert. UI-Tests im Ganzen laufen erst in der CI nach dem Push, lokal nur InboxDrawerSmokeTests 3/3.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: Shared/Models/Enums.swift:88
  Evidence: Index im Screenshot ohne "Neu"; Erfassungsdurchlauf zeigt beide Aufgaben sofort in "All open"; test-proof 3/3 bestanden.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: Shared/Services/TaskActions.swift:89
  Evidence: confirmReview entfernt, keine Aufrufer; park folgt direkt auf die Vorgaengerfunktion.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: Shared/Models/RowKeyAction.swift:43
  Evidence: spaceCompletes kennt nur noch .done? und .parked?.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: LooseEnds/Views/TaskListView.swift:322
  Evidence: emptySentence ohne .new, switch erschoepfend.
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

═══════════════════════════════════════
VERDICT: VERIFIED
═══════════════════════════════════════
Die Implementierung hielt der Pruefung stand.
Tests: Unit-Lauf 0 fehlgeschlagen (0 ✘), InboxDrawerSmokeTests 3 bestanden, 0 uebersprungen; 3 von 6 Messstrecken uebersprungen (fehlende Korpusdateien, ohne Bezug); UI-Tests im Ganzen erst in der CI
Edge cases: alle geprueft, keine gebrochen (nur LOW F001, F002: veraltete Kommentare)
Regressions: keine gefunden
Checklist: 5/5 points proven

## Geprüfte Dateien

- sha256:ba069fd75ae4b53478b1a794451830e5aa4a91781afd951b3de874baf161127d  LooseEnds/Views/TaskListView.swift
- sha256:9bacacc369384bc465c8c816821e52d5f152649ec2c39cf7db1a88528532d79c  Shared/Models/Enums.swift
- sha256:15f9bdbc4092b181f1384404e5cf7bf2360c73c4429ec3f6068e43447724c277  Shared/Models/RowKeyAction.swift
- sha256:b09e4382ba3500810d1fd9cd43d48accf23507a2bf094ef16c3ebc63cb72a68c  Shared/Models/TaskItem.swift
- sha256:d5a73786c62e27fbfa707fe646a278fceb7d9a3361126cf27b8e1a4cd8755b50  Shared/Models/ViewRules.swift
- sha256:08fa397c69d6ea5d7ea3ddb6a95018d6a8ff54604694fa8261e0f4345d505744  Shared/Services/TaskActions.swift

## Prüfbasis

- base: a8cc19f9a3fbe569c57544d53f9ff1eddf1881c1
- blob:3cb6d67c9454079127f3d50f393d1a4ff2311393  LooseEnds/Views/TaskListView.swift
- blob:573db5ce3fb9b785503c34933b2250c6ca9ddf05  Shared/Models/Enums.swift
- blob:640ac78ef5cce670150b673eea5353adb5a3c3ab  Shared/Models/RowKeyAction.swift
- blob:57c7c90b50696dbfb060ead960584f80d4394375  Shared/Models/TaskItem.swift
- blob:e00c55ebca5b7592d928e9a2ef3a242afab75eca  Shared/Models/ViewRules.swift
- blob:8c9b90b56130453253a32c4bcff5dcba1c1bd56d  Shared/Services/TaskActions.swift

## Geprüfte Dateien

- sha256:ba069fd75ae4b53478b1a794451830e5aa4a91781afd951b3de874baf161127d  LooseEnds/Views/TaskListView.swift
- sha256:9bacacc369384bc465c8c816821e52d5f152649ec2c39cf7db1a88528532d79c  Shared/Models/Enums.swift
- sha256:15f9bdbc4092b181f1384404e5cf7bf2360c73c4429ec3f6068e43447724c277  Shared/Models/RowKeyAction.swift
- sha256:b09e4382ba3500810d1fd9cd43d48accf23507a2bf094ef16c3ebc63cb72a68c  Shared/Models/TaskItem.swift
- sha256:d5a73786c62e27fbfa707fe646a278fceb7d9a3361126cf27b8e1a4cd8755b50  Shared/Models/ViewRules.swift
- sha256:08fa397c69d6ea5d7ea3ddb6a95018d6a8ff54604694fa8261e0f4345d505744  Shared/Services/TaskActions.swift

## Prüfbasis

- base: a8cc19f9a3fbe569c57544d53f9ff1eddf1881c1
- blob:3cb6d67c9454079127f3d50f393d1a4ff2311393  LooseEnds/Views/TaskListView.swift
- blob:573db5ce3fb9b785503c34933b2250c6ca9ddf05  Shared/Models/Enums.swift
- blob:640ac78ef5cce670150b673eea5353adb5a3c3ab  Shared/Models/RowKeyAction.swift
- blob:57c7c90b50696dbfb060ead960584f80d4394375  Shared/Models/TaskItem.swift
- blob:e00c55ebca5b7592d928e9a2ef3a242afab75eca  Shared/Models/ViewRules.swift
- blob:8c9b90b56130453253a32c4bcff5dcba1c1bd56d  Shared/Services/TaskActions.swift
