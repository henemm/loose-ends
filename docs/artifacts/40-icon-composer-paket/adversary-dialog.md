# Adversary Dialog — 40-icon-composer-paket
Spec: docs/specs/feat-40-icon-composer-paket.md
Datum: 2026-10-26 (Neufassung: Spec hat nur AC-1..AC-6 und AC-8; AC-7/AC-9 sind Nachgelagert N-1/N-2, keine Abnahmepunkte)

## Checkliste
- [x] **AC-1:** `LooseEnds/Resources/AppIcon.icon` liegt im Repo; `icon.json` ist lesbares JSON, nennt eine Gruppe mit der Ebene `layer-thread.svg` (Glas, Specular, neutraler Schatten) und einen hellen Fill `#F4F3EE`; alle genannten Bilddateien existieren.
- [x] **AC-2:** `./scripts/sim.sh build` (iOS) und der Mac-Bau (`./scripts/sim.sh mac-build`) laufen durch; `actool` meldet keinen Fehler, `ASSETCATALOG_COMPILER_APPICON_NAME` bleibt `AppIcon`.
- [x] **AC-3:** Hell, Dunkel und Getönt sind im gebauten Paket belegt: die `Assets.car` der gebauten App enthält die Darstellungen, und ein aus ihr gerendertes Bild je Darstellung (`ictool` oder Auslese der `Assets.car`) zeigt im Dunkel den dunklen Grund mit Faden `#5FC4C9`. Die Bilder werden geöffnet und beschrieben, nicht gezählt.
- [x] **AC-4:** Im iOS-27-Simulator zeigt der Home-Screen das neue Icon (hell) mit sichtbarer Tiefe; Screenshot als Beleg über `./scripts/sim.sh test-proof` bzw. `screenshot`.
- [x] **AC-5:** Das Watch-Target baut mit demselben Paket (keine Kopie der SVGs, Leinwand 1088 vom System angepasst); `watch`-Bau läuft durch.
- [x] **AC-6:** `scripts/test_app_icon_package.py` läuft in der CI im Schritt „Script tests“ und prüft: Manifest lesbar, Bilder vorhanden, Hell- und Dunkel-SVG unterscheiden sich nur in der Strichfarbe, Fill-Spezialisierung für Dunkel vorhanden.
- [x] **AC-8:** README und `05-logo.md` nennen den Ist-Stand (eine Gruppe mit Fill, PNG-Sätze ungenutzt) statt „zwei Ebenen / Icon Composer per GUI“.

## Dialog

