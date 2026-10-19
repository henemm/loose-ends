# Adversary-Dialog feat-478-mac-einstellungen-papier

Tests: CI Lauf 39231055167 auf c52a0f5 alle Jobs success (Mac Gallery, UI Smoke, Build, Unit); lokal sim-unit 848 Tests, 0 fehlgeschlagen, 5 Messtests uebersprungen (ci-result.txt). Eigene Testlaeufe nicht ausgefuehrt (Auftrag: nichts auf dem Mac).

### Runde 1

- [x] AC-1: Galeriebilder geoeffnet. Hell: warmer Papiergrund, Zeilen durch feine graue Haarlinien getrennt, keine Karten. Dunkel: dunkler Grund, gleiche Haarlinien. Code reference: LooseEnds/Views/SettingsView.swift:115
- [x] AC-2: Koepfe NOTIFICATIONS, LOOSE ENDS, CALENDAR, MENU BAR, ABOUT als kleine graue Grossbuchstaben (captionHead, SettingsView.swift:157). Hinweise grau 12 pt direkt unter der Zeile (SettingsView.swift:147). iCloud-Zeile oben ohne Ueberschrift (SettingsView.swift:175). Wolkensymbol vorhanden; Status "Waiting for iCloud" im Bild GRAU, nicht Akzent. Code reference: LooseEnds/Views/SettingsView.swift:192 (Akzent nur bei summary.role == .accent, Logik unveraendert; Spec Implementation Details: "SyncStatus liefert Symbol und Rolle schon"). Bewertung: keine Verletzung, da Zustand Waiting laut unveraenderter Rollenlogik grau ist; als LOW F001 vermerkt.
- [x] AC-3: Alle sieben Eintraege im Bild sichtbar (iCloud sync, Reminder time, Evening/Morning-Schalter mit Zeiten, New events in, Open at login, Version 0.1.0 (1)). Test findet alle sieben Kennungen. Code reference: LooseEndsUITests/MacGalleryTests.swift:80. Diff-grep auf accessibilityIdentifier: keine hinzugefuegten/entfernten Zeilen, alle Kennungen unveraendert.
- [x] AC-4: Diff zeigt Bindungen, onChange (opensAtLogin), .task und .sheet nur als Kontext, nicht geaendert; grep nach AppStorage im Code-Diff: kein Treffer (nur Spec-/Kontexttext). Code reference: LooseEnds/Views/SettingsView.swift:70. sim-unit 848/0 fehlgeschlagen, SettingsSmokeTests 1/1 (ci-result.txt).
- [x] AC-5: Schalter als Schalter ohne Kaestchen/Rahmen (Bild hell und dunkel, Teal-Akzent); Zeiten mit Beschriftung links und Zeit rechts; Kalenderzeile "New events in" links, "Loose Ends" und Chevron rechts (ausgegraut, da Kalender nicht bereit, erwartet). Rueckfall nicht noetig. Code reference: LooseEnds/Views/SettingsView.swift:122
- [x] AC-6: window-size.txt: 640 x 752 pt = 640 Breite plus 32 pt Titelleiste zu 720 Inhalt; Test asserted Breite 640 +-2. Titelleiste des Systems mit "Settings" im Bild. Code reference: LooseEnds/App/LooseEndsApp.swift:115. Abweichung vom Ticket in Spec benannt, Abschlussbericht muss sie nennen.
- [x] AC-7: iOS-Zweig: container nutzt Form + .formStyle(.grouped) (SettingsView.swift:130), group nutzt Section mit header/footer (SettingsView.swift:138). iPhone-Bilder vorher/nachher: gleiche Karten, Schalter in Gruen, iCloud-Abschnitt mit Ueberschrift; einziger Unterschied Hinweistext "Loose ends" (vorher laenger, nachher kuerzer) - laut Auftrag Stand-Unterschied main (vor #554), im Diff ist dieser Text unveraendert. Code reference: LooseEnds/Views/SettingsView.swift:130

### Runde 2

Gegenproben:
- Fremdaenderungen: git diff origin/main zeigt testflight.yml und scripts/test_mac_ci_entitlements.py; Gegenprobe git diff 05637ce(merge-base) HEAD fuer .github, scripts, LooseEnds: nur LooseEndsApp.swift und SettingsView.swift. Die beiden Dateien stammen also von einem voraus liegenden main, nicht von diesem Zweig. Kein Befund.
- Dateigrenze: 3 Code-Dateien (SettingsView, LooseEndsApp, MacGalleryTests), +91/-34 plus 35 Test-Zeilen, innerhalb Limit.
- iOS-Kette: Reihenfolge der iOS-Sektionen unveraendert (syncSection steht nach Loose ends, vor Calendar; per #if os(iOS)). Mac: iCloud oben, bewusst laut Spec.
- Mac-Weiche: .environment(defaultMinListRowHeight, 0) und frame minHeight 40-20 = Zeilenhoehe mind. 40 pt, im Bild konsistent ~44 pt.
- .preferredColorScheme(uiTestColorScheme) in der Settings-Szene: LooseEndsApp.swift:116, nur Testschalter, in der Hauptszene bereits vorhanden (Zeile 102), kein Produktverhalten.
- Edge: Hoehe fest 720 pt; Inhalt im Bild passt mit Luft unten; bei grosser Schrift/Lokalisierung koennte abgeschnitten werden (List scrollt, daher kein Verlust). LOW F002.
- Edge: Hinweis ohne Trennlinie darunter: Bild zeigt Haarlinie ueber jedem Kopf, keine zwischen Zeile und Hinweis, wie spezifiziert.
- Galerie-Bild zeigt das Dock im Fensterausschnitt unten (Screenshot-Artefakt, kein Produktbefund).

Findings:
Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: LooseEnds/Views/SettingsView.swift:192
  Description: Status-Wert in Grau im Zustand Waiting for iCloud; Akzent nur bei role == .accent
  Spec requirement: AC-2 - Status als Wert in Akzent mit Wolkensymbol
  Conflict: Im Galeriebild grau; wortwoertlich nicht Akzent, aber Rollenlogik unveraendert und in Spec als schon vorhanden benannt
  Remediation: Im Bericht benennen; Akzent in aktiven Zustaenden nicht im Bild belegt

Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: LooseEnds/App/LooseEndsApp.swift:115
  Description: feste Fensterhoehe 720 pt
  Spec requirement: AC-6 - Breite 640 pt (Hoehe laut Spec nach Inhalt)
  Conflict: Hoehe ist fest statt inhaltsabhaengig (Spec-Abweichung, im Kommentar begruendet: 512 schnitt Zeilen ab; Tafel 640 x 720)
  Remediation: keine noetig

Confirmation: AC-1 SettingsView.swift:115 CONFIRMED
Confirmation: AC-2 SettingsView.swift:192 CONFIRMED (mit F001)
Confirmation: AC-3 MacGalleryTests.swift:80 CONFIRMED
Confirmation: AC-4 SettingsView.swift:70 CONFIRMED
Confirmation: AC-5 SettingsView.swift:122 CONFIRMED
Confirmation: AC-6 LooseEndsApp.swift:115 CONFIRMED
Confirmation: AC-7 SettingsView.swift:130 CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

VERDICT: VERIFIED

## Geprüfte Dateien

- sha256:58e0b66aa7305d3e03936280ed288fa1492a0081c69e73904ca10a45b31d7b37  LooseEnds/App/LooseEndsApp.swift
- sha256:dad03f5609bded4481c92266ef14a7d35cf2443609c676cefbab2758fe3214f6  LooseEnds/Views/SettingsView.swift

## Prüfbasis

- base: 05637cefe407718eec35d7dbf4c920ddc919dfac
- blob:6cfa28ec3257575438525fcc741dd5cd8839c90a  LooseEnds/App/LooseEndsApp.swift
- blob:2ea47b3efe7f87ab4f1e1197642fa55759429f3d  LooseEnds/Views/SettingsView.swift
