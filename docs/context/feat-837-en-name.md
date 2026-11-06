# Context: feat-837-en-name

## Request Summary
Das Anlegen der englischen App-Info-Lokalisierung (en-US) scheitert bei Apple mit HTTP 409 `ENTITY_ERROR.ATTRIBUTE.INVALID.DUPLICATE.DIFFERENT_ACCOUNT` (Lauf 42183585381, nach PR #850). Henning wählte am 2026-11-06: englischen Namen mit Zusatz versuchen, deutscher Name bleibt.

## Related Files
| File | Relevance |
|------|-----------|
| docs/reference/app-store-untertitel.md | Quelle der Texte; `## en-US` hat `Name: Loose Ends` und `Untertitel: Say it. Clear your head.` — die Zeile `Name:` ist die einzige nötige Änderung |
| scripts/asc_app_info.py | `wanted_texts` liest Name/Untertitel (max. 30 Zeichen, `MAX_CHARS`); `write_subtitles` legt eine fehlende Sprache per POST mit Name an; kein Code-Änderungsbedarf erwartet |
| scripts/test_asc_app_info.py | Fake-Server-Tests; `NAME = "Loose Ends"` ist Testfixture, hängt nicht an der Doku-Datei (APP_INFO_FILE überschreibbar) |
| .github/workflows/asc-app-info.yml | Handlauf `lesen`/`untertitel` |

## Existing Patterns
- Texte stehen nur in der Referenzdatei, das Skript liest sie; Länge wird vor jeder Anfrage geprüft.
- Handlauf `lesen` zeigt den Zustand (2026-11-06: eine App-Info READY_FOR_DISTRIBUTION, eine PREPARE_FOR_SUBMISSION; de-DE heißt "Loose Ends", Untertitel noch "Gesagt. Sortiert.").
- Fehlercode seit PR #850 im Protokoll.

## Dependencies
- Upstream: App Store Connect API (`appInfoLocalizations`).
- Downstream: Store-Auftritt englisch; keine App-Funktion.

## Existing Specs
- docs/specs/feat-837-schnitt-2-schreibweg.md (Schreibweg), docs/specs/fix-837-asc-fehlercode.md

## Risks & Considerations
- Bedeutung von DIFFERENT_ACCOUNT ist bei Apple nicht dokumentiert (Suche 2026-11-06 ohne Treffer); Deutung "Name bei anderem Konto vergeben" ungeprüft. Der Lauf nach dem Merge ist der Test.
- Der Name ist öffentlich sichtbar; ein von Apple angenommener Name lässt sich danach nicht beliebig zurücknehmen.
- Zusatz bleibt ≤ 30 Zeichen; Marke "Loose Ends" bleibt vorn.
- Wahl des Zusatzes ist ein Produktthema (Henning), Empfehlung in /20-analyse mit Alternative.
- Bei erneutem 409 kein Blindversuch mit weiteren Namen: erst den Hinweis lesen.

## Analysis

### Type
Feature (Textänderung am Store-Auftritt; kein Fehler im Code — der Schreibweg arbeitet, Apple lehnt den Namen ab).

### Recherche (2026-11-06, vor allem anderen)
- Wörtlicher Code `ENTITY_ERROR.ATTRIBUTE.INVALID.DUPLICATE.DIFFERENT_ACCOUNT` bei `appInfoLocalizations`: Apple-Forum https://developer.apple.com/forums/thread/844943 (gleicher Fehler beim PATCH des Namens, Name blieb auch nach Löschen des alten App-Eintrags gesperrt, ohne Antwort).
- Apple-Support laut Forum (aus zweiter Hand): Ein Name gilt als vergeben, sobald ein App-Eintrag existiert, und bleibt für gespeicherte Lokalisierungen reserviert, solange die App in Entwicklung ist.
- Apple-Hilfe: Ein Name ist je Lokalisierung einmalig (https://www.developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app). Abhilfe laut Hilfe: den anderen Eintrag umbenennen oder entfernen.
- Fremde App mit gleichem Namen: Markenstreit-Formular (https://www.apple.com/legal/intellectual-property/dispute-forms/app-store); Entwickler im Forum berichten, praktisch half nur ein anderer Name (https://developer.apple.com/forums/thread/685777, https://developer.apple.com/forums/thread/691494).
- Es gibt keine Apple-Dokumentation zum Code selbst. Wessen Eintrag den englischen Namen hält, ist nicht abfragbar.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| docs/reference/app-store-untertitel.md | MODIFY | `## en-US`: Zeile `Name:` mit Zusatz |
| docs/specs/feat-837-schnitt-3-en-name.md | CREATE | Spec |

Skript und Tests brauchen keine Änderung (Länge ≤ 30 prüft `wanted_texts` schon vor der Anfrage).

### Scope Assessment
- Files: 1 Doku + Spec
- Estimated LoC: +1/-1 (ohne Spec)
- Risk Level: LOW (öffentlich sichtbarer Name; ein von Apple angenommener Name lässt sich nicht beliebig zurücknehmen)

### Technical Approach
Einfachster Weg zuerst: nur die Zeile `Name:` im Abschnitt en-US ändern, danach `untertitel` im Handlauf `asc-app-info` laufen lassen. Der Lauf ist der Nachweis (Fehler 409 weg, `lesen` zeigt en-US mit Name und Untertitel). Marke „Loose Ends“ bleibt vorn.
Empfehlung: `Loose Ends: Voice Tasks` (23 Zeichen). Es sagt das, was die App tut (sprechen, Aufgabe erfasst), und bleibt weit unter 30.
Alternativen:
1. `Loose Ends – Quick Capture` (26): neutraler, ohne „Voice“; weniger greifbar.
2. Namen „Loose Ends“ behalten und bei Apple klären (Support/Markenformular): würde den Zusatz sparen, dauert aber unbestimmt lang und blockiert die 1.0-Einreichung; ohne Beleg, dass der Name uns zusteht.
3. Keine en-US-Lokalisierung anlegen: englische Store-Besucher sähen den deutschen Untertitel — verworfen, weil #837 gerade den englischen Auftritt will. Dafür würde die Entscheidung „DE+EN“ (#788) gekippt.
Zweifel an der Deutung: ob Apple auch den Zusatznamen ablehnt, ist offen; der Lauf entscheidet. Bei erneutem 409 kein Blindversuch mit weiteren Namen, erst den Hinweis lesen.

### Dependencies
Upstream: App Store Connect API. Downstream: nur der englische Store-Auftritt; Build 128 / Einreichung 1.0 (#788) wartet nicht auf den Namen, der Name wirkt erst mit der nächsten Einreichung.

### Open Questions
- [x] Zusatz: Henning wählte am 2026-11-06 `Loose Ends: Voice Tasks`.
