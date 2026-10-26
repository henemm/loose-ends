# Adversary Dialog — 40-icon-composer-paket
Spec: docs/specs/feat-40-icon-composer-paket.md
Datum: 2026-10-26 10:01

## Checkliste
- [x] **AC-1:** `LooseEnds/Resources/AppIcon.icon` liegt im Repo; `icon.json` ist lesbares JSON, nennt eine Gruppe mit der Ebene `layer-thread.svg` (Glas, Specular, neutraler Schatten) und einen hellen Fill `#F4F3EE`; alle genannten Bilddateien existieren.
- [x] **AC-2:** `./scripts/sim.sh build` (iOS) und der Mac-Bau (`./scripts/sim.sh mac-build`) laufen durch; `actool` meldet keinen Fehler, `ASSETCATALOG_COMPILER_APPICON_NAME` bleibt `AppIcon`.
- [x] **AC-3:** Hell, Dunkel und Getönt sind im gebauten Paket belegt: die `Assets.car` der gebauten App enthält die Darstellungen, und ein aus ihr gerendertes Bild je Darstellung (`ictool` oder Auslese der `Assets.car`) zeigt im Dunkel den dunklen Grund mit Faden `#5FC4C9`. Die Bilder werden geöffnet und beschrieben, nicht gezählt.
- [x] **AC-4:** Im iOS-27-Simulator zeigt der Home-Screen das neue Icon (hell) mit sichtbarer Tiefe; Screenshot als Beleg über `./scripts/sim.sh test-proof` bzw. `screenshot`.
- [x] **AC-5:** Das Watch-Target baut mit demselben Paket (keine Kopie der SVGs, Leinwand 1088 vom System angepasst); `watch`-Bau läuft durch.
- [x] **AC-6:** `scripts/test_app_icon_package.py` läuft in der CI im Schritt „Script tests“ und prüft: Manifest lesbar, Bilder vorhanden, Hell- und Dunkel-SVG unterscheiden sich nur in der Strichfarbe, Fill-Spezialisierung für Dunkel vorhanden.
- [ ] **AC-7:** Das Archiv des TestFlight-Laufs (Prüfschritt „Verify the archive“) findet das Icon weiter; der Probe-Bau (`BUNDLE_ID_SUFFIX`) baut.
- [x] **AC-8:** README und `05-logo.md` nennen den Ist-Stand (eine Gruppe mit Fill, PNG-Sätze ungenutzt) statt „zwei Ebenen / Icon Composer per GUI“.
- [ ] **AC-9 (Gerät, Stufe 3):** Home-Screen in Hell, Dunkel, Getönt und Klar, Watch und Mac-Dock im selben TestFlight-Durchgang wie #176. Gilt, weil `project.yml` auf der Geräteliste steht; nichts auf Hennings Geräten, bevor er „jetzt ist ein Test möglich“ schreibt.

## Dialog

