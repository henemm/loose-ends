---
spec_file: docs/specs/feat-625-schnitt-1-datenschutztext.md
spec_sha256: 2a98604e793af279fbf16723fe42cb52766fa94a5729e70f48c6c2b278d231b3
spec_frozen_sha256: 7923fa36c903e1824b18ce6021fa2065fb05e98c3483c26ca238d8257a74ff00
---

# PO-Briefing: feat-625-store-datenschutz

- **Spec:** docs/specs/feat-625-schnitt-1-datenschutztext.md
- **Issue:** #625
- **Erstellt:** 2026-11-17

## Was gebaut wird

Der Datenschutztext nennt künftig die Abschrift deiner offenen Aufgaben und die Installationskennung, deutsch und englisch, auf henemm.com.

## Definition of Done

Beide öffentlichen Seiten sind erreichbar, enthalten den freigegebenen Wortlaut samt Abschrift-Zeitpunkt, und der Store-Schalter für das Konto bleibt aus.

## Wie geprüft wird

Ein Textprüfskript belegt Kernsätze lokal und live; ob die Aussagen stimmen, belegt nur ein Abgleich gegen den Code, keine Rechtsprüfung.

## Kritische Anmerkungen

- Weckruf (Push-Token) fehlt bewusst im Text; mit dem späteren Schnitt muss der Text erneut geändert und freigegeben werden.
- Abmelden lässt die zuletzt gesendete Abschrift beim Dienst stehen; der Text sagt das offen.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
