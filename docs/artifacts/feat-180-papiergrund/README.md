# #180 Schritt 1: Papiergrund und Haarlinien — Simulator-Beleg (Stufe 2)

Quelle: CI-Lauf [37120830321](https://github.com/henemm/loose-ends/actions/runs/37120830321),
Commit `6da8870`, Artefakt `DesignGallery` aus `DesignGalleryTests` (#182), iPhone-Simulator iOS 26.4.

| Bild | Inhalt |
|---|---|
| `galerie/gallery-{light,dark}-1-start.png` | Startseite auf Papiergrund, Haarlinien statt Karten |
| `galerie/gallery-{light,dark}-2-start-scrolled.png` | Startseite gescrollt: kein grauer Abschnittskopf, Navigationsleiste mit Glas |
| `galerie/gallery-{light,dark}-3-list-new.png` | Liste „New“, plain mit Haarlinien |
| `galerie/gallery-{light,dark}-4-detail.png` | Detail: weiße Abschnitte auf Papier (Haarlinien folgen mit Schritt 2) |

Im selben Lauf fiel `CaptureCancelCrashTests` aus: ein Absturz in `SpeechCapture.startEngine`
(Audio-RPC-Zeitüberschreitung), unabhängig von dieser Änderung, siehe #184.

Kein Pfad der Geräteliste berührt.
