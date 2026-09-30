---
entity_id: fix-156-pruefkennung
type: bugfix
created: 2026-09-30
updated: 2026-09-30
status: draft
workflow: bundle-id-debug-156
---

# Spec: #156 — Prüfbauten tragen eigene Kennung (`.probe`), Hennings App bleibt unangetastet

## Approval

- [ ] Approved

## Purpose

Am 2026-09-30 lief beim Bau von #153 ein UI-Test signiert auf Hennings iPhone. Er installierte
unter derselben Kennung wie Hennings produktive Installation (`com.henning.looseends`), überschrieb
sie und startete sie im Vordergrund. Issue #156 verlangt, dass Prüfbauten künftig strukturell nicht
mehr an Hennings Daten herankommen können — nicht durch Disziplin, sondern durch eine eigene
Kennung samt eigener App-Gruppe und eigenem CloudKit-Container.

Diese Spec gibt jedem Gerätebau eine eigene Kennung (`.probe`-Suffix auf Bundle-ID, App-Gruppe und
iCloud-Container), ohne Debug oder Release anzufassen: Beide bleiben bitgleich zu heute, solange
niemand die Kennung explizit anfordert.

### Abweichungen vom Ticket (mit Begründung)

Der Befund am Gerät (2026-09-30, `devicectl device info apps`, nur lesend) widerlegt eine Prämisse
des Issues: „Loose Ends" auf Hennings iPhone ist `builtByDeveloper: true` — ein Xcode-Build, **keine
TestFlight-Installation**. Hennings Alltags-App ist der Debug-Build, den er per Xcode-„Run" aus
seinem Hauptordner startet (`CLAUDE.md`, Abschnitt „Ausliefern"). TestFlight ruht seit
`docs/project/04-stand.md:182`. Damit tragen zwei DoD-Punkte des Issues eine Prämisse, die nicht
zutrifft:

| DoD-Punkt (Issue) | Änderung in dieser Spec | Begründung |
|---|---|---|
| 1. „project.yml setzt für Debug `.debug`, Release unverändert" | **Ersetzt durch:** Prüfbauten (der Gerätebau-Pfad in `sim.sh`) bekommen `.probe`; Debug (Hennings Xcode-„Run") und Release bleiben beide unverändert | Debug pauschal auf `.debug` umzustellen hieße: Hennings nächster Xcode-Start sähe eine **leere** App — seine Daten blieben im alten App-Gruppen-Speicher und CloudKit-Development-Bereich liegen, wären aber für die neue Kennung unsichtbar. Ein Wechsel auf TestFlight, um diesen Bruch zu vermeiden, wäre größer und riskanter als das eigentliche Ticket: CloudKit Development → Production (Datenumzug ungeklärt, Produktionsschema müsste erst ausgerollt werden), jede Auslieferung über Upload + Apple-Verarbeitung statt direkt aus Xcode, `loose-ends-sync-main.sh` müsste umgebaut werden. Henning selbst am 2026-09-30: „ich muss die App nicht aus Xcode nutzen. Ich kann mir gerne die TestFlight Version installieren, wenn es das für dich einfacher macht." Es macht es nicht einfacher — technische Entscheidung Claude: Kennung am **Prüfweg**, nicht an der Build-Konfiguration. |
| 4. „Gerätelauf lässt die aus TestFlight installierte App nachweislich unangetastet" | **Ersetzt durch:** Ein Gerätebau mit `.probe` lässt Hennings tatsächliche Alltags-App (Debug, `com.henning.looseends`) nachweislich unangetastet — beide Apps gleichzeitig auf dem Gerät sichtbar | Es gibt keine TestFlight-Installation, die unangetastet bleiben könnte; der Nachweis muss sich auf die tatsächlich vorhandene App beziehen. |

DoD-Punkte 2 (App-Gruppe/CloudKit ziehen mit), 3 (Watch/Widget/Share ziehen mit) und 5
(00-entscheidungen.md-Eintrag) bleiben inhaltlich wie im Issue, nur bezogen auf den Prüfweg statt
auf „Debug" als Konfiguration.

### Alternative (nicht gewählt, mit Kipppunkt benannt)

