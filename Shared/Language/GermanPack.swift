extension LanguagePack {
    static let german = LanguagePack(
        code: "de",
        name: "German",
        numbers: [
            "ein": 1, "eine": 1, "einer": 1, "einem": 1, "einen": 1, "eins": 1, "zwei": 2, "drei": 3,
            "vier": 4, "funf": 5, "sechs": 6, "sieben": 7, "acht": 8, "neun": 9, "zehn": 10, "elf": 11,
            "zwolf": 12,
        ],
        weekdays: [
            "sonntag": 1, "montag": 2, "dienstag": 3, "mittwoch": 4, "donnerstag": 5, "freitag": 6,
            "samstag": 7, "sonnabend": 7,
        ],
        months: [
            "januar": 1, "februar": 2, "marz": 3, "april": 4, "mai": 5, "juni": 6, "juli": 7,
            "august": 8, "september": 9, "oktober": 10, "november": 11, "dezember": 12,
        ],
        relativeDays: ["heute": 0, "morgen": 1, "ubermorgen": 2],
        nextWords: ["nachste", "nachsten", "nachster", "nachstes", "nachstem"],
        dayUnits: ["tag", "tage", "tagen"],
        weekUnits: ["woche", "wochen"],
        dayPrepositions: ["am", "zum", "bis"],
        ordinalSuffixes: [],
        repetitions: ["jeden", "jede", "jeder", "jedes", "jedem", "werktags", "taglich", "wochentlich",
                      "monatlich", "jahrlich"],
        timeCues: ["um", "auf"],
        clockWords: ["uhr"],
        timeArticles: ["ein", "eine", "einer", "einem", "einen"],
        articleCues: ["um"],
        spelledHours: [
            "null": 0, "dreizehn": 13, "vierzehn": 14, "funfzehn": 15, "sechzehn": 16, "siebzehn": 17,
            "achtzehn": 18, "neunzehn": 19, "zwanzig": 20, "einundzwanzig": 21, "zweiundzwanzig": 22,
            "dreiundzwanzig": 23,
        ],
        hourUnits: ["stunden", "stunde", "std", "h"],
        abbreviatedHourUnits: [],
        minuteUnits: ["minuten", "minute", "min"],
        spokenOffsets: [
            ["einer", "halben", "stunde"]: 30, ["einer", "viertelstunde"]: 15, ["einer", "dreiviertelstunde"]: 45,
            ["anderthalb", "stunden"]: 90, ["eineinhalb", "stunden"]: 90, ["einer", "stunde"]: 60,
        ],
        durationPhrases: [
            "eine dreiviertelstunde": 45, "dreiviertelstunde": 45, "eineinhalb stunden": 90,
            "anderthalb stunden": 90, "eine halbe stunde": 30, "halbe stunde": 30,
            "eine viertelstunde": 15, "viertelstunde": 15, "eine stunde": 60, "ein paar minuten": 5,
        ],
        pointInTime: ["in", "nach"]
    )
}
