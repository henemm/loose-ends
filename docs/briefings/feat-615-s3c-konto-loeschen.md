---
spec_file: docs/specs/feat-615-schnitt-3c1-konto-loeschen.md
spec_sha256: 4ad2d5779b851f1826eb72c45d1fedcaaf551a79120a23120ac61a2437792a12
spec_frozen_sha256: 0ff33383c8b6e01f466bd097f8932cf60bbd8a1262c858a002c76560c9128bfd
---

# PO-Briefing: feat-615-s3c-konto-loeschen

- **Spec:** docs/specs/feat-615-schnitt-3c1-konto-loeschen.md
- **Issue:** #615
- **Erstellt:** 2026-11-05

## Was gebaut wird

Der Dienst bekommt die Funktion „Konto löschen“: Konto samt Daten verschwindet, danach wird Apples Zugriffsschlüssel widerrufen.

## Definition of Done

Ein angemeldeter Nutzer löscht sein Konto per Anfrage an den Dienst; danach bleibt keine Zeile von ihm übrig, und Apple wurde zum Widerruf angefragt.

## Wie geprüft wird

Automatische Tests mit nachgestelltem Apple belegen Löschung, Widerruf und Fehlerfälle; echtes Apple-Verhalten und der App-Ablauf bleiben ungeprüft.

## Kritische Anmerkungen

- Neu gegenüber erster Freigabe: Widerruf entfällt auch bei veralteter Apple-Kennung; Löschen antwortet trotzdem „erledigt“, ein weiterer Test deckt das ab.
- Noch nicht erreichbar: Einhängen in den laufenden Dienst folgt in 3c-2; App-Ablauf erst mit S4.
- Scheitert der Apple-Widerruf, gibt es keine Wiederholung; der Nutzer müsste selbst bei Apple widerrufen. Bewusst akzeptiert.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