**Suffix fest an die Debug-Konfiguration koppeln** (näher am ursprünglichen Issue-Wortlaut): Wird
TestFlight wieder Hennings Alltagskanal (weil z. B. andere Personen testen und ein sauberer
Vertriebsweg gebraucht wird), verliert das Argument „Debug ist seine Alltags-App" seine Grundlage.
Dann ist derselbe Mechanismus (Variable statt Konstante, Kennung aus dem Bundle lesen) direkt
wiederverwendbar — nur der Default-Wert von `BUNDLE_ID_SUFFIX` wechselt von „leer" auf „konfigurations-
abhängig" (`.debug` für Debug, leer für Release), was dann `settings.configs.debug`/`.release` in
`project.yml` statt eines reinen Kommandozeilen-Overrides braucht. Das würde die hier getroffene
Entscheidung „Kennung am Prüfweg" kippen, nicht diese Spec selbst — es ist als Migrationspfad
festgehalten, nicht als offene Frage.

## Source

- **File:** `project.yml`
- **Identifier:** `settings.base` (Zeile 14–27, projektweit), `targets.LooseEnds/.LooseEndsWatch/.LooseEndsWidgets/.LooseEndsShare` — `entitlements.properties`, `info.properties`, `settings.base.PRODUCT_BUNDLE_IDENTIFIER`
- **File:** `Shared/Persistence/ModelContainerFactory.swift`
- **Identifier:** `static let appGroup`/`cloudContainer` (Zeile 12–13) — hart kodiert, einzige Stelle im Code mit den Kennungen
- **File:** `scripts/sim.sh`
- **Identifier:** `cmd_device_build` (Zeile 271–284), `args=(...)`

## Dependencies

| Baustein | Art | Zweck |
|---|---|---|
| Apple Developer Portal / automatische Signierung (`CODE_SIGN_STYLE: Automatic`, `-allowProvisioningUpdates` in `cmd_device_build`) | Upstream | Muss App-ID, App-Gruppe **und** iCloud-Container für `.probe` anlegen können — Recherche in `docs/context/bundle-id-debug-156.md` fand keinen belastbaren Beleg, dass Letzteres automatisch geschieht. Wird im Machbarkeitsbau (unten) geklärt. |
| xcodegen-Variablensubstitution in Entitlements/Info.plist (`$(BUNDLE_ID_SUFFIX)`, `$(LE_DISPLAY_NAME)`) | Werkzeug | Etabliertes Muster im Projekt (`$(MARKETING_VERSION)`, `$(PRODUCT_MODULE_NAME)` bereits in `project.yml` verwendet) |
| Alle Aufrufer von `ModelContainerFactory.make()` (App, Watch, Widgets, Share, App Intents) | Downstream | Lesen künftig `appGroup`/`cloudContainer` aus dem Bundle statt aus Konstanten — jeder Aufrufer muss weiterhin denselben Wert je Prozess sehen (kein Verhaltensunterschied für Standardbauten) |
| `LooseEndsLab` (Messprogramm) | Unverändert, explizit ausgenommen | Hat keine App-Gruppe, kein CloudKit — trägt kein `BUNDLE_ID_SUFFIX` und wird von dieser Spec nicht berührt |
| `.github/workflows/testflight.yml` | Unverändert, geprüft | `xcodebuild archive`/`-exportArchive` übergeben kein `BUNDLE_ID_SUFFIX` (Zeile 64–102) — das Release-Archiv bleibt beim Default (leer) |

## Scope

### Affected Files

| File | Change Type | Beschreibung |
|---|---|---|
| `project.yml` | MODIFY | `BUNDLE_ID_SUFFIX: ""` und `LE_DISPLAY_NAME: Loose Ends` einmal projektweit in `settings.base` (Zeile 14–27); `PRODUCT_BUNDLE_IDENTIFIER` in App/Watch/Widgets/Share auf `$(BUNDLE_ID_SUFFIX)` erweitert; Entitlements-Werte (`group.…`, `iCloud.…`) und `WKCompanionAppBundleIdentifier` mit derselben Variable; `CFBundleDisplayName` in allen vier Zielen auf `$(LE_DISPLAY_NAME)`; neue Info.plist-Schlüssel `LEAppGroup`/`LECloudContainer` in App, Watch, Widgets, Share |
| `Shared/Persistence/ModelContainerFactory.swift` | MODIFY | `appGroup`/`cloudContainer` werden aus `Bundle.main.infoDictionary` über eine reine Funktion `resolveIdentifiers(from:fallbackGroup:fallbackContainer:)` aufgelöst; Rückfall auf die heutigen Konstanten nur bei fehlendem Schlüssel, mit `Logger`-Fehler statt stillem Rückfall |
| `scripts/sim.sh` | MODIFY | `cmd_device_build`: `args` bekommt `BUNDLE_ID_SUFFIX=.probe` und `LE_DISPLAY_NAME=LE Prüfbau` als zusätzliche `xcodebuild`-Kommandozeilen-Einstellungen, exakt nach demselben Muster wie das heutige `DEVELOPMENT_TEAM=$TEAM_ID` |
| `LooseEndsTests/ModelContainerFactoryTests.swift` | CREATE (geprüft: existiert nicht — `ls LooseEndsTests/` enthält keine Datei zu `ModelContainerFactory` oder `Persistence`) | Unit-Tests für `resolveIdentifiers`: Schlüssel vorhanden → gelesene Werte; Schlüssel fehlt → heutige Konstanten |
| `docs/project/00-entscheidungen.md` | MODIFY | Neuer Eintrag ADR-18 „Prüfkennung": Prüfbauten tragen nie die Produktivkennung |

