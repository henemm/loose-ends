# Logo und App-Icon

Motiv B aus `docs/project/05-logo.md`: ein Faden mit zwei freien Enden, dessen Schlaufe sich
einmal kreuzt. Farbe Petrol `#0F6E73` (hell) und `#5FC4C9` (dunkel), Grund `#F4F3EE`.
Die Kurve ist eine Trochoide (`x = a·t − b·sin t`, `y = −b·cos t` mit a = 90, b = 230 auf
einem 1024-Raster, t von −3,5 bis 3,0), Strichstärke 72, runde Enden. `generate.py.txt`
erzeugt daraus die SVGs; umbenennen nach `.py` und mit Python 3 ausführen.

| Datei | Zweck |
|-------|-------|
| `loose-ends-icon.svg` | Das ganze Icon, heller Grund, für Marketing und als Vorlage |
| `layer-background.svg` | Ebene 1 für Icon Composer: der Grund |
| `layer-thread.svg` | Ebene 2 für Icon Composer: der Faden, transparent |

## Was im Projekt liegt

- `LooseEnds/Resources/Assets.xcassets/AppIcon.appiconset`: iOS hell (deckend, ohne Alpha,
  so verlangt es App Store Connect), dunkel und getönt (transparent, das System legt seinen
  Grund darunter), Mac hell.
- `LooseEndsWatch/Assets.xcassets/AppIcon.appiconset`: hell, das System maskiert rund.
- `AccentColor.colorset`: Petrol hell und dunkel; damit ist "tippbar" in der App dieselbe
  Farbe wie das Logo (ADR-14).

## Nächster Schritt auf dem Mac: Icon Composer

Xcode 26 bringt Icon Composer mit. Damit wird aus den zwei Ebenen ein `AppIcon.icon`-Paket,
und das System rendert daraus Liquid Glass in Hell, Dunkel, Getönt und Klar, Mac und Watch:

1. Icon Composer öffnen, neues Icon, Name `AppIcon`.
2. `layer-background.svg` als unterste Ebene, `layer-thread.svg` darüber; dem Faden etwas
   Höhe ("Specular", "Shadow") geben, den Grund flach lassen.
3. Als `AppIcon.icon` nach `LooseEnds/Resources/` sichern und in `project.yml` beim Target
   `LooseEnds` unter `sources` eintragen; `ASSETCATALOG_COMPILER_APPICON_NAME` bleibt `AppIcon`.
4. `./scripts/sim.sh build` und Home-Screen in allen vier Darstellungen prüfen.

Bis dahin gelten die PNGs; sie sehen auf iOS 26 korrekt aus, nur ohne Ebenentiefe.
