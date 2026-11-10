# App-Store-Untertitel

Name und Untertitel der App-Informationen in App Store Connect, je Sprache ein Abschnitt (#837, Wortlaut von Henning am
2026-11-04 freigegeben). `scripts/asc_app_info.py untertitel` setzt sie über den Handlauf `asc-app-info`, nur bei Abweichung
und nur, wenn genau eine App-Info bearbeitbar ist. Name und Untertitel haben höchstens 30 Zeichen; `Name:` braucht nur eine
Sprache, die bei Apple neu angelegt wird.

Die Datenschutz-Adresse je Sprache zeigt `lesen` (`datenschutz=<adresse>` oder `datenschutz=-`); `datenschutz` setzt sie aus
der Repo-Variable `ASC_PRIVACY_POLICY_URL` (en-US: `PRIVACY_URL_EN`) nur bei Abweichung, legt nie eine Sprache an und prüft
danach gegen (#893 Schnitt D).

## de-DE

Untertitel: Einfach sagen. Kopf frei.

## en-US

Name: Loose Ends: Voice Tasks
Untertitel: Say it. Clear your head.