### Estimated Changes

- Files: 5 (innerhalb der 4–5-Grenze aus `CLAUDE.md`)
- LoC: ~+70/-15 (innerhalb der 250er-Grenze)
  - `project.yml`: ~+30/-10 (zwei neue globale Einstellungen, vier Bundle-IDs, sechs
    Entitlement-Werte, ein Companion-Bezeichner, vier Anzeigenamen, acht neue Info.plist-Zeilen
    für die zwei neuen Schlüssel in vier Zielen)
  - `Shared/Persistence/ModelContainerFactory.swift`: ~+18/-4
  - `scripts/sim.sh`: ~+2/-0
  - `LooseEndsTests/ModelContainerFactoryTests.swift`: ~+45 (neue Datei)
  - `docs/project/00-entscheidungen.md`: ~+8

## Implementation Details

### Schritt 0 — Machbarkeitsbau (zuerst, vor allem anderen Code)

Die Recherche in `docs/context/bundle-id-debug-156.md` fand keinen belastbaren Beleg, ob
`-allowProvisioningUpdates` einen **neuen iCloud-Container** (`iCloud.com.henning.looseends.probe`)
automatisch registriert, so wie es das für App-IDs und App-Gruppen zuverlässig tut. Deshalb ist der
erste Implementierungsschritt ein Testbau, nicht das fertige Feature:

1. `project.yml` und `ModelContainerFactory.swift` wie unten beschrieben ändern, `xcodegen generate`.
2. `./scripts/sim.sh device-build` mit `.probe`-Suffix laufen lassen (liest nur die Xcode-Ausgabe,
   kein Schritt, den Henning tippen muss).
3. Ergebnis prüfen:
   - **Erfolgsfall:** Build und Signierung gehen durch, `-allowProvisioningUpdates` hat App-ID,
     App-Gruppe und iCloud-Container `.probe` selbst angelegt. Weiter mit Schritt 1 unten.
   - **Fehlerfall (iCloud-Container fehlt/passt nicht zum Profil):** Dann scheitert bereits das
     **Signieren beim Bauen** — das Profil deckt das Entitlement nicht ab. Der bestehende
     `catch`-Block in `ModelContainerFactory.make()` (Zeile 56–68) hilft hier nicht, er greift erst
     zur Laufzeit. Vorgehen in dieser Reihenfolge:
     1. Einmalige Anlage des Containers `iCloud.com.henning.looseends.probe` über die
        Xcode-Kontoanbindung bzw. das Developer-Portal-API — nie über einen Befehl, den Henning tippt.
     2. Gelingt das nicht: Der Prüfbau verzichtet auf das iCloud-Entitlement. Dafür bekommt
        `project.yml` eine zweite Build-Variable (`LE_ICLOUD_CONTAINERS`, Default = heutiger
        Container, im Prüfbau leer), und `ModelContainerFactory` nutzt bei leerem
        `LECloudContainer` `cloudKitDatabase: .none`. Der Prüfbau bleibt isoliert (eigene App-Gruppe,
        eigener lokaler Speicher), nur ohne Sync-Prüfung. Das kostet ~+10 LoC in denselben Dateien
        und wird im Abschlussbericht offen benannt.

Dieser Schritt entscheidet, ob AC-d (unten) den vollen Sync-Pfad oder den dokumentierten
Rückfallpfad zeigt. Beide Ausgänge erfüllen das Ticket, weil die Isolation in beiden Fällen steht.

