# Mini-Spec: fix-398-jetzt-block

**ADR-Nr.:** keine — Feinschliff am vorhandenen Block „Jetzt“ (#368), kein Architekturschritt.

Ticket #398, Teil von Epic #467. Stand geprüft 2026-10-22 gegen `main` b8e656a: `NowBlock`
(`LooseEnds/Views/StartZones.swift`) trägt iPhone/iPad (`SidebarView`, `nowRow_`) und Mac (`StartPage`, `startNowRow_`);
eine Änderung dort wirkt auf beide. Rein regelbasiert, kein Modell: „Without the model this fails because …“ entfällt,
weil kein Feld abgeleitet wird.

## Was ändert sich

- **AC-1 Zuklappen:** Sinkt die Zahl der Jetzt-Aufgaben auf ≤ 5, ist der Block wieder zugeklappt. Steigt sie danach über 5,
  steht „N weitere“, nicht „Weniger anzeigen“. Der `onChange(of: tasks.count)` hängt an `ZoneCaption("Now")`, die immer
  steht (der Knopf fehlt bei ≤ 5, der Hinweis bei Zeilen).
- **AC-2 VoiceOver:** Der Knopf `nowMore` bekommt einen Hinweis: zugeklappt „Shows the remaining tasks“ / „Zeigt die übrigen
  Aufgaben“, aufgeklappt „Shows only the first five tasks“ / „Zeigt nur die ersten fünf Aufgaben“. Sichtbarer Text und
  Label bleiben („2 more“, `testNowMoreExpandsInPlace`).

## Was darf sich nicht ändern

- Aussehen des Blocks, Grenze 5, `SidebarView` und `StartPage`.
- Vorhandene Tests: `testNowMoreExpandsInPlace`, `testEmptyNowShowsTheHint`, `testRemovingNextUpFromDueRowKeepsItInNow`.

## Tests (`LooseEndsUITests/StartScreenInteractionTests.swift`, iPhone-Simulator der CI)

- `testNowRowOpensItsTask` (3a): Jetzt-Zeile antippen öffnet das Detail (`detailTitleField`, `detailRawTextMarker` mit dem
  Rohtext), nach Zurück steht dieselbe Zeile da. Der Mac ist schon belegt (`MacDetailClickTests`, `startNowRow_`).
- `testNewWithoutNowKeepsTheHint` (3b): eine Aufgabe ohne Datum: `inboxBar` da, keine `nowRow_`, kein `nowMore`, Hinweis da.
- `testNowFoldsAgainOnceFiveAreLeft` (3c, zu AC-1): sieben „Heute …“, aufklappen, zwei erledigen bis 5, zwei erfassen:
  „2 more“ und fünf Zeilen. Vor dem Fix rot, danach grün (zwei Commits im PR, CI-Lauf je Commit).

## Abnahme

Stufe 1 und 2 über die CI (`ui-smoke`, iPhone 17, iOS 27.0): die drei Tests spielen den geänderten Ablauf im Simulator
durch. Kein Pfad der Geräteliste berührt.
