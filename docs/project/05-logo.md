# Logo und App-Icon: Plan

> Erstellt: 2026-09-17
> Status: Entschieden am 2026-09-17: Motiv B (Knoten), Petrol, heller Grund. Assets siehe `docs/design/logo/README.md`.

## Ausgangslage

Seit #17 gibt es ein Platzhalter-Icon: violetter Farbverlauf mit weißem Häkchen. Es erfüllt
App Store Connect, sagt aber nichts über die App. Ein Häkchen auf Verlauf ist das Icon jeder
zweiten Aufgaben-App, und der Verlauf widerspricht dem Leitbild "sehr einfarbig" (R3-3, ADR-14).
Die Akzentfarbe der App ist noch nicht gesetzt (`AccentColor` leer, also System-Blau).

## Was das Logo leisten muss

- **Den Namen tragen.** "Loose Ends" sind lose Fäden, Dinge, die noch nicht zu Ende gebracht
  sind. Das Motiv soll das zeigen, nicht das Erledigen (kein Häkchen, keine Liste).
- **In Graustufen funktionieren** (ADR-14): eine Form, eine Farbe, kein Verlauf als Träger
  der Aussage.
- **Klein lesbar sein**: 29 pt auf dem Sperrbildschirm, rund maskiert auf der Watch, in der
  Liquid-Glass-Darstellung von iOS 26 mit Licht, Dunkel, getönt und klar.
- **Zur UI passen**: die App nutzt SF Symbols und Systemfarben; das Logo definiert die eine
  Akzentfarbe, die die App danach überall für "tippbar" nutzt.

## Motiv-Richtungen (Henning wählt eine)

| | Idee | Bild | Stärke | Risiko |
|---|------|------|--------|--------|
| A | **Der lose Faden** | Eine Linie läuft ruhig ins Bild und endet frei, mit einer kleinen Schlaufe oder Locke | Wörtlich, ruhig, sehr minimal, einfarbig | Kann bei 29 pt zu dünn wirken; Strichstärke ist alles |
| B | **Der Knoten** | Ein einfacher Überhandknoten aus einer Linie, beide Enden sichtbar | "Loose end, tied up": Versprechen der App in einem Bild | Knoten sind schnell kleinteilig; braucht sehr reduzierte Form |
| C | **Faden wird Linie** | Links ein wirrer, kurzer Faden, der nach rechts in eine gerade Linie übergeht | Erzählt die Verwandlung: Chaos rein, Struktur raus (die KI) | Zwei Zustände in einem kleinen Quadrat, am schwersten sauber zu zeichnen |

Empfehlung: **A** als Hauptmotiv, mit der Locke als eigenständigem Zeichen, das auch als
SF-Symbol-artiges Glyph in der App wiederverwendbar wäre (Kontext-Symbol, leerer Zustand).
B ist die Alternative, wenn A zu leise ist.

## Farbe

Eine Hauptfarbe, die gleichzeitig Akzent der App wird. Vorschlag drei Kandidaten, jeweils auf
Weiß und auf dunklem Grund geprüft:

1. Tiefes Indigo (ruhig, nicht das Standard-Blau von iOS)
2. Warmes Orange-Rot (Faden-Assoziation, aber Rot ist im Farbbudget für Zeitdruck reserviert;
   müsste klar davon abgesetzt sein)
3. Dunkles Petrol

Der Hintergrund des Icons ist einfarbig hell oder dunkel, kein Verlauf; Liquid Glass gibt
die Tiefe von selbst.

## Technische Form (iOS 26 / macOS 26 / watchOS 26)

- **Icon Composer-Format `.icon`**: ein Paket aus `icon.json` plus SVG-Ebenen (Hintergrund,
  Faden). Xcode 26 kompiliert daraus alle Darstellungen: Licht, Dunkel, getönt, klar, Mac
  und Watch. Das Paket ist Textdateien, also im Repo versionierbar und ohne GUI erzeugbar.
- **Ebenen**: Ebene 1 Hintergrundfläche, Ebene 2 der Faden als SVG-Pfad mit fester
  Strichstärke. Zwei Ebenen reichen für Parallaxe und Glas.
- **Fallback**: `AppIcon-1024.png` bleibt für ältere Werkzeuge; die Watch bekommt das Motiv
  ohne Rand, weil sie rund maskiert.
- **Akzentfarbe**: `AccentColor.colorset` bekommt die Logo-Farbe mit Licht- und Dunkelwert.
- **Kein Icon-Text**, kein Schriftzug im Icon. Der Name steht darunter.

## Schritte

| # | Schritt | Wer | Ergebnis |
|---|---------|-----|----------|
| 1 | Motiv-Richtung und Farbe wählen | Henning | "A, Indigo" oder ähnlich |
| 2 | Drei Varianten des gewählten Motivs als SVG, nebeneinander auf einer Seite, jede in 1024, 180, 60 und 29 pt sowie hell, dunkel, getönt, Graustufen | Claude | Vergleichsseite zum Anschauen |
| 3 | Eine Variante wählen, Feinschliff (Strichstärke, Locke, Abstand) | Henning, Claude | Endgültiges SVG |
| 4 | `.icon`-Paket erzeugen, Fallback-PNGs rendern, Watch-Icon, `AccentColor` setzen | Claude | PR mit Assets, Build in CI |
| 5 | Prüfen auf Gerät: Home-Screen hell und dunkel, getönt, Watch, Mac-Dock; TestFlight-Build | Henning mit lokaler Claude-Instanz | Freigabe |
| 6 | Marketing: 1024-PNG für App Store Connect, Vorschau-Screens später | Claude | Ablage in `docs/marketing/` |

Aufwand: Schritte 2 bis 4 sind je ein kurzer Schnitt; Schritt 5 braucht ein Gerät.

## Entscheidung

Henning, 2026-09-17, auf der Design-Leinwand: **Motiv B (der Knoten) in Petrol**, heller Grund.
Schritte 2 bis 4 sind damit erledigt (PNG-Fallbacks und Akzentfarbe im Projekt); Schritt 5,
das Icon-Composer-Paket, läuft auf dem Mac nach `docs/design/logo/README.md`.
