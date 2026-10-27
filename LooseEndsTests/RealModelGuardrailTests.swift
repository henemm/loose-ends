#if canImport(FoundationModels) && !os(watchOS)
import Foundation
import OSLog
import Testing
@testable import LooseEnds

/// Refusal rate of the real on-device model on a Mac (#71, Schnitt 1): every text twice, since a
/// false alarm is not deterministic (forum 793876). Same gates as `RealModelLatencyTests`: skipped
/// without `LOOSEENDS_REAL_MODEL=1`, never in CI. Texts: the 100 touchy ones of `guardrail-corpus.json`,
/// plus the FocusBlox raw sentences when `LOOSEENDS_FOCUSBLOX_CORPUS` points at that file. Raw probes go
/// to `LOOSEENDS_GUARDRAIL_OUT`, without the everyday wording (personal data); the local summary with
/// every hit's wording only to `LOOSEENDS_GUARDRAIL_LOCAL`, outside the repo. Without them nothing is written.
@Suite(
    .enabled(if: RealModel.isRequested, "LOOSEENDS_REAL_MODEL=1 is not set (./scripts/sim.sh real-model-guardrail)"),
    .serialized
)
struct RealModelGuardrailTests {
    private static let logger = Logger(subsystem: "com.henning.looseends", category: "RealModelGuardrail")
    private static let runs = 2

    private struct Item {
        let id: String
        let menge: String
        let sprache: String
        let gruppe: String
        let text: String
    }

    struct Head: Codable {
        let geraet: String
        let system: String
        let datum: Date
        let nurHeikel: Bool
        let durchlaeufe: Int
    }

    struct RawFile: Codable {
        let kopf: Head
        let proben: [GuardrailProbe]
    }

    private struct FocusBloxSentence: Decodable {
        let lang: String
        let rawText: String
    }

    private static var environment: [String: String] { ProcessInfo.processInfo.environment }

    private func touchyItems() throws -> [Item] {
        try Corpus.load(fileName: "guardrail-corpus").map { entry in
            Item(id: entry.id, menge: "heikel", sprache: entry.lang, gruppe: entry.form, text: entry.text)
        }
    }

    /// The everyday set, only when the variable points at an existing file. Ids are the index, never the sentence.
    private func everydayItems() throws -> [Item] {
        guard let path = Self.environment["LOOSEENDS_FOCUSBLOX_CORPUS"], !path.isEmpty,
              FileManager.default.fileExists(atPath: path) else {
            Self.logger.info("LOOSEENDS_FOCUSBLOX_CORPUS not set or missing, touchy set only")
            return []
        }
        let sentences = try JSONDecoder().decode([FocusBloxSentence].self, from: Data(contentsOf: URL(fileURLWithPath: path)))
        return sentences.enumerated().map { index, sentence in
            Item(id: "alltag-\(index)", menge: "alltag", sprache: sentence.lang, gruppe: "alltag", text: sentence.rawText)
        }
    }

    private func input(_ note: String) -> EnrichmentInput {
        EnrichmentInput(
            rawText: note,
            capturedAt: Date(),
            contextVocabulary: ["Computer", "Telefon", "Haus", "Garten", "Unterwegs", "Besorgung"],
            projectNames: [],
            examples: []
        )
    }

    /// One call with a fresh enricher, as in the product. The probe keeps the wording; the raw file drops it later.
    private func probe(_ item: Item, run: Int) async -> GuardrailProbe {
        var kind: String?
        do {
            _ = try await FoundationModelsEnricher().enrich(input(item.text))
        } catch {
            kind = MeasurementErrorKind.classify(error)
        }
        Self.logger.info("\(item.id, privacy: .public) run \(run, privacy: .public): \(kind ?? "ok", privacy: .public)")
        return GuardrailProbe(id: item.id, menge: item.menge, sprache: item.sprache, gruppe: item.gruppe,
                              text: item.text, durchlauf: run, fehlerart: kind)
    }

