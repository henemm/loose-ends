---
spec_file: docs/specs/feat-615-schnitt-3c1-konto-loeschen.md
spec_sha256: 9b8a2a4c32e465be21628f6ffad76dbd21e51e9b32165b294428dc3d0a6b6187
spec_frozen_sha256: ca8f226080ce8a20fe8f0de7e1fa9b8dae280aae311aa9f2cff9440d7feea965
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

- Noch nicht erreichbar: Einhängen in den laufenden Dienst folgt in 3c-2; der Simulator-Beleg des Tickets steht bis S4 aus.
- Scheitert der Apple-Widerruf, wird er nicht wiederholt; der Nutzer müsste selbst in den Apple-Einstellungen widerrufen. Bewusst akzeptiert.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