### Runde 1
**Adversary:** Ich vertraue dem alten Dialog nicht und prüfe selbst.
- AC-1: `python3 scripts/test_app_icon_package.py` läuft: 9 Tests, OK. icon.json gelesen: `fill-specializations` hell `srgb:0.95686,0.95294,0.93333` (= #F4F3EE), dunkel `0.06275,0.09412,0.09804` (= #101819); eine Gruppe, Ebene `layer-thread` mit `glass: true`, `specular: true`, Schatten `neutral` 0.5; Bildnamen `layer-thread.svg` und per `appearance: dark` `layer-thread-dark.svg`; beide Dateien liegen in `AppIcon.icon/Assets/`. Ich habe beide SVGs gelesen: Pfade identisch, Strichfarbe hell `#0F6E73`, dunkel `#5FC4C9` (Diff beschränkt sich auf die Farbe). Code reference: LooseEnds/Resources/AppIcon.icon/icon.json:1, .../Assets/layer-thread.svg:1, .../Assets/layer-thread-dark.svg:1.
- AC-2: build-ios.txt endet mit „Build Succeeded“, Ziele LooseEnds, Watch, Widgets, Share, WatchWidgets; build-mac.txt Zeile 252 „Build Succeeded“. `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon` steht unverändert in project.yml:119. Code reference: project.yml:119.
- AC-3: assets-car-ios-watch.txt und assets-car-mac.txt (Auslese der gebauten Assets.car) enthalten IconImageStack/IconGroup für UIAppearanceLight, UIAppearanceDark und ISAppearanceTintable (iOS) bzw. Aqua, DarkAqua, Tintable (Mac), Vektoren `layer-thread` und `layer-thread-dark`, Farben Color-2 (#F4F3EE) und Color-3 (#101819). Ich habe render-Default.png geöffnet: helles Off-White-Quadrat mit Rundung, dunkelgrüner Faden in einer Schlaufe, erkennbarer Schatten und Glasrand. render-Dark.png: fast schwarzer Grund (#101819-Ton), Faden hell türkis (Glas lässt ihn etwas gedämpft wirken, passt zu #5FC4C9), Glaskante sichtbar. Dunkel unterscheidet sich eindeutig von Hell. Einwand: Der Dunkel-Faden ist optisch gedämpfter als der Hexwert; das ist Glaswirkung des Systems, kein Fehler im Paket. Code reference: docs/artifacts/40-icon-composer-paket/assets-car-ios-watch.txt:1.
- AC-4: home-hell.png geöffnet: iOS-Home-Screen mit Hintergrundbild, unten links „Loose Ends“ mit hellem Icon, grünblauer Schlaufe und sichtbarem Glasrand und Schatten; die Nachbarn („LE Labor“ usw.) zeigen dagegen das Platzhaltergitter, das neue Icon ist also wirklich das Paket. Tiefe sichtbar, wenn auch klein.
- AC-5: Beleg für Watch gefunden: build-ios.txt baut `LooseEndsWatch` mit „Generate Asset Symbols“, „Emplaced .../Debug-watchsimulator/LooseEndsWatch.app/Assets.car“, „Validate Embedded Binary LooseEndsWatch.app“, Build Succeeded. assets-car-ios-watch.txt zeigt Assets.car im Watch-Bundle mit Idiom `watch`, Vektor `AppIcon_Assets/layer-thread` aus demselben Paket. project.yml bindet `AppIcon.icon` aus `LooseEnds/Resources` ein, keine SVG-Kopie. render-watch-Default.png geöffnet: runder heller Grund, gleiche Schlaufe, Faden mittig, nicht abgeschnitten. Eigener separater `watch`-Aufruf ist nicht abgelegt, der eingebettete Watch-Bau im iOS-Lauf deckt ihn jedoch mit ab. Code reference: project.yml:131.
- AC-6: Der Schritt „Script tests“ in ci.yml ruft `unittest discover -s scripts -p 'test_*.py'` auf; die Datei passt auf das Muster, läuft lokal grün (9 Tests). Code reference: scripts/test_app_icon_package.py:1, .github/workflows/ci.yml:29. Ich habe nicht geprüft, ob die Tests auch rot werden, wenn ein Strichfarbwert abweicht, sondern verlasse mich auf test-red-output.txt (Rotlauf vor dem Paket).
- AC-8: README.md (Zeilen 12, 18, 21, 25-41) und 05-logo.md (Zeilen 51-59) nennen „eine Gruppe mit Fill“, „PNG-Sätze ungenutzt“, „von Hand geschrieben, ohne Icon-Composer-Oberfläche“. Kein „zwei Ebenen“ mehr als Ist-Stand. Code reference: docs/design/logo/README.md:25, docs/project/05-logo.md:51.
**Implementierer:** Keine Änderung nötig; Belege liegen vor.

### Runde 2
**Adversary:** Gegenproben. (a) Greifen die ungenutzten PNG-Sätze doch? Die Assets.car zeigt nur Paket-Renditionen für `AppIcon`; die iOS-Liste enthält zusätzlich das Legacy-`AppIcon60x60@2x.png`, das actool für ältere Systeme ableitet, harmlos. (b) Stammt die Mac-Auslese vom Paket? Ja: Vektoren und drei Darstellungen. (c) Ist der Test nur Existenzprüfung? Er prüft Strichfarben-Diff und Fill-Spezialisierung, das ist Nutzen und nicht bloße Existenz. (d) Dunkel-Testform: render-Dark-testform-ignoriert.png ist ein Probelauf, der ausdrücklich als ignoriert benannt ist; kein Beleg wird darauf gestützt. (e) Watch hat keine Dunkel-/Getönt-Darstellung, passt zu `supported-platforms.circles = watchOS`; die Spec verlangt es dort nicht. (f) Getönt und Klar: render-TintedDark/-Light und render-ClearLight liegen vor, AC-3 verlangt nur Hell, Dunkel, Getönt im Paket; die Car-Listing belegt das. N-1 und N-2 (Archiv-Prüfschritt, Gerät) sind laut Spec nachgelagert und werden hier nicht gewertet. Keine Befunde, nur Hinweis: Die Rendergrundlage ist `ictool`/Xcode 27.1 aus dem Spike, die CI pinnt 27.0 (Spec-Risiko 3); das beweist erst die CI und gehört nicht zu den ACs.
**Implementierer:** Hinweis zur Kenntnis genommen.

Confirmation:
  AC: AC-1
  Code reference: LooseEnds/Resources/AppIcon.icon/icon.json:1
  Code reference: LooseEnds/Resources/AppIcon.icon/Assets/layer-thread.svg:1
  Code reference: LooseEnds/Resources/AppIcon.icon/Assets/layer-thread-dark.svg:1
  Evidence: icon.json: eine Gruppe, Glas/Specular/neutraler Schatten, Fill #F4F3EE (dunkel #101819); SVGs unterscheiden sich nur in der Strichfarbe.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: project.yml:119
  Evidence: build-ios.txt und build-mac.txt enden mit Build Succeeded; ASSETCATALOG_COMPILER_APPICON_NAME bleibt AppIcon.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: LooseEnds/Resources/AppIcon.icon/icon.json:1
  Evidence: Assets.car-Auslesen enthalten Hell, Dunkel, Getönt; render-Default.png und render-Dark.png geöffnet und beschrieben (dunkler Grund, türkiser Faden).
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: project.yml:119
  Evidence: home-hell.png zeigt das neue Icon mit Glasrand und Schatten.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: project.yml:134
  Evidence: Watch-Bau im iOS-Lauf, Watch-Assets.car mit demselben Paket, keine SVG-Kopie.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: scripts/test_app_icon_package.py:1
  Evidence: 9 Tests grün; CI-Schritt Script tests nutzt discover test_*.py.
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: docs/project/05-logo.md:51
  Evidence: README und 05-logo.md nennen den Ist-Stand.
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict
VERDICT: VERIFIED
Tests: 9 passed (test_app_icon_package.py), 0 failed, 0 übersprungen; Build iOS (inkl. Watch) und Mac erfolgreich laut Belegen.
Edge cases: geprüft, keine gebrochen. Regressions: keine. Checklist: 7/7 bewiesen.
Hinweis (kein Befund): Watch-Bau nur als eingebetteter Teil des iOS-Baus belegt; Xcode-27.0-Verhalten der CI offen bis zum CI-Lauf.

## Geprüfte Dateien

- sha256:e1459401ec3c602fe10e34fbf1a0f5e70373b644455e28c0c3be314b88feb73d  LooseEnds/Resources/AppIcon.icon/Assets/layer-thread-dark.svg
- sha256:4424cd212f081276cd8de28e8b238fe2fa8efc401db9571222856a1c675d6359  LooseEnds/Resources/AppIcon.icon/Assets/layer-thread.svg
- sha256:55f010cad6d20450ac37bd47f0be1bde9245776b505e067f544039d58a08c009  LooseEnds/Resources/AppIcon.icon/icon.json
- sha256:3005ffb8aab70d52d352b05fd7d4be8118b93ad1973430bd587928ab9895bfa8  docs/project/05-logo.md
- sha256:020008eb656d256d56f8414dc3db873a12b03514c9aef9e51a1acc67333d683b  project.yml
- sha256:b68b3a7682a18ddc5a7ad61d2b05bdfce34ca097d09085d4f88ce29bf297d93f  scripts/test_app_icon_package.py

## Prüfbasis

- base: 2a206699e07b0fe99d7d0ff9965741fcb97c703d
- blob:3f4a70f573fea3a180cd3f596d17a01522aaffc9  LooseEnds/Resources/AppIcon.icon/Assets/layer-thread-dark.svg
- blob:73797718a71bca9de33227ec07737f3584b75620  LooseEnds/Resources/AppIcon.icon/Assets/layer-thread.svg
- blob:7769598abf3f740f6b831331b2f829998fca741b  LooseEnds/Resources/AppIcon.icon/icon.json
- blob:5def523cbfeb2dce612a9fee0811f5fc01411272  docs/project/05-logo.md
- blob:3c145839ac920323bdb63bebd61ad63b1ebdffbe  project.yml
- blob:61c0feb291a65538ba7303cd13304093f9ff2680  scripts/test_app_icon_package.py
