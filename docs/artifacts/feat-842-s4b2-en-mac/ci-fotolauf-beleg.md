# CI-Fotoläufe store-mac.yml (#842 S4b-2)

Gestartet am 2026-11-08 auf dem Zweig `worktree-whimsical-nibbling-bird` (Commit 842c1e4), vor dem Merge:
`gh workflow run store-mac.yml --ref worktree-whimsical-nibbling-bird -f language=<de|en>`.
GitHub nahm die neue Eingabe `language` auf dem Zweig an; ein zweiter PR nach dem Merge ist damit nicht nötig.

| Sprache | Run-ID | Ergebnis | Artefakt | Umgebung im Protokoll |
|---|---|---|---|---|
| en | 42493445337 | success, „Executed 1 test, with 0 failures“, TEST SUCCEEDED | `StoreMac-en` | `TEST_RUNNER_LOOSEENDS_UI_LANG: en` (15:19:01Z) |
| de | 42493481108 | success | `StoreMac-de` | `TEST_RUNNER_LOOSEENDS_UI_LANG: de` (15:25:35Z) |

Ein Lauf ohne Eingabe (Push auf `store/mac`) wurde nicht gefahren: Er wertet denselben Ausdruck
`${{ inputs.language || 'de' }}` mit leerem `inputs.language` aus und ergibt `de` (Abweichung von AC-6 genannt).

Artefakt `StoreMac-en`: vier Anhänge `store-01-start`, `store-03-neu`, `store-04-detail`, `store-05-erledigt`.
`python3 scripts/store_screenshots.py --mac docs/store/screenshots/en <export>` → „4 Mac-Bilder (1280x800)“.
`sips`: alle vier 1280×800, `hasAlpha: no`. Manifest `en`: Mac-Eintrag angehängt („Mac (16:10)“, 1280x800,
vier Dateien), iPhone/iPad/Watch unverändert (Diff nur Zusatz).

## Sichtprüfung Englisch (alle vier geöffnet)

- `01-start`: Seitenleiste CONTENTS, Start page 3, Next up, Due 3, New 4, Tags 6 (Phone 1, Garden 1), Projects, All open 4,
  Completed; Kopf „Today three things due.“, Datum „Sunday Nov 8“; „New · 4 to look over“, die vier englischen Aufgaben
  (Check the tax notice !!!, Call Anna about Sunday · Phone, Water the flowers, Mow the lawn · Garden), Zeile „What should I
  remember?“, darunter „Now 3“ mit drei „Today“-Zeilen; rechts QUICK, NEXT DAYS Sun 3 / Mon–Thu 0. Startsprache englisch
  (Wochentage und Datum englisch formatiert).
- `03-neu`: Kopf „New · 4 open“, Abschnitt „NEEDS A LOOK“, vier englische Aufgaben je mit „Not sorted yet“.
- `04-detail`: Titel „Mow the lawn“, Hinweis „Not sorted yet – That happens by itself once Apple Intelligence is ready.“,
  Tags Garden, Wortzeilen + Note, + Attachment, + Due, + Place, + Importance, + Urgency, + Duration, + Energy, + Project,
  + Subtask, + Waiting on, + The Tangle, + Collect beads; „1 from your words · Show“; Leiste „Looks right“, „Complete“.
- `05-erledigt`: Kopf „Completed“, „THIS WEEK · NOVEMBER 2 – 8“, Schnur, „Sun · Mow the lawn · Garden“; Seitenleiste
  Completed 1, New 3.

Kein deutsches Wort auf den vier Bildern; nichts bricht unleserlich um; Fenster 1280×800 voll sichtbar (der Test
mit `macAssertWindowFitsScreen` bestand). Das „!!!“ unter „Check the tax notice“ ist eine Regel der App („tax“ steht in
`EnglishPack.importanceWords`) und erscheint ebenso auf dem freigegebenen englischen iPhone-Bild `en/iphone/01-start.png`.

## Gegenprobe Deutsch

`StoreMac-de` `store-01-start` neben `docs/store/screenshots/de/mac/01-start.png` geöffnet: gleicher Aufbau, gleiche Texte
(Steuerbescheid prüfen, Anna wegen Sonntag anrufen · Telefon, Blumen gießen, Rasen mähen · Garten, „Heute drei Dinge
fällig.“, „4 zum Durchsehen“, „Jetzt 3“), gleiche Zeilenzahl, 1280×800. Unterschiede: Datum (Sonntag 8. Nov. statt Samstag
31. Okt., Tagesleiste So–Do statt Sa–Mi) und die Trennlinien unter „Jetzt“ beginnen etwas weiter links (App-Stand seit
31.10., nicht aus diesem Schnitt). Die Dateien des Gegenlaufs wurden nicht übernommen; unter `docs/store/screenshots/de/`
steht nichts im Diff.

## Geräteliste

Diff: `.github/workflows/store-mac.yml`, `LooseEndsUITests/MacStoreScreenshotsTests.swift`, `scripts/test_store_screenshots.py`,
`docs/…`. Kein Pfad der Geräteliste berührt. Nichts lief auf Hennings Geräten oder seinem Mac.
