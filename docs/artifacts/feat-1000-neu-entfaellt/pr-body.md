Refs #1000 (Schnitt 1 von 3, Epic #999, ADR-22)

## Was sich ändert
- Startseite (iPhone, iPad, Mac): Der Kopf „Neu · N zum Durchsehen“ über der Schreibzeile entfällt. Die Zeilen dieser Sitzung bleiben zwischen Satz des Tages und Schreibzeile (Entwurf A, von Henning am 2026-11-26 freigegeben: https://claude.ai/artifact/3oGvFJxJ7Mob4WcfZDiam3).
- Index („Inhalt“) und Seitenleiste führen „Neu“ nicht mehr (`ViewRules.dailyViews`/`indexViews` ohne `.new`).
- VoiceOver nach Return: „Captured: %@“ / „Aufgenommen: %@“ statt „Filed in New: %@“.
- UI-Tests öffnen frisch Erfasstes über „Lose Enden“ (`viewRow_open`); drei Tests, die nur die Liste „Neu“ prüften, entfallen.

App-Code: 3 Dateien, +19/−83. Spec: `docs/specs/feat-1000-schnitt-1-startseite-ohne-neu.md`.

## Belege
- Unit: StartViewsTests, InboxDrawerTests grün; Katalogwächter 9/9.
- UI lokal (iPhone-Simulator): InboxDrawerSmokeTests 2/2 (mit `test-proof`), CaptureSmokeTests 29/29, StartScreenInteractionTests 17/17, dazu Calendar, ContextUniqueness, Drive, Fields, NoModelCapture, Place, ProjectSubtasks, Recognition, StoreScreenshots, DesignGallery grün. PaperGroundTests: 2 übersprungen (nur iPad).
- Mac-Klassen (MacDetailClickTests, MacGalleryTests, MacStoreScreenshotsTests) nur in „Mac Gallery (macOS)“.
- Adversary VERIFIED (3 Runden): `docs/artifacts/feat-1000-neu-entfaellt/adversary-dialog.md`.

Kein Pfad der Geräteliste berührt.

## Folgeschnitte
S2: Liste „Neu“, Wischen/Menü/Detail-Knopf „Passt“, ReviewNote. S3: Regeln (`isInNew`, `ViewKind.new`, `confirmReview`), Tönung weg, Katalogschlüssel, Doku. Danach TestFlight-Bau mit den Gerätepunkten von #982.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
