# Context: fix-144-recognition-pool-empty

Issue: [#144](https://github.com/henemm/loose-ends/issues/144) — „Ohne Apple Intelligence greift die
Wiedererkennung nie — Vergleichsmenge bleibt für immer leer (#136)"
Vorgänger: #136 (Wiedererkennung gebaut), #95 (Regelschritt unabhängig vom Modell), #145 (Prozess-Folge)

## Request Summary

Auf einem Gerät ohne Apple Intelligence übernimmt eine wortgleiche Zweiterfassung nie Dauer und
Kontexte der ersten Aufgabe: die Vergleichsmenge der Regel hängt am Modell-Vermerk `processedAt`,
der ohne Modelllauf nie gesetzt wird. Ein Regelpfad darf nicht davon abhängen, dass das Modell
verfügbar war („Rules before the model").

## Root Cause — im Code bestätigt

| Stelle | Befund |
|--------|--------|
| `Shared/Enrichment/EnrichmentWriter.swift:94` | `task.processedAt = now` — die **einzige** Schreibstelle im Produktpfad |
| `Shared/Enrichment/EnrichmentCoordinator.swift:50-65` | `EnrichmentWriter.apply` steht innerhalb von `if modelUnavailable == nil` |
| `Shared/Enrichment/EnrichmentCoordinator.swift:160` | Pool-Fetch: `#Predicate { $0.processedAt != nil }` |
| `Shared/Enrichment/EnrichmentCoordinator.swift:49` | `applyRules(to:…)` läuft korrekt auch ohne Modell (#95 AC-7) — nur sein Eingangsmaterial hängt am Modell |

Damit ist die Kette geschlossen: kein Modell → kein `processedAt` → leerer Pool → `RecognitionRule.match`
bekommt `pool == []`, filtert auf `hits.isEmpty` und liefert `nil` (`RecognitionRule.swift:52-53`).

**Verschärfend:** Ohne Modell können Dauer und Kontexte überhaupt nur aus zwei Quellen kommen — der
Wiedererkennung selbst oder einer Nutzereingabe. Das Saatkorn der Vergleichsmenge ist auf einem Gerät
ohne Apple Intelligence also immer ein **nutzergesetzter** Wert. `RecognitionRule.winner`
(`RecognitionRule.swift:86-88`) bevorzugt solche Werte ausdrücklich — die Regel ist dafür gebaut, sie
bekommt sie nur nie zu sehen.

## Related Files

| File | Relevance |
|------|-----------|
| `Shared/Enrichment/EnrichmentCoordinator.swift` | Pool-Fetch (Z. 157-163), Regelschritt (Z. 86-95, 181-219), Pending-Fetch (Z. 36-40) — hier liegt die Änderung |
| `Shared/Enrichment/EnrichmentWriter.swift` | Setzt `processedAt` (Z. 94); `userHasTouched` (Z. 103) bleibt der Nutzermarker |
| `Shared/Enrichment/RecognitionRule.swift` | Reine Regel, kein SwiftData — bleibt unberührt, bekommt nur endlich Material |
| `Shared/Models/TaskItem.swift:19` | `processedAt: Date?`; hier entstünde bei Alternative 2 ein zweites Feld |
| `Shared/Persistence/ModelContainerFactory.swift` | Schema ohne `VersionedSchema`/`SchemaMigrationPlan` — additive optionale Felder laufen als Lightweight Migration, CloudKit-tauglich, weil optional |
| `LooseEnds/App/ContentView.swift:41,68` | Die zwei Auslöser: Nachzügler-Lauf beim Start und Lauf bei jeder Änderung von `tasks.count` (also direkt nach jeder Erfassung) |
| `LooseEndsTests/EnrichmentTests.swift` | 24 Tests aus #136 + die Modell-frei-Tests aus #95 — mehrere zementieren die heutige `processedAt`-Bedeutung, siehe „Risks" |
| `docs/project/00-entscheidungen.md:87-103` | ADR-4 (Veredelung genau einmal, `processedAt` = Modelllauf seit #95) und ADR-5 (Wiedererkennung) |
| `docs/specs/enrichment/feat-136-wiedererkennung.md:200-223, 429-436` | Spec-Zusagen zur Vergleichsmenge, AC-6/AC-7 |

## Existing Patterns

- **Regel vor Modell im selben Durchgang:** `applyRules` schreibt Wert, `*SourceRaw = ai`, `*Confidence`
  und genau eine `Revision` pro Feld — dasselbe Muster wie `EnrichmentWriter`, nur ohne `processedAt`
  (`EnrichmentCoordinator.swift:97-150`). Jede weitere Regel reiht sich dort ein.
- **Guards gegen Doppelschreiben:** `Feld == nil` plus `!EnrichmentWriter.userHasTouched(…)`. Der
  Herkunftsvermerk taugt nicht als Nutzermarker, weil `FieldCodec` ihn beim Leeren mitlöscht; nur eine
  `Revision` mit `author == .user` ist verlässlich (`EnrichmentCoordinator.swift:186-190`).
- **Einmal-Fetch vor der Schleife:** Kontexte, Projekte, Beispiele und Pool werden vor dem Lauf geholt
  (Z. 43-46). Daraus folgt strukturell — nicht per Laufzeitfilter —, dass keine Aufgabe desselben
  Durchgangs Quelle für eine andere sein kann (#136, AC-7).
- **Additive optionale Felder ohne Migrationsplan:** So kamen `showInCalendar`, `repeatRule` und die
  Herkunfts-/Konfidenzfelder ins Modell.

## Dependencies

- **Upstream:** `RecognitionRule` (rein), `RawTextWords` (Tokenisierung), `Revision`/`FieldSource`,
  SwiftData-Fetches über `TaskItem`.
- **Downstream:** `processedAt` wird ausschließlich in `EnrichmentWriter`, `EnrichmentCoordinator` und
  Tests gelesen — **keine** View, keine `ViewRules`, kein Widget hängt daran (geprüft per Volltextsuche).
  `Measurement/LeaveOneOut.swift` nennt `RecognitionRule` nur im Kommentar, kein Codebezug.
- Ein neues Feld auf `TaskItem` wird automatisch in Watch-, Widget- und Share-Target mitgebaut
  (`Shared/` kompiliert dorthin) — kein Zusatzaufwand, aber CloudKit-Regel beachten: optional.

## Existing Specs

- `docs/specs/enrichment/feat-136-wiedererkennung.md` — AC-6 (Vorrang nutzergesetzter Werte),
  **AC-7 (Pool enthält nur bereits verarbeitete Aufgaben)**, AC-8 (keine doppelte Revision)
- `docs/specs/enrichment/feat-95-parser-in-app.md` — AC-7/AC-8: Regelschritt unabhängig vom Modell
- `docs/project/06-annahmen-und-experimente.md` (B1) — Wiedererkennung statt Lernen, Messbeleg

## Risks & Considerations

1. **Die Reproduktionstests aus dem Issue liegen nicht im Repo.** Die Suite
   `RecognitionPoolReachabilityTests` ist nirgends vorhanden (Volltextsuche negativ) — sie entstand im
   Untersuchungs-Worktree und wurde nicht eingecheckt. Phase 4 muss sie neu schreiben; der rote Lauf
   ist damit echt zu erbringen, nicht bloß zu zitieren.

2. **Alternative 1 (`processedAt` nach dem Regelschritt setzen) ist teurer als im Issue beschrieben.**
   Sie kollidiert nicht nur mit ADR-4, sondern schaltet den Modell-Nachzügler-Lauf ab: der
   Pending-Fetch ist `processedAt == nil && statusRaw == unprocessed` (Z. 38). Eine ohne Apple
   Intelligence erfasste Aufgabe bekäme Titel, Energie und Projekt dann **nie mehr**, auch wenn das
   Modell später verfügbar wird. Genau das prüft heute ein Test
   (`EnrichmentTests.swift:262-290`, Kommentar Z. 258-261). Drei weitere Tests fordern nach einem
   modellfreien Lauf ausdrücklich `processedAt == nil` (Z. 570, 636, 670), einer bei der Datumsregel
   (Z. 255).

3. **Alternative 3 (Pool über „hat einen gesetzten Wert mit Herkunft") bricht AC-7 von #136.** Der
   bestehende Test „der Pool enthält nur verarbeitete Aufgaben" (`EnrichmentTests.swift:536-554`) baut
   zwei gleichzeitig unverarbeitete Aufgaben, von denen die erste eine **nutzergesetzte** Dauer trägt,
   und fordert, dass die zweite sie nicht übernimmt. Unter Alternative 3 wäre die erste im Pool und die
   zweite übernähme — die Zusage aus der #136-Spec müsste also geändert werden, nicht nur ein ADR.
   Sachlich wäre das verteidigbar (ein Nutzerwert ist kein KI-Fehler, der sich vervielfachen kann), es
   ist aber eine Spec-Änderung mit eigener Begründungspflicht.

4. **Alternative 2 (eigener Vermerk, z. B. `rulesAppliedAt`) hat eine Bestandsdaten-Lücke.** Aufgaben,
   die vor der Änderung schon veredelt wurden (lokal oder per CloudKit von einem Gerät mit Apple
   Intelligence), hätten `processedAt != nil`, aber `rulesAppliedAt == nil`. Ein Pool, der nur am neuen
   Feld hängt, verliert die gesamte Vorgeschichte — und holt sie nie nach, weil diese Aufgaben nicht
   mehr im Pending-Fetch auftauchen. Der Pool muss deshalb beide Vermerke lesen oder das neue Feld
   nachgetragen werden. Die Migration selbst ist billig (optionales `Date?`, Lightweight, kein
   Migrationsplan vorhanden), die Bestandsfrage ist der eigentliche Punkt.

5. **Der Regelschritt läuft ohne Modell bei jedem App-Start erneut** über alle Aufgaben, weil sie
   `unprocessed` bleiben (Status wird nur in `EnrichmentWriter` gesetzt, Z. 34-37). Ein neuer Vermerk
   darf den Pending-Fetch nicht verengen, sonst verschwinden diese Aufgaben aus dem Lauf, bevor das
   Modell sie je gesehen hat. Umgekehrt verhindern die bestehenden Guards, dass die Wiederholung
   zweite Revisionen anhängt — das muss so bleiben (AC-8).

6. **Kettenweitergabe:** Sobald die Wiedererkennung ohne Modell greift, kann ein übernommener Wert
   seinerseits Saatkorn für eine dritte Aufgabe werden (Vermerk und Herkunft sehen wie beim Original
   aus). Das ist bei wortgleichem Text gewollt, sollte aber bewusst entschieden und nicht nebenbei
   eingeführt werden.

7. **Nachweis im Simulator ist Pflicht (DoD, #145).** Der Ablauf „erfassen → Werte von Hand setzen →
   wortgleich erneut erfassen → Werte sind da" muss in der laufenden App gezeigt werden, nicht nur im
   Test. Werkzeug dafür ist vorhanden (`scripts/sim.sh boot|launch|screenshot`); die Gate-Mechanik aus
   #145 existiert noch nicht, der Durchlauf ist also als Artefakt zu registrieren.

8. **Scope-Grenze:** Änderung an 2-4 Dateien erwartet (`EnrichmentCoordinator`, evtl. `TaskItem` +
   `EnrichmentWriter`, Tests, plus ADR/Spec-Text). Das Feld `energy` bleibt außerhalb (ADR-5), die
   Titel-Frage bleibt außerhalb (das Modell bleibt für Sprachverstehen zuständig).

---

## Analysis

### Type

Bug.

### Reproduktion — selbst erbracht, nicht zitiert

Lauf vom 2026-09-28 in diesem Worktree, `./scripts/sim.sh unit` nach `generate`, mit dem aus dem
Untersuchungszweig `issue-144-pool-erreichbarkeit` (aa24b04) übernommenen RED-Test. Wörtlich:

```
✘ "Ohne Modell übernimmt die zweite wortgleiche Erfassung die Werte der ersten"
    EnrichmentTests.swift:724: Expectation failed: second.duration == .minutes30
    EnrichmentTests.swift:725: Expectation failed: (second.contexts ?? []).map(\.name) == ["Garten"]
✘ "Ohne Modell bekommt keine Aufgabe je einen Verarbeitungs-Vermerk"
    EnrichmentTests.swift:744: Expectation failed: pool.count == 3
✘ Test run with 226 tests in 48 suites failed after 2.947 seconds with 3 issues.
```

Die Vergleichsmenge enthielt 0 statt 3 Aufgaben; die übrigen 223 Tests blieben grün. Der Test ist
auf diesem Zweig committet, damit der Beleg einen `/clear` überlebt. Zusätzlich liegt der
Bedienablauf im Simulator als Bildstrecke vor (`5700c6c`, Zweig `issue-144-pool-erreichbarkeit`):
Bild 2 zeigt `Duration · 30 min`, Bild 4 bei wortgleichem Rohtext nur `Duration`.

### Root Cause — im Code bestätigt, zwei Pfade zum selben Fehler

Beide Pfade laufen über dieselbe Stelle: `task.processedAt = now` steht am Ende von
`EnrichmentWriter.apply` (`EnrichmentWriter.swift:94`), der einzigen Schreibstelle im Produktpfad,
und dieser Aufruf (`EnrichmentCoordinator.swift:60`) steht doppelt eingeschränkt:

1. **Kein Modell** — umschlossen von `if modelUnavailable == nil` (Z. 50).
2. **Fehlgeschlagener Modellaufruf** — nur im `try`-Erfolgsfall; ein Fehlschlag landet im `catch`
   (Z. 62-64) und `apply` läuft nicht. Das trifft auch Hennings iPhone 16 Pro, nicht nur den
   Simulator: eine Aufgabe, deren Modellaufruf einmal scheitert, fällt dauerhaft aus der
   Vergleichsmenge.

Die Vergleichsmenge ist `#Predicate { $0.processedAt != nil }` (Z. 160). Damit ist die Vorbedingung
der Regel nicht *Verfügbarkeit* des Modells, sondern ein *erfolgreicher Modelllauf* — für eine
Regel, die kein Modell braucht. Das widerspricht der Grundregel „Rules before the model".

### Bewertung der drei Alternativen aus dem Issue

| | Bricht bestehende Tests | Bricht Zusagen | Migration | Urteil |
|---|---|---|---|---|
| **1** `processedAt` nach dem Regelschritt setzen | **6 Tests hart** (Z. 181, 255, 284/285, 570, 636, 670), 2 weitere sinnentleert | ADR-4 (00-entscheidungen.md:90-92) und feat-95 AC-7/AC-8 **wörtlich** | keine | verworfen |
| **2** eigener Vermerk `rulesAppliedAt` | keiner | ADR-4 wird ergänzt, feat-136 AC-7 umformuliert — additiv | additiv, optional, Lightweight | **empfohlen** |
| **3** Pool über „hat einen Wert mit Herkunft" | 1 Test (Z. 538-554, AC-7) | feat-136 AC-7 wörtlich | keine | verworfen |

**Warum Alternative 1 teurer ist, als sie aussieht:** Der Nachzügler-Fetch ist
`processedAt == nil && statusRaw == unprocessed` (Z. 38). `processedAt` ohne Modell zu setzen heißt,
dass eine ohne Apple Intelligence erfasste Aufgabe **nie mehr** Titel, Energie, Personen oder Projekt
bekommt, auch wenn das Modell später verfügbar wird. Genau dieses Problem hat #95 bewusst gelöst;
Alternative 1 führt es wieder ein. ADR-4 sagt dazu wörtlich: „Seit #95 markiert `processedAt` nur
noch den Modelllauf … ‚genau einmal' gilt für das Modell, nicht für die regelbasierten Felder."

**Warum Alternative 3 die falsche Zusage kippt:** Der Test „Zwei unverarbeitete Aufgaben im selben
Lauf befruchten sich nicht (AC-7)" (Z. 538-554) baut zwei gleichzeitig unverarbeitete Aufgaben, von
denen die erste eine nutzergesetzte Dauer trägt, und fordert, dass die zweite sie nicht übernimmt.
Unter Alternative 3 wäre die erste im Pool. Zudem braucht Alternative 3 einen Laufzeitfilter, den
der Code (Z. 152-156) ausdrücklich für unnötig erklärt, weil die Abgrenzung aus dem Fetch-Zeitpunkt
folgt.

**Eine vierte Alternative, geprüft und widerlegt:** „Pool = alle Aufgaben außer denen des laufenden
Durchgangs" — kein neues Feld, keine Migration, AC-7 wörtlich erhalten. Trägt nicht: ohne Modell
bleibt `status` dauerhaft `.unprocessed` (nur `EnrichmentWriter` setzt ihn, Z. 34-37), die erste
Aufgabe steht also bei **jedem** Durchgang wieder im Pending-Fetch und wäre damit immer
ausgeschlossen. Der Fehler bliebe bestehen.

### Empfehlung

**Alternative 2:** ein zweiter, optionaler Vermerk `rulesAppliedAt: Date?` auf `TaskItem`, gesetzt
unmittelbar nach `applyRules` und unabhängig davon, ob ein Modell lief oder der Lauf glückte. Die
Vergleichsmenge liest beide Vermerke.

Sie ist die einzige Alternative, die keine der vier belegten Zusagen (ADR-4, feat-95 AC-7/AC-8,
feat-136 AC-7) umstößt, keinen der 226 Tests bricht und beide Fehlerpfade zugleich schließt: Der
Vermerk steht vor dem Modellaufruf, also greift er auch nach einem Fehlschlag. Sie ist zugleich die
Alternative, die „Rules before the model" wörtlich umsetzt — der Regelpfad bekommt seinen eigenen
Zustand statt beim Modell mitzumieten.

**Pool ohne ODER-Prädikat.** Im gesamten Projekt existiert kein einziges `#Predicate` mit `||`
(vier Prädikate insgesamt, alle `==`/`&&`). Ob SwiftData mit CloudKit-Store ein ODER übersetzt, ist
hier unbelegt — deshalb zwei getrennte `FetchDescriptor` (`processedAt != nil`,
`rulesAppliedAt != nil`) und Zusammenführung per `id` in Swift. Das Dedupe-Muster steht schon in
`recognitionInputs` (Z. 162). Damit ist zugleich die Bestandsdaten-Lücke geschlossen: Aufgaben, die
vor der Änderung veredelt wurden oder per CloudKit von einem Gerät mit Apple Intelligence kommen,
tragen `processedAt` und bleiben im Pool.

### Bewusste Folge, die in die Spec gehört

Ab dem **zweiten** Durchgang kann eine noch unverarbeitete Aufgabe Quelle für eine andere noch
unverarbeitete Aufgabe sein — beide tragen dann `rulesAppliedAt`. Der bestehende AC-7-Test bleibt
grün (im ersten Durchgang trägt noch keine den Vermerk), aber die **Formulierung** von AC-7
(„unverarbeitet") muss auf „der Regelschritt lief noch nicht" umgestellt werden.

Sachlich ist das genau die gewollte Wirkung und kein aufgeweichter Schutz: Ohne Modell können Dauer
und Kontexte überhaupt nur aus einer Nutzereingabe oder aus der Wiedererkennung selbst stammen. Das
Saatkorn ist also immer ein Nutzerwert — und `RecognitionRule.winner` (Z. 85-90) bevorzugt
nutzergesetzte Werte ausdrücklich. Der Schutzzweck von AC-7 („ein KI-Fehler vervielfältigt sich
nicht still") bleibt erhalten, weil es ohne Modell keinen KI-Fehler gibt, der sich vervielfältigen
könnte. Ein Selbsttreffer (eine Aufgabe liegt gleichzeitig im Pool und im Pending-Fetch) ist
wirkungslos: die Guards `Feld == nil` und `!userHasTouched(…)` blockieren jedes Schreiben.

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `Shared/Models/TaskItem.swift` | MODIFY | `var rulesAppliedAt: Date?` neben `processedAt`, optional (CloudKit) |
| `Shared/Enrichment/EnrichmentCoordinator.swift` | MODIFY | Vermerk nach `applyRules` setzen; `recognitionInputs` auf zwei Fetches + Dedupe |
| `LooseEndsTests/EnrichmentTests.swift` | MODIFY | RED-Tests liegen vor; dazu: Fehlschlag-Pfad, Bestandsdaten, Dedupe, Modellfreiheit nach Muster `ruleWritesDueDateWithoutModel` |
| `LooseEndsUITests/RecognitionWalkthroughTests.swift` | CREATE | Bedienablauf im Simulator (aus `5700c6c` übernehmen), DoD-Pflicht |
| `docs/project/00-entscheidungen.md` | MODIFY | ADR-4 um einen Satz zu `rulesAppliedAt` ergänzen |
| `docs/specs/enrichment/feat-136-wiedererkennung.md` | MODIFY | AC-7 umformulieren, Implementierungsnotiz zur Vergleichsmenge nachziehen |

### Scope Assessment

- Dateien: 6 (davon 2 Produktivcode) — Grenze „4-5 Dateien" gilt für Produktivcode, Tests und Doku
  zählen gesondert; der Produktivanteil liegt bei 2.
- Geschätzte LoC: Produktivcode **+25/-8**, Tests **+120**, Doku **+20** — zusammen unter 250.
- Risiko: **niedrig**. Additives optionales Feld ohne Migrationsplan (Muster wie `showInCalendar`,
  `repeatRule`); `processedAt` behält seine Bedeutung; keine View, keine `ViewRules`, kein Widget
  liest die berührten Felder (Volltextsuche negativ).

### Kein Entwurf nötig

Es entsteht kein neues Layout und keine neue Zeile. Sichtbar wird nur, dass eine bestehende
Darstellung endlich Werte trägt — Bild 2 des Simulator-Durchlaufs zeigt den Zielzustand bereits.

### Nebenbefund

Der beim Simulator-Durchlauf gefundene `ContextSeeder`-Fehler ist bereits als **#146** erfasst und
bleibt außerhalb dieses Vorgangs.

### Open Questions

Keine. Die Alternativenwahl ist eine technische Entscheidung und ist oben belegt getroffen; die
Umformulierung von AC-7 ist ihre dokumentarische Folge, nicht eine zweite Entscheidung.
