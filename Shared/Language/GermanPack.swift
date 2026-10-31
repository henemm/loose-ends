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
                      "monatlich", "jahrlich"]
    )
}
