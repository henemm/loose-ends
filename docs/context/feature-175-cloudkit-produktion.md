# Context: feature-175-cloudkit-produktion

## Request Summary
Die TestFlight-Fassung soll zwischen zwei Geräten abgleichen. Zu belegen ist, ob Hennings Alltagsdaten aus dem
CloudKit-Bereich Development dort ankommen und, falls nicht, wie sie hinkommen. Reihenfolge laut Issue #175:
messen → Umzug entscheiden → Schema in Production → Sync-Nachweis auf zwei Geräten → Kontext-Dubletten ansehen.

Die Recherche mit Quellen steht in `docs/artifacts/feature-175-cloudkit-produktion/recherche.md` (R1–R11, O1–O3).

## Related Files
| File | Relevance |
|------|-----------|
| `Shared/Persistence/ModelContainerFactory.swift` | Der einzige Ort, der den CloudKit-Speicher öffnet: `.private(cloudContainer)` in der App-Gruppe, Name „LooseEnds“. Kein `VersionedSchema`, keine `SchemaMigrationPlan`. Schema = `LooseEndsSchema.models` (TaskItem, TaskContext, Project, Revision, CompletionRecord, SavedView). |
| `project.yml` (Z. 31–114) | Berechtigungen: `icloud-container-identifiers`, `aps-environment: development` (App und Watch). `BUNDLE_ID_SUFFIX` trennt den Prüfbau (`.probe`) mit eigenem Container `iCloud.com.henning.looseends.probe`. Kein Eintrag `icloud-container-environment`. Liegt auf der Geräteliste. |
| `.github/workflows/testflight.yml` (Z. 147–167) | Export mit `method = app-store-connect`. Xcode setzt dabei Production; den Umgebungs-Eintrag beachtet der Export nicht mehr (R6). |
| `Shared/Models/TaskItem.swift`, `TaskPlace.swift`, `Enums.swift` | Seit der letzten TestFlight-Fassung (Lauf 37233766254, Stand `723f3cd`, 2026-10-04) sind neue Felder dazugekommen: `place`, `placeSourceRaw`, `placeRemindedAt` (#226/#241). |
| `LooseEndsTests/ModelContainerFactoryTests.swift` | Bestehende Tests der Fabrik (Test-Speicher ohne CloudKit). |
| `docs/reference/testflight.md` | Einrichtung des TestFlight-Laufs; nichts zum CloudKit-Schema. |
| `docs/project/04-stand.md` (Z. 180–200) | Geräte-Stufe, Prüfbau seit #156, „TestFlight ist keine Stufe“. |
| `docs/context/bundle-id-debug-156.md` | Wie der Prüfbau seine eigene Kennung und seinen eigenen Container bekommt. |

## Existing Patterns
- **Getrennte Kennung für Versuche** (#156, ADR-18): Der Prüfbau „LE Prüfbau“ hat einen eigenen iCloud-Container. Dort
  lassen sich O1 (lädt der Fassungswechsel lokale Daten nach Production hoch?) und O3 (greift der Umgebungs-Eintrag
  in Xcode 27 noch?) ausprobieren, ohne Hennings Daten anzufassen. Das braucht aber eine TestFlight-Fassung des
  Prüfbaus oder einen Ad-hoc-Export (R6).
- **Tests nie gegen echte Daten:** Test-Prozesse bekommen einen Speicher im Arbeitsspeicher mit `cloudKitDatabase: .none` (#163).
- **Kontext-Dubletten** werden bei jedem Start zusammengeführt (`mergeDuplicateContexts`, #157); #163 ist geschlossen.
- Restock (Hennings andere App) sichert den lokalen Speicher vor dem ersten CloudKit-Versuch
  (`backupLocalStoreBeforeFirstCloudAttempt`). Das ist ein mögliches Muster für den Umzug.

## Dependencies
- Upstream: SwiftData → NSPersistentCloudKitContainer (Spiegelung), CloudKit-Container `iCloud.com.henning.looseends`,
  CloudKit Console (Schema-Deploy nur dort, R3), App Store Connect / TestFlight-Lauf.
- Downstream: App, Watch, Widgets, Share-Erweiterung, Intents. Alle öffnen denselben Speicher in der App-Gruppe und
  müssen dieselbe CloudKit-Umgebung haben (WWDC26 Group Lab, R10).

## Existing Specs
- Keine Spec zu CloudKit-Produktion. Verwandt: `docs/context/bundle-id-debug-156.md`.

## Risks & Considerations
- **Das Schema in Development ist womöglich unvollständig.** Development legt Felder nur an, wenn ein Datensatz sie mit
  einem Wert schreibt. Ein Feld, das nie gefüllt wurde (z. B. `placeRemindedAt`), fehlt dann im Development-Schema
  und damit auch nach dem Deploy in Production. Folge in TestFlight: Sync-Fehler. Gegenmittel:
  `initializeCloudKitSchema()` einmal gegen Development laufen lassen (R10), danach Development und Production per
  `cktool export-schema` vergleichen (R5, R11).
- **Die TestFlight-Fassung ist veraltet.** Sie stammt vom 2026-10-04 und hat die Ort-Felder nicht. Für die Messung
  braucht es einen neuen Lauf vom aktuellen Stand, sonst misst man ein anderes Schema.
- **Production ist danach nur noch additiv.** Ohne `VersionedSchema` gibt es keinen geordneten Migrationsweg. Jede
  künftige Modelländerung braucht vor dem TestFlight-Bau einen Deploy. Das muss in CLAUDE.md und `testflight.md`
  stehen; denkbar ist eine Schranke im TestFlight-Lauf (R11).
- **Hennings Daten:** Sie liegen in Development und bleiben dort (R1). Auf dem Gerät ersetzt die TestFlight-Fassung
  seine Xcode-Fassung; der lokale Speicher bleibt (R8, R9). Wird die App gelöscht, statt sie zu überinstallieren,
  ist der lokale Stand weg. Die Messung darf nur überinstallieren.
- **Zugang:** Für den Schema-Stand in Production braucht es einen CloudKit-Management-Token (Console → Settings).
  Keiner ist gespeichert (`cktool get-teams`: „No management token found“). Der Deploy selbst ist ein Klick in der
  Console mit Hennings Apple-Konto, also ein Vorgang an seinem Konto (Label `lokal`).
- **Nur auf dem Gerät prüfbar:** Abgleich zwischen zwei Geräten und Push (`aps-environment`). Laut Geräteliste
  betrifft jede Änderung an `project.yml`, Berechtigungen oder `Shared/Persistence/` die Stufe 3.

## Analysis

### Type
Feature, überwiegend Betrieb (Messung, Console, TestFlight, zwei Geräte) mit einem kleinen Code-Anteil.

### Befunde der Analyse (2026-10-08)
- Im Code gibt es weder `initializeCloudKitSchema`, `cktool` noch den Umgebungs-Eintrag. `cktool` liegt unter
  `xcrun`, ein Management-Token fehlt.
- Die letzte TestFlight-Fassung (Lauf 37233766254, 2026-10-04) kennt die Ort-Felder nicht. Die Messung braucht einen
  neuen Lauf.
- Alle sechs Modelle sind CloudKit-tauglich: Beziehungen optional, Vorgabewerte überall, kein `@Unique`.
- App, Watch und Share haben iCloud-Berechtigungen. Widgets haben nur die App-Gruppe (`project.yml` Z. 132–135).
  Das ist so beabsichtigt oder ein eigener Befund, gehört aber nicht zu #175.
- FocusBlox und Restock nutzen weder den Umgebungs-Eintrag noch `initializeCloudKitSchema`. Hennings „nie Probleme"
  erklärt sich damit nicht über einen Kniff, sondern wahrscheinlich über R8/R9 (lokaler Speicher bleibt).
- **Sicherheitsnetz für Hennings Daten:** Sie liegen auch in CloudKit Development. Eine neue Xcode-Fassung holt sie von
  dort zurück. Zusätzlich lässt sich vor der Überinstallation der App-Gruppen-Speicher per
  `devicectl device copy from --domain-type appGroupDataContainer` auf den Mac kopieren. Das geht ohne Code und liest
  nur.

### Reihenfolge gegenüber dem Issue geändert
Das Issue misst zuerst und rollt danach das Schema aus. Ohne Schema in Production misst die TestFlight-Fassung aber nur
R2 („Production lehnt ab, Daten bleiben lokal"). Das ist vorhersagbar und beantwortet O1 nicht. Deshalb: erst lesen
(O2), dann Schema vollständig machen und ausrollen, dann messen.

### Slices
| Slice | Art | Inhalt | Dateien / LoC |
|---|---|---|---|
| S0 | Betrieb | Token anlegen, `cktool export-schema` für Development **und** Production, beide gegen `LooseEndsSchema` abgleichen (O2) | 0 / 0, Protokoll in `docs/artifacts/feature-175-cloudkit-produktion/` |
| S1 | Code, nur wenn S0 Lücken in Development zeigt | Schema-Initialisierer (eigener Speicherort, nie App-Gruppe wegen ProcessCache), Startargument, Test | 3–4 / 150–200 |
| S2 | Betrieb, Hennings Konto | „Deploy Schema Changes" in der Console, danach Production-Export = Development-Export (R5) | 0 / 0 |
| S3 | Betrieb | Speicher sichern (devicectl), neuer TestFlight-Lauf, Henning überinstalliert auf dem iPhone (nie löschen) | 0 / 0 |
| S4 | Betrieb | O1 messen (kommen seine Aufgaben auf Gerät B an?) und Abgleich A→B belegen | Protokoll |
| S5 | eigenes Issue | Schutzschranke: Schema-Abbild im Repo, Test „Modell = Abbild", Prüfung in `testflight.yml` per `cktool` (R11) | 3 / 60–150 |
| S6 | Doku | `docs/reference/testflight.md`, CLAUDE.md: Production nur additiv, Deploy vor jedem TestFlight-Bau mit Modelländerung | 2 / ~40 |
| — | eigenes Issue, nach S4 | Kontext-Dubletten in Production ansehen (#157/#163) | — |

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `docs/artifacts/feature-175-cloudkit-produktion/messprotokoll.md` | CREATE | S0, S2, S4: Schema-Exporte, Deploy-Beleg, Messergebnis O1, Zwei-Geräte-Beleg |
| `Shared/Persistence/CloudKitSchemaInitializer.swift` | CREATE (nur falls S0 Lücken zeigt) | `NSPersistentCloudKitContainer` + `NSManagedObjectModel.makeManagedObjectModel(for:)` + `initializeCloudKitSchema()` auf eigenem Speicherort |
| `LooseEnds/LooseEndsApp.swift` | MODIFY (nur falls S1) | Startargument greift vor `ModelContainerFactory.make` |
| `LooseEndsTests/CloudKitSchemaInitializerTests.swift` | CREATE (nur falls S1) | Initialisierer läuft nie unter Tests und nie gegen den App-Gruppen-Speicher |
| `docs/reference/testflight.md`, `CLAUDE.md` | MODIFY | S6 |

### Scope Assessment
- Files: 3 (nur Betrieb + Doku) bis 6 (mit S1)
- Estimated LoC: +40 (Doku) bis +240 (mit S1)
- Risk Level: MEDIUM. Code-Risiko gering. Das Risiko liegt im Betrieb: Der Deploy ist endgültig (nur noch additiv,
  R4), und die Überinstallation berührt Hennings Alltags-App. Abgefedert wird es durch die Sicherung und die Kopie in
  Development.

### Technical Approach (Empfehlung)
Weg 1 der Recherche, ergänzt um eine Messung zuerst:
1. S0: beide Schemata lesen.
2. S1 nur, falls Development Lücken hat. Ohne Lücken entfällt Code ganz. Regel: Die einfachste Lösung kommt zuerst.
3. S2: Henning drückt Deploy.
4. S3/S4: TestFlight messen.

Lädt die TestFlight-Fassung die lokalen Daten hoch (O1 positiv), ist der Umzug erledigt. Wenn nicht, wird der Umzug
neu entschieden (Alternative B). Kippt keine ADR.

### Alternativen
- **A — Xcode-Fassung auf Production (R7):**
  - Henning bleibt bei Xcode, beide Fassungen teilen Daten.
  - Unbelegt für Xcode 27. Jeder Xcode-Lauf mit noch nicht ausgerolltem Modell schreibt gegen das echte Schema.
  - Berührt ADR-2 (Umgebungen getrennt) und verlangt eine Probe mit `.probe` (O3). Sie ist sinnvoll, falls Henning
    dauerhaft aus Xcode arbeiten will.
- **B — Einmaliger Umzug per Export/Import:**
  - Sicherer Rückweg, falls O1 negativ ist.
  - Eigenes Issue, etwa 200+ LoC: alle Felder, Revisionen, Wiederholungen, Kontexte nach Namen.
- **C — Neustart in Production ohne Übernahme:**
  - Am billigsten. Development bleibt Archiv.
  - Henning sieht seine Aufgaben nur noch, solange der lokale Speicher sie hält.

### Dependencies
- SwiftData → `NSPersistentCloudKitContainer`. Container `iCloud.com.henning.looseends`.
- Die CloudKit Console verlangt Hennings Apple-Konto (Token, Deploy).
- TestFlight-Lauf (`testflight.yml`).
- Ein zweites Gerät mit derselben Apple-ID.

### Open Questions
- [ ] Welches zweite Gerät für den Abgleich-Nachweis? (iPad aus TestFlight; der Mac bekommt aus `testflight.yml` keine
      eigene Fassung)
- [ ] Darf ich in Hennings angemeldetem Chrome die CloudKit Console öffnen, einen Management-Token anlegen und die
      Schemata lesen? Der Deploy-Knopf folgt erst nach eigener Freigabe.