### 1. `project.yml` — Variable statt Konstante

Global in `settings.base` (Zeile 14–27), zwei neue Einstellungen mit Default, die **jeder** Bau
ohne expliziten Override bekommt (Xcode-„Run", Simulator, CI, Release-Archiv):

```yaml
settings:
  base:
    ...
    BUNDLE_ID_SUFFIX: ""
    LE_DISPLAY_NAME: Loose Ends
```

In `targets.LooseEnds.settings.base`:
```yaml
PRODUCT_BUNDLE_IDENTIFIER: com.henning.looseends$(BUNDLE_ID_SUFFIX)
```
Entitlements:
```yaml
com.apple.developer.icloud-container-identifiers: [iCloud.com.henning.looseends$(BUNDLE_ID_SUFFIX)]
com.apple.security.application-groups: [group.com.henning.looseends$(BUNDLE_ID_SUFFIX)]
```
Info.plist: `CFBundleDisplayName: $(LE_DISPLAY_NAME)`, dazu zwei neue Schlüssel
`LEAppGroup: group.com.henning.looseends$(BUNDLE_ID_SUFFIX)` und
`LECloudContainer: iCloud.com.henning.looseends$(BUNDLE_ID_SUFFIX)`.

Analog für `LooseEndsWatch` (zusätzlich `WKCompanionAppBundleIdentifier: com.henning.looseends$(BUNDLE_ID_SUFFIX)`,
Bundle-ID bleibt `com.henning.looseends$(BUNDLE_ID_SUFFIX).watchkitapp`),
`LooseEndsWidgets` (nur App-Gruppe + `LEAppGroup`, kein iCloud-Container — die Widgets-Entitlements
tragen heute keinen; `LECloudContainer` wird trotzdem mitgeführt, weil `ModelContainerFactory` den
Wert heute unabhängig vom Entitlement des jeweiligen Ziels liest, siehe unten) und `LooseEndsShare`
(App-Gruppe + iCloud-Container + beide Info.plist-Schlüssel).

`LooseEndsLab`, `LooseEndsTests`, `LooseEndsUITests` bleiben unverändert — keine App-Gruppe, kein
CloudKit, kein Suffix. Der UI-Test-Runner erbt seine Kennung vom `TEST_TARGET_NAME` der App; da
`BUNDLE_ID_SUFFIX` dort nicht überschrieben wird, bleibt sie beim Default (leer).

**Warum ein globaler Kommandozeilen-Override statt `settings.configs.debug`/`.release`:** Die
Recherche fand einen historischen, ungeprüften Fehlerbericht (Xcode 8.3, rdar 31383369), dass
Variablen in Entitlements bei automatischer Signierung teils gegen die Debug-Konfiguration statt
gegen die tatsächlich aktive aufgelöst wurden. Ein reiner Kommandozeilen-Override (wie das
bestehende `DEVELOPMENT_TEAM=$TEAM_ID` in `cmd_device_build`) umgeht diese Fehlerklasse
strukturell: Es gibt keine konfigurationsabhängigen Werte, nur einen einzigen globalen Default und
eine explizite Überschreibung für genau den einen Bau, der sie braucht. Xcodes eigener „Run" aus
Hennings Hauptordner übergibt nie einen Override und bekommt damit garantiert den Default.

### 2. `ModelContainerFactory.swift` — Kennung aus dem Bundle lesen

```swift
enum ModelContainerFactory {
    private static let fallbackAppGroup = "group.com.henning.looseends"
    private static let fallbackCloudContainer = "iCloud.com.henning.looseends"

    static func resolveIdentifiers(
        from infoDictionary: [String: Any]?,
        fallbackGroup: String = fallbackAppGroup,
        fallbackContainer: String = fallbackCloudContainer
    ) -> (group: String, container: String) {
        let group = infoDictionary?["LEAppGroup"] as? String
        let container = infoDictionary?["LECloudContainer"] as? String
        if group == nil { logger.error("LEAppGroup fehlt im Info-Dictionary, Rückfall auf Konstante") }
        if container == nil { logger.error("LECloudContainer fehlt im Info-Dictionary, Rückfall auf Konstante") }
        return (group ?? fallbackGroup, container ?? fallbackContainer)
    }

    private static let identifiers = resolveIdentifiers(from: Bundle.main.infoDictionary)
    static let appGroup = identifiers.group
    static let cloudContainer = identifiers.container
    ...
}
```

`resolveIdentifiers` ist eine reine Funktion ohne `Bundle`-Zugriff — testbar mit einem
handgebauten `[String: Any]`, ohne echtes Bundle oder App-Start. `appGroup`/`cloudContainer`
bleiben `static let`: Sie werden einmal pro Prozess beim ersten Zugriff aufgelöst (das Bundle ändert
sich zur Laufzeit nicht), ein fehlender Schlüssel wird also einmal protokolliert, nicht bei jedem
Zugriff. Die bestehende Aufrufstelle in `make()` (Zeile 51, 60–61) bleibt unverändert.

### 3. `scripts/sim.sh` — `cmd_device_build` übergibt die Prüfkennung

```bash
local args=(build -project "$PROJECT" -scheme "$SCHEME" -destination "id=$id"
            -derivedDataPath "$dd" -allowProvisioningUpdates "DEVELOPMENT_TEAM=$TEAM_ID"
            "BUNDLE_ID_SUFFIX=.probe" "LE_DISPLAY_NAME=LE Prüfbau")
```

`device_app_path` (Zeile 294) und `cmd_device_launch` (Zeile 309–318) lesen die Kennung bereits
heute aus der gebauten `Info.plist` (`plutil -extract CFBundleIdentifier raw …`) statt sie zu
kennen — sie brauchen keine Änderung, tragen die neue Kennung automatisch. `cmd_lab` (Zeile
347–380, eigener `LAB_SCHEME`/`LAB_BUNDLE`) bleibt unberührt, ebenso `run_xcodebuild` (Simulator,
Zeile 122–133) und der TestFlight-Workflow — beide übergeben `BUNDLE_ID_SUFFIX` nie, bleiben also
beim Default.

### 4. `docs/project/00-entscheidungen.md` — neuer Eintrag

Anfügen nach ADR-17 (Zeile 174, vor „Bewusst nicht in Version 1"):

```markdown
**ADR-18 Prüfkennung.** Jeder signierte Gerätebau (`./scripts/sim.sh device-build` und jeder
künftige Geräte-Testweg) trägt die Kennung `com.henning.looseends.probe` samt eigener App-Gruppe
und eigenem iCloud-Container, Anzeigename „LE Prüfbau". Debug (Hennings Xcode-„Run") und Release
bleiben beim Standard-Suffix (leer) und damit bitgleich zu heute. Anlass: Der Gerätelauf von #153
installierte 2026-09-30 unter Hennings Produktivkennung und überschrieb seine Installation. Die
Kennung hängt am Prüfweg, nicht an der Build-Konfiguration — Begründung und Alternative in
`docs/specs/tooling/fix-156-pruefkennung.md` (#156).
```

## Test Plan

### Geplante Tests — nur Unit-Tests, keine UI-Tests

Diese Änderung hat keine sichtbare UI-Oberfläche und keinen Bedienablauf: Sie verschiebt zwei
Konstanten in eine Bundle-Auflösung und fügt Build-Variablen hinzu. Ein UI-Test würde nichts prüfen,
was ein Unit-Test nicht ohnehin abdeckt, und könnte die Kennungsauflösung ohnehin nicht am
Signierungs- und Provisioning-Verhalten prüfen — das ist ausschließlich am echten Gerät sichtbar
(deshalb Stufe 3 unten). ADR-11 verlangt UI-Tests ohnehin erst nach Design-Freeze und nur als
Smoke-Tests; hier gibt es kein Design und keinen Bedienablauf, der einen rechtfertigt.

- **`LooseEndsTests/ModelContainerFactoryTests.swift`** (neu):
  - `resolveIdentifiers` mit `["LEAppGroup": "group.x", "LECloudContainer": "iCloud.x"]` liefert
    genau diese beiden Werte zurück.
  - `resolveIdentifiers` mit leerem/`nil`-Dictionary liefert die heutigen Konstanten
    (`group.com.henning.looseends`, `iCloud.com.henning.looseends`) zurück — das ist die
    Rückfall-Garantie, die Hennings Standardbau nie berührt.
  - `resolveIdentifiers` mit nur einem der beiden Schlüssel liefert für den fehlenden den
    Standardwert, für den vorhandenen den gelesenen Wert (gemischter Fall).
- **`./scripts/sim.sh unit`** — Regressionsschutz, dass `ModelContainerFactory` weiterhin für alle
  bestehenden Aufrufer kompiliert und die In-Memory-/Test-Zweige (`isRunningTests`, `isUITesting`)
  unverändert funktionieren.
- **`./scripts/sim.sh build` + `./scripts/sim.sh launch`** (Simulator, Stufe 2) — belegt, dass der
  Standardbau ohne Suffix unverändert startet und `com.henning.looseends` bleibt.

## Acceptance Criteria

- **AC-a Standardbau bitgleich:** Given `project.yml` ohne Override generiert und gebaut / When die
  erzeugten Entitlements- und Info.plist-Werte aller vier betroffenen Ziele (App, Watch, Widgets,
  Share) mit dem heutigen Stand verglichen werden / Then sind `PRODUCT_BUNDLE_IDENTIFIER`,
  App-Gruppe, iCloud-Container, `WKCompanionAppBundleIdentifier` und `CFBundleDisplayName`
  inhaltlich identisch zu heute (weil `BUNDLE_ID_SUFFIX`/`LE_DISPLAY_NAME` beim Default stehen);
  `LEAppGroup`/`LECloudContainer` sind neue, zusätzliche Info.plist-Schlüssel, deren Werte den
  heutigen hart kodierten Konstanten entsprechen — additiv, keine bestehenden Werte werden entfernt
  oder geändert. Nachweis: `xcodegen generate` vor/nach dieser Änderung, `plutil -p` bzw.
  `codesign -d --entitlements -` auf den erzeugten Build-Produkten vergleichen.
- **AC-b Unit-Test grün, Rückfall geprüft:** Given `LooseEndsTests/ModelContainerFactoryTests.swift`
  / When `./scripts/sim.sh unit` läuft / Then sind alle drei Fälle (beide Schlüssel vorhanden, beide
  fehlend, gemischt) grün, und der Fehlend-Fall liefert nachweislich die heutigen Konstanten.
- **AC-c Simulator unverändert (Stufe 2):** Given der Standardbau ohne Override / When
  `./scripts/sim.sh build && ./scripts/sim.sh launch` läuft / Then startet die App unverändert mit
  Bundle-ID `com.henning.looseends`, kein Absturz, kein neues Verhalten.
- **AC-d Gerätebau installiert isoliert neben Hennings App (Stufe 3):** Given
  `./scripts/sim.sh device-build` mit `BUNDLE_ID_SUFFIX=.probe` gefolgt von
  `./scripts/sim.sh device-install` / When `devicectl device info apps --device <id>` gelesen wird /
  Then erscheinen **beide** Einträge — „Loose Ends" (`com.henning.looseends`) und „LE Prüfbau"
  (`com.henning.looseends.probe`); Version/Installationsstand (Build-Zeitstempel,
  `dataContainerSize`/letzte Änderung) von „Loose Ends" ist gegenüber dem Stand vor dem Prüfbau
  unverändert; weder `device-launch` noch `device` (kombiniert) werden gegen eine der beiden Apps
  aufgerufen — der Nachweis bleibt beim rein installierenden `device-build`/`device-install`, kein
  Fernstart (ADR-11 gilt weiterhin uneingeschränkt für jede App auf Hennings Gerät, nicht nur seine
  eigene).
- **AC-e Grundsatz dokumentiert:** Given `docs/project/00-entscheidungen.md` / When ADR-18 gelesen
  wird / Then steht dort, dass Prüfbauten nie die Produktivkennung tragen, mit Verweis auf #156 und
  diese Spec.
- **AC-f Release/TestFlight unverändert:** Given `.github/workflows/testflight.yml` / When die
  `xcodebuild archive`/`-exportArchive`-Aufrufe gelesen werden / Then übergeben sie kein
  `BUNDLE_ID_SUFFIX` — das Release-Archiv bleibt beim Default (leer), keine Datei in diesem Workflow
  wird geändert.

## Risiken

1. **iCloud-Container-Registrierung ungeklärt** (siehe Machbarkeitsbau, Schritt 0). Fehlt der
   Container, scheitert das Signieren beim Bauen, nicht erst die App zur Laufzeit. Rückfall: Anlage
   über Xcode-Konto/Portal-API, sonst Prüfbau ohne iCloud-Entitlement (Schritt 0, Punkt 2), also
   isoliert, aber ohne Sync-Prüfung. Das ist im Bericht offen zu benennen und blockiert das Ticket nicht.
2. **Entitlement-Variablen-Auflösung bei automatischer Signierung** — historischer Xcode-8.3-Fehler
   (Variablen wurden gegen Debug statt gegen die aktive Konfiguration aufgelöst). Durch den
   Kommandozeilen-Override (kein `configs`-Split) strukturell unwahrscheinlich, aber am
   Machbarkeitsbau zu bestätigen, nicht nur zu vermuten.
3. **Widgets-Ziel hat kein iCloud-Entitlement, bekommt aber `LECloudContainer` in der Info.plist.**
   Das entspricht dem heutigen Verhalten (die hart kodierte Konstante gilt heute schon
   unabhängig vom jeweiligen Ziel-Entitlement) — keine neue Diskrepanz, aber auch keine Bereinigung
   einer bestehenden. Außerhalb des Scopes dieses Tickets.
4. **Scoping-Grenze knapp:** 5 Dateien, geschätzt ~70/-15 LoC — an der oberen Grenze der
   `CLAUDE.md`-Vorgabe (4–5 Dateien, ±250 LoC gesamt), aber innerhalb. Kein Nachfragebedarf.

## Side-Effects

- **Geänderte Dateien:** `project.yml`, `Shared/Persistence/ModelContainerFactory.swift`,
  `scripts/sim.sh`, `docs/project/00-entscheidungen.md`; neu: `LooseEndsTests/ModelContainerFactoryTests.swift`.
  Generiert (nicht von Hand, nicht versioniert): `LooseEnds/LooseEnds.entitlements`,
  `LooseEndsWatch/LooseEndsWatch.entitlements`, `LooseEndsWidgets/LooseEndsWidgets.entitlements`,
  `LooseEndsShare/LooseEndsShare.entitlements`, die vier zugehörigen `Info.plist`.
- **Neue Permissions (Info.plist)?** Nein — nur zwei neue, rein informative Schlüssel
  (`LEAppGroup`, `LECloudContainer`), keine neue Nutzerberechtigung.
- **AppStorage-Keys geändert?** Nein.
- **Audio-Dateien hinzugefügt/umbenannt?** Nein.
- **Apple Developer Portal:** ggf. einmalige Registrierung der App-ID/App-Gruppe/iCloud-Container
  `.probe`, falls die automatische Signierung sie nicht selbst anlegt (Schritt 0) — über
  App-Store-Connect-API bzw. Xcode-Konto, nie über einen Befehl an Henning.

## Hinweis: Stufe 3 Pflicht

Diese Änderung berührt vier Pfade aus der Geräteliste in `CLAUDE.md`: `project.yml`,
`*.entitlements` (generiert aus `project.yml`), `*/Info.plist` (dito) und
`Shared/Persistence/ModelContainerFactory.swift`. Stufe 3 (`./scripts/sim.sh device-status`, rein
lesend, plus der in AC-d beschriebene, ausschließlich installierende Gerätebau) ist damit
verpflichtend — genau der Nachweis, den diese Spec selbst als AC-d fordert.

## Definition of Done

- [ ] Schritt 0 (Machbarkeitsbau) durchgeführt, Ergebnis (Erfolg, Container-Anlage oder Prüfbau
      ohne iCloud-Entitlement) im Abschlussbericht benannt
- [ ] AC-a bis AC-f erfüllt, jeder Nachweis-Befehl ausgeführt und seine Ausgabe im Abschlussbericht
      wörtlich zitiert
- [ ] `./scripts/sim.sh unit` grün
- [ ] `./scripts/sim.sh build` + `./scripts/sim.sh launch` (Simulator) grün
- [ ] `docs/project/00-entscheidungen.md` trägt ADR-18
- [ ] Kein manueller Testhinweis an Henning — jede Acceptance Criterion ist automatisiert oder durch
      einen protokollierten Befehl belegt
- [ ] Jeder Commit kompiliert
- [ ] Nach dem Zusammenführen: Hennings Hauptordner nachgezogen und Projekt neu erzeugt
      (`bash ~/.claude/scripts/loose-ends-sync-main.sh`)
- [ ] PR schließt #156 (`Closes #156`)
- [ ] CI grün

## Changelog

- 2026-09-30: Spec aus der Analyse in `docs/context/bundle-id-debug-156.md` geschrieben. Kennung am
  Prüfweg statt an der Debug-Konfiguration (Henning/Claude, 2026-09-30) — DoD-Punkte 1 und 4 des
  Issues sinngemäß umformuliert, mit Begründung und Alternative oben offen benannt.
