# Mini-Spec: fix-334-ipad-markierung

**ADR-Nr.:** keine — kein Architekturschritt, schaltet eine vorhandene Darstellung (#476) auf dem iPad ein.

Ticket #334 (iPad: ausgewählte Zeile der Seitenleiste im hellen Modus kaum lesbar). Nachgestellt am 2026-10-16
(Stand 246fe4c, iPad Pro 13" M5, iOS 27, hell, Querformat): Der gemeldete Fehler (weiße Schrift auf hellem Grund)
ist seit dem Umbau zum Inhaltsverzeichnis (#368, #463) weg. Neu: Die offene Liste ist auf dem iPad gar nicht
mehr markiert, weil `SidebarView` dem kompakten Zweig kein `selected` mitgibt (nur der Mac-Zweig tut es).
Entscheidung Henning (2026-10-16): offene Zeile auf dem iPad markieren wie am Mac, iPhone unverändert.

## Was ändert sich

- **AC-1:** Auf dem iPad trägt im Inhaltsverzeichnis der Seitenleiste die Zeile der gerade offenen Liste die
  Markierung des Mac (zarte graue Fläche, `Color.primary.opacity(0.07)`): in Hell und Dunkel, Schrift unverändert
  gut lesbar. Gilt für die Zeilen „Als nächstes“, „Fällig“, „Neu“, „Alle offenen“, „Erledigt“ und für die Wörter
  Etiketten/Projekte (Seiten `.catalog`).
- **AC-2:** Die markierte Zeile meldet sich für VoiceOver und UI-Tests als ausgewählt (`.isSelected`); eine
  nicht offene Zeile nicht.
- **AC-3:** Ohne offene Liste (Startseite im Detail) ist keine Zeile markiert.
- **AC-4:** Umsetzung in `SidebarView.swift` (kompakter Zweig reicht `selection` als `selected` durch) und
  `StartZones.swift` (`lineButton`: `.isSelected`-Merkmal bei `isOpen`). Eine Stelle je Datei, ~10 LoC.

## Was darf sich nicht ändern

- **AC-5:** iPhone: Nach dem Zurück aus einer Liste ist im Inhaltsverzeichnis keine Zeile markiert (das
  Verzeichnis ist dort eine Seite, keine Seitenleiste). Der Mac-Zweig bleibt unverändert.
- Farbbudget: keine neue Farbe, kein Akzent auf der Fläche (Akzent = antippbar bleibt den Wörtern).
- Kein Eingriff in den Zweig `showsFoldGroups` (Fallback ohne kompakte Größenklasse) und nicht in `Shared/`.

## Abnahme (Stufe 2, Simulator; Kein Pfad der Geräteliste berührt)

1. iPad Pro 13" (M5): Querformat und Hochformat, hell und dunkel; „Alle offenen“ und „Neu“ antippen, Bildschirmfoto
   je Zustand (Markierung sichtbar, Schrift lesbar). Belege unter `docs/artifacts/fix-334-ipad-markierung/`.
2. iPhone 17: Liste öffnen, zurück, Bildschirmfoto: nichts markiert.

## Inline-Test (während der Umsetzung)

- [ ] UI-Test (`StartScreenInteractionTests`): Liste „Neu“ öffnen → auf iPad (`userInterfaceIdiom == .pad`) hat
  `viewRow_new` den Zustand `isSelected`, `viewRow_open` nicht; auf iPhone nach „Zurück“ hat keine Zeile ihn.
  Vorher rot (iPad), nachher grün.
