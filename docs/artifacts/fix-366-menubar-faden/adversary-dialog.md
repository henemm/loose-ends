# Adversary Dialog — fix-366-menubar-faden
Spec: docs/specs/fix-366-menubar-faden.md
Datum: 2026-10-12 15:42

## Checkliste
- [x] **AC-1 Gemeinsame Formel:** Given `ThreadShape` und das Raster / When beide den Knoten bilden / Then stammen die Rohpunkte aus derselben Funktion `curvePoints(form:)`; `ThreadShapeTests` bleiben unverändert grün.
- [x] **AC-2 Template:** Given der Mac-Prüfbau / When die Menüleiste gezeigt wird / Then ist das Symbol ein Template-Bild (`isTemplate = true`, 18 pt, 1x und 2x) und nimmt die Systemtönung an: schwarz in der hellen, weiß in der dunklen Menüleiste. Beleg: Screenshot beider Modi.
- [x] **AC-3 Erkennbar:** Given die Menüleiste in Originalgröße (1x) und Retina (2x) / When man den Knoten ansieht / Then ist die Kreuzung als Knoten mit losem Faden erkennbar. Läuft die Lücke bei 1x zu, gilt Rückfall B (kräftigerer Faden ohne Lücke) ohne Rückfrage, dokumentiert mit Screenshot.
- [x] **AC-4 Raster:** Given `MenuBarThreadRaster.cgImage(scale:)` / When es bei 1x und 2x läuft / Then ist das Bild 18 bzw. 36 px hoch, nicht leer, nur schwarz auf transparent, und die Kreuzungslücke ist bei 2x transparent (Simulator-Tests).
- [x] **AC-5 Panel unverändert:** Given das neue Symbol / When man es anklickt / Then öffnet dasselbe Panel und erfasst wie bisher (Text, Mikrofon, Return speichert, Panel schließt); `menuBarOpenApp` und `menuBarQuit` funktionieren.
- [x] **AC-6 Nichts sonst:** Der Diff berührt nur die vier genannten Dateien; iOS-, Watch- und Widget-Verhalten ändern sich nicht; alle bestehenden Tests grün; der iOS-Simulatorbau ist grün.

## Dialog

### Runde 1
**Adversary:** Befunde A–G (Testdatei nur Übersetzungsfix, Formel unverändert, Isolation ok; Lückentest zu schwach: schlug erst bei ~3-facher Strichstärke an; Spec sagt „zwischen den Armen“, Test prüft Schleifeninneres; `#if os(macOS)`-Teil in keinem Simulatorlauf übersetzt; `sim.sh build` ohne eigenen Beleg).
**Implementierer:** Lückentest verschärft: alle Pixel im Radius 3,5 px um die Schleifenmitte müssen bei 2x transparent sein (freie Fläche rechnerisch 4,2 px); `sim-unit MenuBarThreadImageTests` grün. Mac-Übersetzung: `xcodebuild build -destination generic/platform=macOS CODE_SIGNING_ALLOWED=NO` erfolgreich (Entwickler-Lauf), iOS `sim.sh build` erfolgreich.

### Runde 2
**Adversary:** Gegenprobe: `swiftc -typecheck -swift-version 6 -target arm64-apple-macos27.0` für MenuBarThreadImage.swift und Thread.swift ohne Fehler; Geometrie in Python nachgerechnet (Schleifenmitte 106,4 Einheiten von der Kurve, halbe Strichbreite 36). AC-1 AKZEPTIERT: Code reference: LooseEnds/Views/Thread.swift:16. AC-4 AKZEPTIERT: Code reference: LooseEnds/Mac/MenuBarThreadImage.swift:36. AC-6 AKZEPTIERT (vier Dateien). AC-2 OFFEN: Code reference: LooseEnds/Mac/MenuBarThreadImage.swift:63 (isTemplate), LooseEnds/App/LooseEndsApp.swift:80. AC-3 OFFEN (Mac-Prüfbau, Rückfall-Konstante lineWidth). AC-5 OFFEN (Mac-Prüfbau).
**Implementierer:** Henning hat den Mac-Prüfbau erst vertagt, dann mit „jetzt ist ein Test möglich“ freigegeben. Belege (Mac-Prüfbau „LE Prüfbau“): crop-hell.png, crop-dunkel.png (Faden als offener Knoten, wie die Nachbarsymbole weiß getönt), 1x-Raster als ASCII (Schleife bleibt offen, Innenöffnung ca. 3x4 px, Variante A bleibt), crop-panel.png (Panel öffnet auf Klick, „Ich höre …“), crop-fokus.png, crop-gespeichert.png (Text im Feld, Return schließt das Panel), Datenbankabfrage des Prüfbaus: neueste Aufgabe „Faden Test“.

