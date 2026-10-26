# Logo und App-Icon

Motiv B aus `docs/project/05-logo.md`: ein Faden mit zwei freien Enden, dessen Schlaufe sich
einmal kreuzt. Farbe Petrol `#0F6E73` (hell) und `#5FC4C9` (dunkel), Grund `#F4F3EE`.
Die Kurve ist eine Trochoide (`x = a·t − b·sin t`, `y = −b·cos t` mit a = 90, b = 230 auf
einem 1024-Raster, t von −3,5 bis 3,0), Strichstärke 72, runde Enden. `generate.py.txt`
erzeugt daraus die SVGs; umbenennen nach `.py` und mit Python 3 ausführen.

| Datei | Zweck |
|-------|-------|
| `loose-ends-icon.svg` | Das ganze Icon, heller Grund, für Marketing und als Vorlage |
| `layer-background.svg` | Der Grund als Fläche; im Paket ersetzt durch einen Fill, ungenutzt |
| `layer-thread.svg` | Der Faden, transparent; Quelle der beiden Faden-Bilder im Paket |

## Was im Projekt liegt

- `LooseEnds/Resources/AppIcon.icon`: das Icon, siehe unten.
- `LooseEnds/Resources/Assets.xcassets/AppIcon.appiconset` (ungenutzt seit #40): iOS hell (deckend, ohne Alpha,
  so verlangt es App Store Connect), dunkel und getönt (transparent, das System legt seinen
  Grund darunter), Mac hell.
- `LooseEndsWatch/Assets.xcassets/AppIcon.appiconset` (ungenutzt seit #40): hell, das System maskiert rund.
- `AccentColor.colorset`: Petrol hell und dunkel; damit ist "tippbar" in der App dieselbe
  Farbe wie das Logo (ADR-14).

## Das Icon-Composer-Paket (#40)

`LooseEnds/Resources/AppIcon.icon` ist das App-Icon für iPhone, iPad, Mac und Watch. Es ist von Hand
geschrieben, nicht mit der Icon-Composer-Oberfläche, und besteht aus Textdateien:

- `icon.json`: der Grund ist ein Fill, keine Ebene: `#F4F3EE` hell, `#101819` (Petrol-Schwarz) dunkel.
  Darüber **eine Gruppe** mit der Faden-Ebene: Glas, Specular, neutraler Schatten.
- `Assets/layer-thread.svg` (Faden `#0F6E73`) und `Assets/layer-thread-dark.svg` (Faden `#5FC4C9`):
  beide gleich `layer-thread.svg` hier, nur die Strichfarbe unterscheidet sich; die Maske am Kreuzungspunkt bleibt.
- Hell und Dunkel stehen beide in `fill-specializations` und `image-name-specializations` (ein Eintrag ohne
  `appearance` für Hell, einer mit `"appearance": "dark"`). Steht daneben ein einfaches `fill` oder `image-name`,
  nimmt `actool` nur dieses und ignoriert die Dunkel-Angabe (geprüft mit `assetutil --info`, 2026-10-26).
- Getönt und Klar rechnet das System selbst aus dem Paket.
- Das Watch-Target nimmt dasselbe Paket als Quelle (`project.yml`), keine Kopie.

Die PNG-Sätze in `Assets.xcassets/AppIcon.appiconset` (App und Watch) liegen noch im Projekt, sind aber
ungenutzt: Liegt ein `AppIcon.icon` daneben, gewinnt das Paket. `layer-background.svg` braucht das Paket nicht.

Prüfen ohne Gerät: `ictool` aus `Icon Composer.app/Contents/Executables/` rendert das Paket je Darstellung
(`--export-image --platform iOS --rendition Default|Dark|TintedLight …`).
