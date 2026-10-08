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