### Schlussrunde
**Adversary:** AC-5 AKZEPTIERT: Code reference: LooseEnds/App/LooseEndsApp.swift:80. AC-2 AKZEPTIERT mit Vorbehalt: Code reference: LooseEnds/Mac/MenuBarThreadImage.swift:63 — der Schwarzfall auf heller Leiste ist nicht direkt beobachtet (Hennings Schreibtischbild ist dynamisch und nicht rückstellbar, deshalb nicht umgestellt), sondern aus isTemplate, rasterIsBlackOnTransparent und der Systemtönung abgeleitet. AC-3 AKZEPTIERT: Code reference: LooseEnds/Mac/MenuBarThreadImage.swift:11. AC-1 AKZEPTIERT: Code reference: LooseEnds/Views/Thread.swift:16. AC-4, AC-6 AKZEPTIERT. menuBarOpenApp/menuBarQuit nicht einzeln geprüft (Code unverändert).
**Implementierer:** Vorbehalte kommen in den Abschlussbericht.



### Belegstellen
Code reference: LooseEnds/Views/Thread.swift:16
Code reference: LooseEnds/Mac/MenuBarThreadImage.swift:63
Code reference: LooseEnds/App/LooseEndsApp.swift:80

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict
**VERIFIED**

Vorbehalt: Schwarzfall von AC-2 nicht direkt beobachtet, aus Template plus Systemtönung abgeleitet; menuBarOpenApp/menuBarQuit nicht einzeln geprüft.

## Geprüfte Dateien

- sha256:eb0c16d4a24b970ad6cf67da5fbd0e02fa553309df3ce4a916707cab33151806  LooseEnds/App/LooseEndsApp.swift
- sha256:99e00b4b34451f6487066b743ae6bb1b5941e7832f56a125b394b2a4e4959811  LooseEnds/Mac/MenuBarThreadImage.swift
- sha256:da29bce4c1ed29c368977d6097c58beb6048a4a4e5a56141e2d519801500963a  LooseEnds/Views/Thread.swift

## Prüfbasis

- base: c90de26cb76636321315808675dce796d8949756
- blob:17f463e5ca0cd2a5c2b55163a54bff183a46ba68  LooseEnds/App/LooseEndsApp.swift
- blob:9c0cf5e3644b7703d39d00b1b5cb3c4b57b997f4  LooseEnds/Mac/MenuBarThreadImage.swift
- blob:7f75c0eb446e1d162cd5969ebc05c6f40ef66487  LooseEnds/Views/Thread.swift

## Geprüfte Dateien

- sha256:eb0c16d4a24b970ad6cf67da5fbd0e02fa553309df3ce4a916707cab33151806  LooseEnds/App/LooseEndsApp.swift
- sha256:99e00b4b34451f6487066b743ae6bb1b5941e7832f56a125b394b2a4e4959811  LooseEnds/Mac/MenuBarThreadImage.swift
- sha256:da29bce4c1ed29c368977d6097c58beb6048a4a4e5a56141e2d519801500963a  LooseEnds/Views/Thread.swift

## Prüfbasis

- base: c90de26cb76636321315808675dce796d8949756
- blob:17f463e5ca0cd2a5c2b55163a54bff183a46ba68  LooseEnds/App/LooseEndsApp.swift
- blob:9c0cf5e3644b7703d39d00b1b5cb3c4b57b997f4  LooseEnds/Mac/MenuBarThreadImage.swift
- blob:7f75c0eb446e1d162cd5969ebc05c6f40ef66487  LooseEnds/Views/Thread.swift
