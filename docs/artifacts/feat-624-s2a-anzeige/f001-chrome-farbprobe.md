# F001 Farbprobe in Chrome (vor dem Ausrollen), 2026-11-17

Fenster-HTML aus `server/src/app-ui.ts` (Stand mit Fix) lokal über 127.0.0.1 in Chrome geladen, eine Zeile mit roter Marke
(`<span class="red">Heute</span>`) und eine wartende Zeile eingesetzt, `getComputedStyle` der Randmarke gemessen:

| Thema | „Heute“ | „Wartet“ | `--red` |
|---|---|---|---|
| hell | rgb(229, 50, 45) | rgb(119, 120, 111) | #E5322D |
| dunkel | rgb(255, 90, 82) | rgb(142, 143, 136) | #FF5A52 |

Die Marke ist wirksam rot (gleich `--red`), die wartende bleibt grau. Vor dem Fix maß das Bild aus claude.ai (94,93,88) = grau.
Der Sichtnachweis am echten Host (AC-10) folgt nach dem Ausrollen.
