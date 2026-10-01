# Context: bundle-id-debug-156

## Request Summary
Prüfbauten (Debug) dürfen Hennings produktive „Loose Ends"-Installation nicht mehr überschreiben: eigene
Kennung (`.debug`) samt eigener App-Gruppe und eigenem CloudKit-Container, damit der Prüfbau Hennings
Daten nicht einmal theoretisch erreicht (Issue #156, Anlass: Gerätelauf von #153 am 2026-09-30).

## Related Files
| File | Relevance |
|------|-----------|
| `project.yml` | Einzige Quelle für Bundle-IDs (App, Watch, Widgets, Share, Lab, Tests, UITests), Entitlements (App-Gruppe, iCloud-Container, aps-environment) und Info.plist (`WKCompanionAppBundleIdentifier`) — alles heute statisch, nur `settings.base`, keine `configs` |
| `Shared/Persistence/ModelContainerFactory.swift:12-13` | `appGroup` und `cloudContainer` **hart im Code** — Entitlements allein reichen nicht. Folge bei abweichendem Entitlement: `containerURL(...)` liefert nil → stiller Rückfall auf lokalen Speicher ohne Sync (Zeile 51), kein Absturz |
| `LooseEnds/*.entitlements`, `LooseEndsWatch/…`, `LooseEndsWidgets/…`, `LooseEndsShare/…` | Von xcodegen aus `project.yml` erzeugt — nicht von Hand ändern |
| `scripts/sim.sh` | `cmd_launch` (Z. 230) und `cmd_device_launch` (Z. 311) lesen die Kennung aus der gebauten Info.plist → passen sich an. `device_app_path` (Z. 297) hängt an `Debug-iphoneos`. `LAB_BUNDLE` (Z. 347) ist hart `com.henning.looseends.lab`. Simulator-Builds laufen mit `CODE_SIGNING_ALLOWED=NO` |
| `.github/workflows/testflight.yml` | `xcodebuild archive` → Scheme-Archive-Konfiguration = Release; bleibt unverändert, solange Release unverändert bleibt |
| `docs/reference/testflight.md` | Registrierte Kennungen im Developer-Portal (App-ID, App-Gruppe, iCloud-Container) — bekommt ggf. die Debug-Pendants |
| `docs/project/00-entscheidungen.md` | DoD verlangt Eintrag: Prüfbauten tragen nie die Produktivkennung |
| `docs/project/04-stand.md:153-176` | Beschreibt den Vorfall und nennt #156 als Vorbedingung für jede weitere Gerätestufe |

## Existing Patterns
- Build-Einstellungen nur unter `settings.base` je Target; Konfigurationsspezifisches gibt es bisher nicht.
- Info.plist nutzt bereits Build-Variablen (`$(MARKETING_VERSION)`, `$(PRODUCT_MODULE_NAME)`) → Substitution in
  Info.plist ist im Projekt etabliert.
- Laufzeit-Unterscheidung heute über Prozessargumente (`--ui-testing`, `XCTestConfigurationFilePath`), nicht über
  Build-Konfiguration.
- `sim.sh` leitet die Kennung aus dem Build-Produkt ab statt sie zu kennen (gutes Muster, trägt die Änderung).

## Dependencies
- Upstream: Apple Developer Portal (App-IDs, App-Gruppen, iCloud-Container müssen registriert sein),
  Xcode automatische Signierung (`CODE_SIGN_STYLE: Automatic`, `-allowProvisioningUpdates` in `sim.sh`),
  SwiftData `ModelConfiguration(groupContainer:cloudKitDatabase:)`.
- Downstream: alle Targets, die `ModelContainerFactory.make()` aufrufen (App, Watch, Widgets, Share, App Intents),
  `sim.sh` (launch, device-*), TestFlight-Archiv (Release), Hennings Xcode-„Run" aus dem Hauptordner.

## Existing Specs
- `docs/specs/tooling/feat-153-geraetestufe-ui-test.md` — der Gerätelauf, der den Vorfall auslöste (zurückgebaut).

## Recherche (Hennings Regel: zuerst suchen)
- Build-Variablen in Entitlements (`$(APP_GROUP_ID)`) mit Werten je Konfiguration sind das Standardmuster; Xcode
  aktualisiert bei unterschiedlichen `PRODUCT_BUNDLE_IDENTIFIER` je Konfiguration die App-IDs im Portal.
  Bekannter historischer Fehler: Variablen in Entitlements wurden immer gegen Debug aufgelöst (Xcode 8.3,
  rdar 31383369) — heute zu prüfen. Quellen: [Radar 29984128](https://github.com/Ashton-W/Radars/tree/master/29984128%20-%20Xcode%20Automatic%20Provisioning%20resolves%20App%20Groups%20entitlement%20incorrectly),
  [rdar 31383369](https://openradar.appspot.com/31383369), [App Clip / Konfigurationen (Apple-Forum)](https://developer.apple.com/forums/thread/698244),
  [aps-environment je Konfiguration](https://github.com/paz-tech-cwb/monorepo/pull/16)
- xcodegen: `settings.configs.debug` / `.release` je Target; strukturierte und flache Form nicht mischen
  (flache Einträge werden dann still ignoriert). Quelle: [XcodeGen ProjectSpec](https://raw.githubusercontent.com/yonaskolb/XcodeGen/master/Docs/ProjectSpec.md),
  [XcodeGen #491](https://github.com/yonaskolb/XcodeGen/issues/491)
- `WKCompanionAppBundleIdentifier` muss exakt der iOS-Kennung entsprechen; Watch-Kennung = iOS-Kennung +
  `.watchkitapp`. Variablen darin funktionieren in Xcode, Flutter-Toolchain hatte Probleme.
  Quellen: [Apple Doku](https://developer.apple.com/documentation/bundleresources/information-property-list/wkcompanionappbundleidentifier),
  [flutter #77244](https://github.com/flutter/flutter/issues/77244)
- iCloud-Container: `-allowProvisioningUpdates` legt App-IDs und Profile an; ob ein **neuer iCloud-Container**
  dabei automatisch registriert wird, ist unklar — mehrere Berichte „There is no iCloud container on this team"
  bzw. Profil passt nicht zum Entitlement. Vermutlich einmalige Registrierung im Portal/Xcode nötig.
  Quellen: [Apple-Forum 808202](https://developer.apple.com/forums/thread/808202),
  [Apple-Forum 87462](https://developer.apple.com/forums/thread/87462), [CloudKit 101](https://www.rambo.codes/posts/2020-02-25-cloudkit-101)
- CloudKit hat ohnehin zwei Umgebungen: Debug-signierte Builds nutzen „Development", TestFlight/App Store
  „Production". Quelle: [Apple-Forum 707098](https://developer.apple.com/forums/thread/707098)

## Risks & Considerations
- **Hauptrisiko — wo liegen Hennings echte Daten?** Das Issue spricht von „der aus TestFlight installierten App".
  `04-stand.md:182` sagt aber, TestFlight ruht; `CLAUDE.md` beschreibt, dass Henning aus seinem Hauptordner per
  Xcode startet — das ist die **Debug**-Konfiguration. Bekommt Debug pauschal `.debug` + neue App-Gruppe + neuen
  Container, sieht Hennings nächster Xcode-Start eine **leere** App (Daten bleiben unberührt im alten Container,
  sind aber unsichtbar). Das ist eine PO-Frage für die Analyse, keine technische.
- Alternative ohne dieses Risiko: Suffix nicht an „Debug" koppeln, sondern an den Prüfweg (eigene Konfiguration
  oder `BUNDLE_ID_SUFFIX` als Kommandozeilen-Einstellung in `sim.sh device-*`). Weicht von DoD-Punkt 1 ab.
- Neuer iCloud-Container muss evtl. einmalig im Developer-Portal registriert werden — darf nicht an Henning als
  Befehl gehen; notfalls über Xcode-Kontoanbindung bzw. ASC-API klären.
- `ModelContainerFactory` muss die Kennungen aus dem Bundle lesen (z. B. Info.plist-Schlüssel mit Build-Variable),
  sonst fällt der Debug-Build still auf lokalen Speicher ohne Sync zurück.
- `LooseEndsLab` darf nicht mitgezogen werden (hart kodiertes `LAB_BUNDLE` in `sim.sh`, eigene Wegwerf-App).
- `aps-environment: development` bleibt für Debug richtig; Release unverändert lassen (Xcode tauscht beim Export).
- Mac-Build teilt das Target: auch dort ändert sich die Debug-Kennung.
- Geräteliste in `CLAUDE.md`: `project.yml`, Entitlements, Info.plist, `Shared/Persistence/` → Stufe 3 Pflicht.

## Analysis

### Type
Bug (Prüfinfrastruktur) — Prüfbauten installieren unter der Produktivkennung.

### Befund am Gerät (2026-09-30, `devicectl device info apps`, nur lesend)
- `com.henning.looseends` „Loose Ends" ist `builtByDeveloper: true` — **Xcode-Build, keine TestFlight-Installation**.
  Die Prämisse des Issues („aus TestFlight installierte App") stimmt nicht: Hennings Alltags-App IST der Debug-Build.
  Seine Daten liegen damit im CloudKit-**Development**-Bereich (Debug-signiert) und im lokalen App-Gruppen-Speicher.
- `com.henning.looseends.uitests.xctrunner` lag entgegen dem Issue-Text noch auf dem Gerät → mit Hennings Freigabe
  am 2026-09-30 per `devicectl device uninstall app` entfernt; „Loose Ends" danach unverändert vorhanden.
- Kennungen im Swift-Code nur an einer Stelle: `ModelContainerFactory.swift:12-13`.

### Entscheidung (Henning, 2026-09-30)
Frage „Kennung an Debug oder an den Prüfweg?" — Henning: „ich muss die App nicht aus Xcode nutzen. Ich kann mir gerne
die TestFlight Version installieren, wenn es das für dich einfacher macht." Es macht es nicht einfacher, deshalb
**Kennung am Prüfweg** (technische Entscheidung Claude):
- Wechsel auf TestFlight hieße: CloudKit Development → Production (Umzug der Daten ungeklärt, Produktionsschema
  müsste erst ausgerollt werden), jede Auslieferung über Upload + Apple-Verarbeitung statt direkt aus Xcode,
  `loose-ends-sync-main.sh`-Auslieferung würde umgebaut. Größer und riskanter als der Prüfweg.
- **Gekippt:** DoD-Punkt 1 („Debug bekommt `.debug`") und DoD-Punkt 4 („TestFlight-App bleibt unangetastet") werden
  sinngemäß umformuliert: „Prüfbauten bekommen `.probe`, Hennings Xcode-Start (Debug) und Release bleiben unverändert"
  bzw. „Ein Gerätelauf lässt Hennings „Loose Ends" nachweislich unangetastet (beide Apps gleichzeitig sichtbar)".
- Alternative, falls TestFlight wieder Alltagskanal wird (z. B. wenn andere testen): dann Suffix zusätzlich fest an
  Debug koppeln — derselbe Mechanismus, nur ein Default-Wert mehr.

### Technical Approach
1. `project.yml`: Build-Einstellung `BUNDLE_ID_SUFFIX` (Default leer, alle Konfigurationen) in App, Watch, Widgets,
   Share. `PRODUCT_BUNDLE_IDENTIFIER: com.henning.looseends$(BUNDLE_ID_SUFFIX)` (+ `.watchkitapp`, `.widgets`,
   `.share`). Entitlements über Variablen: `group.com.henning.looseends$(BUNDLE_ID_SUFFIX)`,
   `iCloud.com.henning.looseends$(BUNDLE_ID_SUFFIX)`. `WKCompanionAppBundleIdentifier` mit Variable.
   Info.plist-Schlüssel `LEAppGroup` / `LECloudContainer` (Build-Variablen) in allen vier Zielen. Anzeigename bei
   Suffix „LE Prüfbau", damit beide Apps auf dem Home-Bildschirm unterscheidbar sind.
   Lab, Tests, UITests bleiben unverändert (UITests-Runner erbt `TEST_TARGET_NAME`-Kennung + Suffix prüfen).
2. `ModelContainerFactory`: `appGroup`/`cloudContainer` aus `Bundle.main` (Info.plist) lesen, Rückfall auf die
   heutigen Konstanten nur, wenn der Schlüssel fehlt — mit `Logger`-Fehler, kein stiller Rückfall.
3. `scripts/sim.sh`: `device-build` (und jeder künftige Geräte-Testweg) übergibt `BUNDLE_ID_SUFFIX=.probe`;
   `device_app_path`/`cmd_device_launch` lesen die Kennung schon aus dem Produkt. Simulator-Wege unverändert.
4. `docs/project/00-entscheidungen.md`: Eintrag „Prüfbauten tragen nie die Produktivkennung".
5. Unit-Test: Factory liest Gruppe/Container aus einem Info-Dictionary (reine Funktion), Default-Fall = heutige Werte.

Erster Implementierungsschritt ist ein **Machbarkeitsbau**: `device-build` mit Suffix — registriert automatisches
Signieren App-IDs, App-Gruppe UND iCloud-Container `.probe` selbst? (Recherche ungeklärt, s. o.) Falls der
iCloud-Container nicht automatisch angelegt wird: Registrierung über die App-Store-Connect-API bzw. Xcode-Konto,
nicht über Henning. Scheitert das, fällt der Prüfbau auf `cloudKitDatabase: .none` zurück (weiterhin isoliert,
nur ohne Sync-Prüfung) — das würde ich dann im Bericht benennen.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `project.yml` | MODIFY | `BUNDLE_ID_SUFFIX`, variable Kennungen/Entitlements/Info.plist-Schlüssel in App, Watch, Widgets, Share |
| `Shared/Persistence/ModelContainerFactory.swift` | MODIFY | Gruppe/Container aus Info.plist statt Konstanten |
| `scripts/sim.sh` | MODIFY | Gerätebau mit `BUNDLE_ID_SUFFIX=.probe` |
| `LooseEndsTests/…ModelContainerFactoryTests.swift` | CREATE | Kennungsauflösung aus Info-Dictionary |
| `docs/project/00-entscheidungen.md` | MODIFY | Grundsatz Prüfkennung |

### Scope Assessment
- Files: 5 (+ generierte Entitlements/Info.plist)
- Estimated LoC: +70/-15
- Risk Level: MEDIUM — Signierung/Provisioning (Klasse des App-Group-Absturzes); für Hennings Xcode-Start muss der
  Default-Weg bitgleich bleiben (Nachweis: erzeugte Entitlements/Info.plist ohne Suffix identisch zu heute).

### Dependencies
Apple Developer Portal (automatische Registrierung), xcodegen-Variablen in Entitlements/Info.plist, alle Aufrufer
von `ModelContainerFactory.make()` (App, Watch, Widgets, Share, Intents).

### Acceptance (Stufe 3 Pflicht — Geräteliste berührt)
Gerätebau mit Suffix installiert „LE Prüfbau" (`com.henning.looseends.probe`) **neben** „Loose Ends";
`devicectl device info apps` zeigt beide, Version/Installationsstand von „Loose Ends" unverändert. Kein Start
von Hennings App.

### Open Questions
- [x] Kennung an Debug oder am Prüfweg? → Prüfweg (s. Entscheidung)
- [ ] Legt automatisches Signieren den iCloud-Container `.probe` selbst an? → Machbarkeitsbau in Phase 5