### Runde 1
**Adversary:** Ich bezweifle jede Behauptung. (a) Ist icon.json gueltig und passt zu AC-1? (b) Unterscheiden sich die SVG wirklich nur in der Strichfarbe? (c) Hat der Test nach dem RED-Umbau noch Zaehne? (d) Enthalten die Assets.car-Listings Hell/Dunkel/Tintable, und sind die Render-Bilder wirklich dunkel mit hellem Faden? (e) Bleibt generate sauber, nutzt die Watch dasselbe Paket?
**Implementierer:** (a) `python3 scripts/test_app_icon_package.py` laeuft: 8 Tests OK. icon.json: eine Gruppe, Ebene layer-thread mit glass true, specular true, shadow neutral 0.5; Fill hell srgb 0.95686,0.95294,0.93333 = #F4F3EE.
Code reference: LooseEnds/Resources/AppIcon.icon/icon.json:1
(b) `diff` der beiden SVG: Unterschiede sind ausschliesslich `#0F6E73` gegen `#5FC4C9` (Pfade, Maske, Breiten identisch); der Test hebt das auf Byte-Gleichheit (hell == docs/design/logo/layer-thread.svg, dunkel == Farbtausch der Quelle).
Code reference: LooseEnds/Resources/AppIcon.icon/Assets/layer-thread.svg:1
Code reference: LooseEnds/Resources/AppIcon.icon/Assets/layer-thread-dark.svg:1
(c) Der Test ist gegenueber der schlichten Form nicht geschwaecht, sondern strenger: er verlangt die Spezialisierungsform (Eintrag ohne appearance = hell, appearance dark = dunkel), prueft den hellen Fill-Wert, den dunklen Eigengrund, das dunkle Bild und verbietet die schlichten Schluessel `fill`/`image-name`, die laut render-Dark-testform-ignoriert.png (Dunkel rendert wie Hell: Faden dunkelpetrol auf Grau-Schwarz) Dunkel lautlos abschalten. Das deckt AC-6 (Manifest, Bilder, SVG nur Strichfarbe, Dunkel-Fill-Spezialisierung) ab.
Code reference: scripts/test_app_icon_package.py:59
(d) assets-car-ios-watch.txt und assets-car-mac.txt: IconGroup und IconImageStack in Dark, Light, ISAppearanceTintable (Mac: DarkAqua/Aqua/Tintable), Farben Color-2 (#F4F3EE) und Color-3 (0.063,0.094,0.098 = dunkler Grund), Vektoren layer-thread und layer-thread-dark. render-Dark.png geoeffnet: heller Teal-Faden mit Glasschimmer und Kantenlicht auf sehr dunklem Petrol-Schwarz, Maske an der Kreuzung erhalten. render-Default.png: dunkler Petrol-Faden auf hellem Grund mit Schatten und Kante. render-Dark-testform-ignoriert.png: Gegenbeispiel, Faden dunkelpetrol auf Grau-Schwarz.
(e) project.yml: nur AppIcon.icon in der includes-Liste der Watch-Resources, ASSETCATALOG_COMPILER_APPICON_NAME bleibt AppIcon (Zeile 119, vom Test geprueft). Die erzeugte Projektdatei kennt AppIcon.icon (wrapper.icon, zwei Resources-Phasen: App und Watch), ist nicht versioniert; die Statusabfrage zeigt keine unerwartete Aenderung an versionierten Dateien. Die Watch-Assets.car enthaelt AppIcon_Assets/layer-thread (keine Kopie).
Code reference: project.yml:131
**Adversary (Gegenprobe):** Build-Logs: `grep -c "error:"` build-ios.txt und build-mac.txt = 0, beide enden mit Build Succeeded. Die Zeile `::error title=board` in test-green-output.txt stammt aus einem erwarteten Negativtest von board.py (Usage-Meldung), nicht vom Bau; 254 Tests OK. Akzeptiert.

### Runde 2
**Adversary:** Zweiter Angriff auf Luecken. (1) Prueft der Test glass/specular/shadow aus AC-1? (2) Watch zeigt in der Assets.car nur Light; Fehler? (3) AC-4 nur einfacher Screenshot. (4) AC-7 Probe-Bau nicht gebaut. (5) AC-8 Wortlaut. (6) CI-Xcode 27.0 gegen lokal 27.1.
**Implementierer:** (1) Nein, der Test prueft Glas/Specular/Schatten nicht; deren Wirkung belegt das Bild (Glanz, Kantenlicht, Schatten in render-Default.png und home-hell.png). Luecke LOW (F001). (2) Die Watch kennt nur eine Darstellung, das System rundet an; AC-5 verlangt Bau mit demselben Paket ohne Kopie, belegt durch Watch-Assets.car (Icon Image Idiom watch, 1024, Vektor aus dem gemeinsamen Paket) und render-watch-Default.png. Kein Verstoss. (3) home-hell.png geoeffnet: iOS-27-Home-Screen; unten links "Loose Ends" mit neuem Icon, heller Grund, Teal-Faden, sichtbarer Schatten und Kantenglanz, im Stil wie Erinnerungen und Dateien. Spec erlaubt "bzw. screenshot": ausreichend fuer AC-4. (4) AC-7: Der Icon-Name AppIcon ist unveraendert und die Assets.car enthaelt AppIcon als Icon Image 1024; der Probe-Bau (BUNDLE_ID_SUFFIX) ist nicht gebaut und nur ueber Geraet/Mac-Installation pruefbar. Ehrlich offen (F002, MEDIUM). (5) AC-8: "zwei Ebenen" kommt nur noch als Berichtigung vor ("die frueher geplanten zwei Ebenen braucht es nicht"); README hat keinen "Naechster Schritt auf dem Mac" mehr (vom Test geprueft), ictool nur als Kommandozeilenpruefung. Dunkelwert #101819 in 05-logo.md stimmt mit icon.json (16,24,25) ueberein.
Code reference: docs/project/05-logo.md:51
(6) Xcode 27.0 in der CI: im Material nicht belegbar, offen bis zur CI (Risiko 3 der Spec); kein Befund gegen die Umsetzung.
**Adversary (Schluss):** Die Behauptungen halten. Offen: AC-9 (Geraet, Stufe 3) bis Hennings Rueckmeldung; AC-7 zweiter Teilsatz ohne Beleg.

## Findings

Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: scripts/test_app_icon_package.py:49
  Description: Der Test prueft Gruppenanzahl und Bilder, aber nicht glass, specular und shadow.
  Spec requirement: AC-1 - Ebene mit Glas, Specular, neutralem Schatten
  Conflict: Entfernt jemand diese Schluessel, bleibt der Test gruen; nur das Bild wuerde es zeigen.
  Remediation: assertTrue auf glass, specular und shadow.kind == neutral ergaenzen.

Finding:
  ID: F002
  Severity: MEDIUM
  Category: spec_violation
  Code reference: project.yml:119
  Description: Der Probe-Bau (BUNDLE_ID_SUFFIX) wurde nicht gebaut; der Icon-Name AppIcon ist unveraendert.
  Spec requirement: AC-7 - der Probe-Bau baut
  Conflict: Teilsatz ohne Beleg; nur ueber Geraet/Mac-Installation (Hennings Wort) pruefbar.
  Remediation: Im TestFlight-Durchgang (AC-9) mitpruefen; bis dahin als offen benennen.

## Confirmations

Confirmation:
  AC: AC-1
  Code reference: LooseEnds/Resources/AppIcon.icon/icon.json:1
  Evidence: gueltiges JSON, eine Gruppe, layer-thread, glass, specular, neutraler Schatten, Fill #F4F3EE; beide SVG existieren.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: project.yml:119
  Evidence: build-ios.txt und build-mac.txt ohne error:, Build Succeeded; Name bleibt AppIcon.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: LooseEnds/Resources/AppIcon.icon/Assets/layer-thread-dark.svg:1
  Evidence: Assets.car-Listings mit Dark, Light, Tintable; render-Dark.png zeigt hellen Teal-Faden auf dunklem Grund.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: LooseEnds/Resources/AppIcon.icon/Assets/layer-thread.svg:1
  Evidence: home-hell.png zeigt das neue Icon mit Tiefe im iOS-27-Home-Screen (einfacher Screenshot, laut Spec zulaessig).
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: project.yml:131
  Evidence: Watch-Resources includes AppIcon.icon, keine Kopie; Watch-Assets.car enthaelt layer-thread; Bau gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: scripts/test_app_icon_package.py:83
  Evidence: 8 Tests gruen; Byte-Gleichheit hell/Quelle, dunkel = Farbtausch; Dunkel-Fill und -Bild geprueft; CI-Schritt Script tests nutzt discover test_*.py (ci.yml:33).
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: docs/project/05-logo.md:51
  Evidence: Ist-Stand "eine Gruppe mit Fill, PNG-Saetze ungenutzt"; README ohne GUI-Schritt.
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: AMBIGUOUS

## Geprüfte Dateien

- sha256:e1459401ec3c602fe10e34fbf1a0f5e70373b644455e28c0c3be314b88feb73d  LooseEnds/Resources/AppIcon.icon/Assets/layer-thread-dark.svg
- sha256:4424cd212f081276cd8de28e8b238fe2fa8efc401db9571222856a1c675d6359  LooseEnds/Resources/AppIcon.icon/Assets/layer-thread.svg
- sha256:55f010cad6d20450ac37bd47f0be1bde9245776b505e067f544039d58a08c009  LooseEnds/Resources/AppIcon.icon/icon.json
- sha256:3005ffb8aab70d52d352b05fd7d4be8118b93ad1973430bd587928ab9895bfa8  docs/project/05-logo.md
- sha256:020008eb656d256d56f8414dc3db873a12b03514c9aef9e51a1acc67333d683b  project.yml
- sha256:b68b3a7682a18ddc5a7ad61d2b05bdfce34ca097d09085d4f88ce29bf297d93f  scripts/test_app_icon_package.py

## Prüfbasis

- base: c4790a534e0bd827548a4991a4d0e3163560c7bb
- blob:3f4a70f573fea3a180cd3f596d17a01522aaffc9  LooseEnds/Resources/AppIcon.icon/Assets/layer-thread-dark.svg
- blob:73797718a71bca9de33227ec07737f3584b75620  LooseEnds/Resources/AppIcon.icon/Assets/layer-thread.svg
- blob:7769598abf3f740f6b831331b2f829998fca741b  LooseEnds/Resources/AppIcon.icon/icon.json
- blob:5def523cbfeb2dce612a9fee0811f5fc01411272  docs/project/05-logo.md
- blob:3c145839ac920323bdb63bebd61ad63b1ebdffbe  project.yml
- blob:61c0feb291a65538ba7303cd13304093f9ff2680  scripts/test_app_icon_package.py
