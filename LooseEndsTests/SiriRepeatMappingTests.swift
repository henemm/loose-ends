import Foundation
import Testing
@testable import LooseEnds

/// Siri's repetition (`Calendar.RecurrenceRule` from the Reminders schema) onto `RepeatRule` (#224):
/// every form the type can express is either mapped or named as not mappable.
@Suite("Siri repetition → RepeatRule (#224)") struct SiriRepeatMappingTests {
    private let gregorian = Calendar(identifier: .gregorian)

    private func recurrence(_ frequency: Calendar.RecurrenceRule.Frequency, interval: Int = 1) -> Calendar.RecurrenceRule {
        var rule = Calendar.RecurrenceRule(calendar: gregorian, frequency: frequency)
        rule.interval = interval
        return rule
    }

    private func mapped(_ recurrence: Calendar.RecurrenceRule) -> RepeatRule? {
        if case .rule(let rule) = SiriRepeatMapping.map(recurrence) { return rule }
        return nil
    }

    private func problems(_ recurrence: Calendar.RecurrenceRule) -> Set<SiriRepeatMapping.Unmappable> {
        if case .unmappable(let problems) = SiriRepeatMapping.map(recurrence) { return problems }
        return []
    }

    // MARK: Mapped

    @Test("Daily, weekly, monthly and yearly keep frequency and interval, from the due date")
    func plainFrequencies() {
        let cases: [(Calendar.RecurrenceRule.Frequency, RepeatRule.Frequency)] =
            [(.daily, .daily), (.weekly, .weekly), (.monthly, .monthly), (.yearly, .yearly)]
        for (siri, own) in cases {
            for interval in [1, 2, 3] {
                let rule = mapped(recurrence(siri, interval: interval))
                #expect(rule == RepeatRule(frequency: own, interval: interval), "\(siri) every \(interval)")
                #expect(rule?.basis == .fromDueDate)
            }
        }
    }

    @Test("Weekly on several weekdays keeps them, numbered 1 = Sunday … 7 = Saturday, sorted, once each")
    func weeklyWeekdays() {
        var siri = recurrence(.weekly)
        siri.weekdays = [.every(.friday), .every(.monday), .every(.monday)]
        #expect(mapped(siri)?.weekdays == [2, 6])

        siri.weekdays = [.every(.sunday), .every(.saturday)]
        #expect(mapped(siri)?.weekdays == [1, 7])
    }

    @Test("„Every weekday“ arrives as daily on Monday to Friday and becomes weekly on those days")
    func everyWeekday() {
        var siri = recurrence(.daily)
        siri.weekdays = [.every(.monday), .every(.tuesday), .every(.wednesday), .every(.thursday), .every(.friday)]
        let rule = mapped(siri)
        #expect(rule?.frequency == .weekly)
        #expect(rule?.interval == 1)
        #expect(rule?.weekdays == [2, 3, 4, 5, 6])
    }

    @Test("One time of day is kept; an hour alone means on the hour")
    func timeOfDay() {
        var siri = recurrence(.daily)
        siri.hours = [7]
        siri.minutes = [30]
        #expect(mapped(siri)?.hour == 7)
        #expect(mapped(siri)?.minute == 30)

        siri.minutes = []
        #expect(mapped(siri)?.hour == 7)
        #expect(mapped(siri)?.minute == 0)

        siri.seconds = [0]
        #expect(mapped(siri)?.hour == 7, "zero seconds change nothing")
    }

    // MARK: Not mappable — named, never cut down

    @Test("Hourly and minutely are not mappable")
    func subDailyFrequencies() {
        #expect(problems(recurrence(.hourly)) == [.frequency])
        #expect(problems(recurrence(.minutely)) == [.frequency])
    }

    @Test("An end after a date or a number of times is not mappable")
    func ends() {
        var siri = recurrence(.weekly)
        siri.end = .afterOccurrences(5)
        #expect(problems(siri) == [.end])
        siri.end = .afterDate(Date(timeIntervalSince1970: 1_800_000_000))
        #expect(problems(siri) == [.end])
    }

    @Test("„The second Monday“ is not mappable")
    func nthWeekday() {
        var siri = recurrence(.monthly)
        siri.weekdays = [.nth(2, .monday)]
        #expect(problems(siri).contains(.nthWeekday))
    }

    @Test("Weekdays on a monthly or yearly rule, or on every second day, are not mappable")
    func weekdaysOutsideAWeek() {
        var monthly = recurrence(.monthly)
        monthly.weekdays = [.every(.monday)]
        #expect(problems(monthly) == [.weekdaysOutsideWeek])

        var everyOtherDay = recurrence(.daily, interval: 2)
        everyOtherDay.weekdays = [.every(.monday)]
        #expect(problems(everyOtherDay) == [.weekdaysOutsideWeek])
    }

    @Test("Days of the month or year, months, weeks and set positions are not mappable")
    func calendarDetails() {
        var siri = recurrence(.monthly)
        siri.daysOfTheMonth = [15]
        #expect(problems(siri) == [.daysOfTheMonth])

        siri = recurrence(.yearly)
        siri.daysOfTheYear = [100]
        #expect(problems(siri) == [.daysOfTheYear])

        siri = recurrence(.yearly)
        siri.months = [3]
        #expect(problems(siri) == [.months])

        siri = recurrence(.yearly)
        siri.weeks = [10]
        #expect(problems(siri) == [.weeks])

        siri = recurrence(.monthly)
        siri.setPositions = [-1]
        #expect(problems(siri) == [.setPositions])
    }

    @Test("Several times a day, or minutes without an hour, are not mappable")
    func severalTimes() {
        var siri = recurrence(.daily)
        siri.hours = [8, 20]
        #expect(problems(siri) == [.time])

        siri.hours = []
        siri.minutes = [15]
        #expect(problems(siri) == [.time])
    }

    @Test("A calendar other than the Gregorian one is not mappable")
    func otherCalendar() {
        var siri = recurrence(.monthly)
        siri.calendar = Calendar(identifier: .hebrew)
        #expect(problems(siri) == [.calendar])
    }

    @Test("Every problem of a rule is named, not just the first")
    func allProblemsNamed() {
        var siri = recurrence(.hourly)
        siri.end = .afterOccurrences(3)
        siri.months = [1]
        #expect(problems(siri) == [.frequency, .end, .months])
    }

    // MARK: Applying

    @Test("Applying sets the rule with one revision by the user, reason Siri, already seen; the same rule again writes nothing")
    @MainActor func apply() throws {
        let store = try TestStore()
        let task = TaskItem(rawText: "Blumen gießen")
        store.context.insert(task)
        let rule = RepeatRule(frequency: .weekly, interval: 1, weekdays: [2, 6])

        let revision = try #require(SiriRepeatMapping.apply(rule, to: task))

        #expect(task.repeatRule == rule)
        #expect(revision.field == .repeatRule)
        #expect(revision.author == .user)
        #expect(revision.seenAt != nil)
        #expect(revision.reason == SiriRepeatMapping.reason)
        #expect(revision.oldValue == nil)
        #expect(revision.newValue == FieldCodec.encode(rule))
        #expect((task.revisions ?? []).count == 1)

        #expect(SiriRepeatMapping.apply(rule, to: task) == nil)
        #expect((task.revisions ?? []).count == 1)
    }

    @Test("The reason is translated into German")
    func reasonInGerman() throws {
        let path = try #require(Bundle.main.path(forResource: "de", ofType: "lproj"))
        let german = try #require(Bundle(path: path))
        #expect(german.localizedString(forKey: "From Siri.", value: nil, table: nil) == "Von Siri.")
    }
}
