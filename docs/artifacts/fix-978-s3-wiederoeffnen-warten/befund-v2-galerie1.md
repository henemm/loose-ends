# #978 S3 v2 — Befund Galerie-Lauf 1 (CI 45464097119, Stand ed75767, 2026-11-24)

Job „Mac Gallery (macOS)“ grün (18:52–19:33 UTC), aber **der v2-Klickweg lief nie**. Beide Klickanhänge (xcresult `MacGallery.xcresult`, exportiert mit `xcresulttool export attachments`):

| Arm | how | click duration | Ergebnis |
|---|---|---|---|
| ⌘W (`reopen-open-app`) | `user: statusItem.click() fallback (frontmost com.apple.finder, empty frame)` | 6,056 s | open |
| Return (`reopen-return`) | `user: statusItem.click() fallback (frontmost com.henning.looseends)` | 5,628 s | open |

**Ursache:** Auf macOS hat ein `XCUIApplication`-Element keinen Rahmen (die Hierarchie im Anhang zeigt `Application, …, pid, title` ohne `{{x,y},{w,h}}`). `XCUIApplication(bundleIdentifier:).frame` ist daher immer leer, und der in der Spec vorgesehene Rückfall „leerer Wurzelrahmen“ greift jedes Mal. Der grüne Lauf belegt deshalb nur den alten Klick (Dauer 5–6 s, wie im Fehlerbild), nicht v2.

**Folge:** AC-1/AC-5 in der jetzigen Form nicht erreichbar; Spec-Korrektur nötig. Die beiden Wiederholungsläufe (45464128332, 45464146424) wurden abgebrochen, weil sie nur den Rückfall gemessen hätten.

**Nächster Ansatz (Hypothese, vor der Spec zu prüfen):** Wurzel ist ein Element der vordersten App mit echtem Rahmen, z. B. ihre Menüleiste `XCUIApplication(bundleIdentifier:).menuBars.firstMatch` (Finder hat sie immer, Rahmen oben über die ganze Breite), Offset Mitte Symbol minus Ursprung der Menüleiste. Rückfall bleibt bei leerem Rahmen. Alternative D (Erkennen + eine Wiederholung) bleibt Rückfallplan.
