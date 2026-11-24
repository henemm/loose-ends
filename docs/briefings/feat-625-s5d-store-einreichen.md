---
spec_file: docs/specs/feat-625-schnitt-5d-1-store-werkzeug.md
spec_sha256: c14b4915a4b08c808dc93b7326730dfe3a1819099b1de65166cf21b2a7c757e2
spec_frozen_sha256: 984da77222b3599ffb3b98edbd2738a16a41752ed331cd64ed237b810906c1c6
---

# PO-Briefing: feat-625-s5d-store-einreichen

- **Spec:** docs/specs/feat-625-schnitt-5d-1-store-werkzeug.md
- **Issue:** #625
- **Erstellt:** 2026-11-24

## Was gebaut wird

Das Store-Werkzeug kann die neue iPhone-Version 1.0.2 anlegen, kennt die Marketing-Adresse und liefert wahre Hinweise für Apples Prüfer.

## Definition of Done

Alle Werkzeug-Tests laufen grün, die Prüfer-Hinweise nennen Apple-Anmeldung, Konto löschen und deutschen Server, und die App selbst bleibt unverändert.

## Wie geprüft wird

Automatische Tests gegen einen Apple-Nachbau belegen Anlegen, Abbrüche und Texte; ob Apple die iPhone-Version wirklich so annimmt, zeigt erst der Folgeschnitt.

## Kritische Anmerkungen

- Bei Apple wird in diesem Schnitt nichts angelegt oder geschrieben; das Verhalten gegenüber dem echten Apple bleibt bis zum Folgeschnitt ungeprüft.
- Datenschutz-Etikett, offene Tür des Dienstes und Einreichen folgen später und brauchen dein ausdrückliches Ja.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
