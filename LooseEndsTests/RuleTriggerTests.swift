import Foundation
import Testing
@testable import LooseEnds

/// The words a rule read a field from, marked in the field editor (#101, AC-7).
@Suite("Rule trigger") struct RuleTriggerTests {
    private func trigger(_ field: RevisedField, in text: String) -> String? {
        RuleTrigger.range(of: field, in: text).map { String(text[$0]) }
    }

    @Test("The due date marks the words of its expression, in the original spelling")
    func dueDate() {
        #expect(trigger(.dueDate, in: "bis Freitag wichtig Geschenk für Anna besorgen") == "Freitag")
        #expect(trigger(.dueDate, in: "Steuerbescheid morgen prüfen") == "morgen")
        #expect(trigger(.dueDate, in: "Zahnarzt nächsten Freitag anrufen") == "nächsten Freitag")
        #expect(trigger(.dueDate, in: "Müll in 3 Tagen rausbringen") == "in 3 Tagen")
        #expect(trigger(.dueDate, in: "Miete bis Ende des Monats überweisen") == "Ende des Monats")
        #expect(trigger(.dueDate, in: "Pay rent by the end of the month") == "end of the month")
        #expect(trigger(.dueDate, in: "Geburtstag am 15. März feiern") == "15. März")
    }

    @Test("Umlauts and ß before the expression keep the words aligned")
    func alignmentAfterFolding() {
        #expect(trigger(.dueDate, in: "Straße fegen, Öl prüfen übermorgen") == "übermorgen")
    }

    @Test("No expression, no mark; a repetition is no date")
    func noDueDate() {
        #expect(trigger(.dueDate, in: "Rasen mähen") == nil)
        #expect(trigger(.dueDate, in: "Jeden Montag Blumen gießen") == nil)
    }

    @Test("Importance and urgency mark their keyword, the earliest of the winning signal")
    func keywords() {
        #expect(trigger(.importance, in: "Rechnung über 250 € zahlen") == "Rechnung")
        #expect(trigger(.importance, in: "Brief vom Finanzamt beantworten") == "Finanzamt")
        #expect(trigger(.urgency, in: "dringend Arzt anrufen") == "dringend")
        #expect(trigger(.urgency, in: "Rasen mähen") == nil)
    }

    @Test("Fields without a single trigger get no mark")
    func noTrigger() {
        #expect(trigger(.duration, in: "Rasen mähen morgen") == nil)
        #expect(trigger(.contexts, in: "Rasen mähen morgen") == nil)
    }

    @Test("The span never changes which expression the parser picks")
    func spanMatchesExpression() {
        let parser = DateExpressionParser(calendar: Calendar(identifier: .gregorian))
        for text in ["morgen", "nächste Woche Freitag", "am 20.", "on May 4th", "Wochenende"] {
            #expect(parser.expression(in: text) != nil, "\(text)")
            #expect(parser.span(in: text) != nil, "\(text)")
        }
    }
}