    @Test(
        "Every text twice through the real model, refusals classified and written as raw probes",
        .enabled(if: RealModel.isAvailable, "Apple Intelligence is not available on this Mac")
    )
    func refusalRate() async throws {
        let everyday = try everydayItems()
        let items = try touchyItems() + everyday
        var probes: [GuardrailProbe] = []
        // Each text once per run, also after a failure: no retry, no stop after failures in a row.
        for run in 1...Self.runs {
            for item in items { probes.append(await probe(item, run: run)) }
        }
        #expect(probes.count == items.count * Self.runs)

        let head = Head(geraet: Self.machineModel(), system: ProcessInfo.processInfo.operatingSystemVersionString,
                        datum: Date(), nurHeikel: everyday.isEmpty, durchlaeufe: Self.runs)
        try writeRaw(head: head, probes: probes)
        try writeLocal(head: head, report: GuardrailReport(probes: probes))
    }

    private func writeRaw(head: Head, probes: [GuardrailProbe]) throws {
        guard let path = Self.environment["LOOSEENDS_GUARDRAIL_OUT"], !path.isEmpty else {
            Self.logger.info("LOOSEENDS_GUARDRAIL_OUT not set, probes not written")
            return
        }
        let stored = probes.map { probe -> GuardrailProbe in
            var copy = probe
            if copy.menge != "heikel" { copy.text = nil }
            return copy
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let url = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoder.encode(RawFile(kopf: head, proben: stored)).write(to: url, options: .atomic)
        Self.logger.info("Probes written to \(path, privacy: .public)")
    }

    /// The summary with the wording of every hit, everyday ones included: local only, never in the repo.
    private func writeLocal(head: Head, report: GuardrailReport) throws {
        guard let path = Self.environment["LOOSEENDS_GUARDRAIL_LOCAL"], !path.isEmpty else {
            Self.logger.info("LOOSEENDS_GUARDRAIL_LOCAL not set, local summary not written")
            return
        }
        let url = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Self.summary(head: head, report: report).write(to: url, atomically: true, encoding: .utf8)
        Self.logger.info("Local summary written to \(path, privacy: .public)")
    }

    private static func summary(head: Head, report: GuardrailReport) -> String {
        var lines = ["Gerät \(head.geraet), \(head.system), \(head.datum.ISO8601Format())",
                     "Durchläufe \(head.durchlaeufe), \(head.nurHeikel ? "nur 100er-Menge" : "heikel + FocusBlox")",
                     "Schwelle 1 %: \(report.threshold.isUnder ? "unter" : "über"), obere Grenze über 1 %: \(report.threshold.upperBoundAbove ? "ja" : "nein")",
                     line("gesamt", report.total)]
        for (title, slices) in [("Menge", report.byMenge), ("Sprache", report.bySprache), ("Gruppe", report.byGruppe)] {
            lines += slices.keys.sorted().compactMap { key in slices[key].map { line("\(title) \(key)", $0) } }
        }
        lines.append("Treffer: \(report.hits.count)")
        lines += report.hits.map { hit in
            "\(hit.id) [\(hit.menge), \(hit.gruppe), \(hit.sprache)] \(hit.frequency.rawValue) \(hit.kindsPerRun.joined(separator: "/")): \(hit.text ?? "")"
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private static func line(_ title: String, _ slice: GuardrailReport.Slice) -> String {
        let kinds = slice.byKind.keys.sorted().map { "\($0) \(slice.byKind[$0] ?? 0)" }.joined(separator: ", ")
        let three = slice.ruleOfThree.map { String(format: ", 3/n %.2f %%", $0 * 100) } ?? ""
        return "\(title): " + String(format: "%d/%d Texte = %.2f %% (Grenze %.2f %%",
                      slice.hitTexts, slice.texts, slice.textRate * 100, slice.upperBound * 100)
            + three + String(format: "), Proben %d/%d gemessen = %.2f %%, ausgenommen %d",
                             slice.refusedProbes, slice.probes - slice.excludedProbes, slice.probeRate * 100, slice.excludedProbes)
            + (kinds.isEmpty ? "" : " [\(kinds)]")
    }

    private static func machineModel() -> String {
        var size = 0
        guard sysctlbyname("hw.model", nil, &size, nil, 0) == 0, size > 0 else { return "unbekannt" }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname("hw.model", &buffer, &size, nil, 0) == 0 else { return "unbekannt" }
        return String(decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }
}
#endif
