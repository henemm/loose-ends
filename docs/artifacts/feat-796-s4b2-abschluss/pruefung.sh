#!/usr/bin/env bash
# #796 S4b-2 Abschluss: prüft AC-1 bis AC-3 der Mini-Spec (AC-4 erst nach dem Merge, Aufruf mit --nach-merge).
# Liest nur: Repo-Dateien und GitHub-Issues. Ausgang 0 nur, wenn jede Prüfung besteht.
set -u
cd "$(dirname "$0")/../../.."
fehler=0
bestanden=0
pruefe() { if eval "$2"; then echo "PASS $1"; bestanden=$((bestanden+1)); else echo "FAIL $1"; fehler=$((fehler+1)); fi; }

BELEG=docs/artifacts/feat-796-s4b2-rueckspielprobe/ac14-sonntagslauf.txt
WORTLAUT="auf einem eigenen Server im selben Projekt"

# AC-1: Beleg des Sonntagslaufs mit Quelle, Infra-PR, Ergebnis und null Fehlerzeilen
pruefe "AC-1 Beleg vorhanden" "[ -s $BELEG ]"
pruefe "AC-1 bestanden am 2026-11-15" "grep -q '^2026-11-15T.*RUECKSPIELPROBE BESTANDEN' $BELEG"
pruefe "AC-1 Fehlerzahl 0" "[ \"\$(tail -1 $BELEG)\" = 0 ]"
pruefe "AC-1 Quelle und Infra-PR" "grep -q '^# Quelle:' $BELEG && grep -q 'henemm-infra#385' $BELEG"

# AC-2: CLAUDE.md nennt die Probe als in Betrieb
pruefe "AC-2 kein 'follows with S4b-2'" "! grep -q 'follows with S4b-2' CLAUDE.md"
pruefe "AC-2 Probe in Betrieb mit henemm-infra#385" "grep -q 'restore test.*henemm-infra#385' CLAUDE.md"

# AC-3: neues Issue mit dem Wortlaut, Teil von #612, auf dem Board; #625 wartet darauf
NEU=$(gh issue list --state open --search "\"$WORTLAUT\" in:body" --json number,body \
  --jq "[.[] | select(.number != 796 and (.body | contains(\"$WORTLAUT\")) and (.body | contains(\"#796\")))][0].number // empty")
pruefe "AC-3 neues Issue mit Wortlaut und Verweis auf #796" "[ -n \"$NEU\" ]"
if [ -n "$NEU" ]; then
  pruefe "AC-3 #$NEU ist Teil von #612" "gh api repos/henemm/loose-ends/issues/612/sub_issues --jq '.[].number' | grep -qx $NEU"
  pruefe "AC-3 #$NEU auf dem Board" "gh project item-list 1 --owner henemm --limit 1000 --format json --jq '.items[].content.number' | grep -qx $NEU"
  pruefe "AC-3 #625 wartet auf #$NEU statt #796" "gh issue view 625 --json body --jq .body | grep -i 'Wartet auf' | grep -q '#$NEU' && ! gh issue view 625 --json body --jq .body | grep -i 'Wartet auf' | grep -q '#796'"
fi

# AC-4: erst nach dem Merge
if [ "${1:-}" = "--nach-merge" ]; then
  pruefe "AC-4 #796 geschlossen" "[ \"\$(gh issue view 796 --json state --jq .state)\" = CLOSED ]"
  pruefe "AC-4 Abschlusskommentar nennt 2026-11-15 und #$NEU" "gh issue view 796 --json comments --jq '.comments[-1].body' | grep -q '2026-11-15' && gh issue view 796 --json comments --jq '.comments[-1].body' | grep -q '#$NEU'"
fi

echo "FEHLER=$fehler"
echo "$bestanden passed, $fehler failed"
[ "$fehler" -eq 0 ]
