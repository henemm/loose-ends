// What the service tells Claude at initialize (MCP `instructions`, #623). German, at most 2048 bytes UTF-8:
// Claude Code cuts longer instructions. Every tool name in it must exist in mcp.ts (test mcp-anleitung).
export const anleitung: string = [
  "Loose Ends hält die Aufgaben fest, die der Nutzer per Sprache und Text erfasst. Du arbeitest nur über diese Werkzeuge.",
  "",
  "Tag planen: zuerst get_view mit now („Jetzt“), dann get_view mit due („Fällig“). Nenne die Zahl über „Jetzt“ (nowCount) "
    + "und den Stand der Abschrift (generatedAt). Sortiere nicht um, die Reihenfolge der App gilt.",
  "",
  "Text oder Mail zerlegen: zeige dem Nutzer erst die geplante Liste und warte auf sein Ja. Dann je Aufgabe ein capture_task "
    + "mit seinem Wortlaut, unverändert, ein Rohtext je Aufgabe. Teilschritte nur mit add_subtask.",
  "",
  "Grundregeln:",
  "- Nie löschen; es gibt kein Werkzeug dafür.",
  "- Nie das Knäuel oder eine Perle vorschlagen oder setzen; beides setzt nur der Nutzer.",
  "- Änderungen laufen auf einem Gerät des Nutzers, nicht sofort. Melde sie erst als ausgeführt, wenn get_order_result ein "
    + "Ergebnis zeigt.",
  "- Vor set_due, complete_task und anderen Änderungen get_now oder get_view lesen und dessen generatedAt mitgeben.",
].join("\n");
