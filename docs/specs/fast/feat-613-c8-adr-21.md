# Mini-Spec: feat-613-c8-adr-21 (#613 Schnitt C8)

**ADR-Nr.:** ADR-21 (neu), ergänzt ADR-2 (wird nicht aufgehoben)

## Was ändert sich
- `docs/project/00-entscheidungen.md`: neuer Absatz **ADR-21 „Claude bekommt ein Fenster, die Datenhaltung bleibt in iCloud“**
  (Henning, 2026-10-31, Weg B), eingefügt nach ADR-20. Er hält fest:
  - Entscheidung: iCloud/CloudKit (ADR-2) bleibt der Abgleich zwischen den Geräten. Der eigene Dienst (`server/`, Hetzner,
    Postgres, TypeScript) hält nur die **Abschrift** (offene Aufgaben, „Jetzt“ und Zahl aus `ViewRules`, ohne Rohtext und
    Notiz) und die **Aufträge** (`capture`, `complete`, `setDue`), die ein Gerät später als Nutzer-Revision mit Grund „Claude“
    ausführt. Vertrag: `docs/reference/claude-abschrift-vertrag.md`.
  - Warum, mit Quellen aus dem #613-Kommentar vom 2026-10-31: PowerSync unterstützt offiziell nur GRDB, 54 von 149 Dateien
    hängen an SwiftData; Supabase-OAuth ohne dokumentiertes CIMD; Weg B spart #616–#620 (ca. 20 Tage).
  - **Alternative (Weg A):** Backend löst CloudKit ganz ab (Supabase oder eigener Dienst mit PowerSync als Offline-Schicht).
    Sie würde ADR-2 vollständig kippen und das Versprechen „privat in deiner iCloud“ für alle streichen. Bewusst nicht
    gewählt; sie bleibt die Option, falls Nutzer ohne Apple-Geräte (Web, Android) dazukommen sollen.
  - **Make or Buy:** OAuth-Server und Konfliktlösung werden nie selbst geschrieben; Rückfall für den OAuth-Teil ist Supabase Pro.
  - **Folge für das Versprechen „privat in deiner iCloud“:** Es gilt unverändert für alle, die Claude nicht verbinden. Wer
    Claude verbindet, legt die Abschrift (ohne Rohtext und Notiz) auf dem Dienst ab. Der Datenschutztext
    (`docs/reference/datenschutz-entwurf.md`, öffentlich auf henemm.com, sagt heute „kein eigener Server, kein Konto bei uns“)
    muss dafür geändert werden, **bevor** ein externer Nutzer Claude verbinden kann; das gehört zu #625 und zu #615
    (Konto), nicht zu diesem Schnitt. Bis dahin ruft die App den Dienst nirgends auf.
  - Betrieb: erst der bestehende Hetzner-Server, vor externen Nutzern ein eigener Server im selben Projekt (#796, #625).
- Zeile ADR-2 erhält den Zusatz „ergänzt durch ADR-21: für Claude zusätzlich eine Abschrift auf dem eigenen Dienst“.
- Ticket #613 wird nach dem Merge geschlossen (Beschreibung ist durch Weg B überholt; Abschlusskommentar nennt, was wohin
  gewandert ist: Konto #615, Betrieb #796, Gerätekanal #795, MCP #621/#622).

## Was darf sich nicht ändern
- Kein Code, keine App, kein Dienst, keine Tests, `project.yml`, Modell oder Katalog.
- ADR-1 bis ADR-20 bleiben wörtlich; nur die ADR-2-Zeile bekommt den Zusatz.
- Der Datenschutztext wird hier nicht geändert (gehört zu #625).

## Manuelle Test-Schritte
Keine nötig, nur Dokumentation. Kein Pfad der Geräteliste berührt.

## Inline-Test
- [ ] `grep -c "ADR-21" docs/project/00-entscheidungen.md` ≥ 2 (Eintrag und Zusatz an ADR-2)
- [ ] `git diff --stat` zeigt nur `00-entscheidungen.md` und die Spec/Belege des Workflows
- [ ] Skripttests (`scripts/test_*.py`, die Entscheidungsdatei lesen) bleiben grün
