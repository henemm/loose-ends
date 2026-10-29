// #88 Schnitt B1b: exports the raw sentences of the Loose Ends store into the file RawSentenceColumn reads.
// Thin entry point; the work is in Measurement/RawTextExport.swift. Build from outside, no binary in the repo, and
// with the script's ABSOLUTE path: the repo root comes from #filePath, a relative one is refused at run time.
//
//   swiftc -parse-as-library "$PWD/Measurement/RawTextExport.swift" "$PWD/scripts/export-loose-ends-rawtexts.swift" -o "$TMPDIR/export"
//   "$TMPDIR/export" [--store <store file>] [--out <json file>]
//
// The output holds real sentences: it goes to the gitignored docs/reference/loose-ends-rawtexts.json or outside the
// repo, nowhere else. Running it on Henning's real store waits for his "jetzt ist ein Test möglich" (B2).

import Foundation

@main
struct ExportLooseEndsRawTexts {
    /// The normal Mac app's store (`ModelContainerFactory`: configuration "LooseEnds", group.com.henning.looseends).
    static let defaultStore = "~/Library/Group Containers/group.com.henning.looseends/Library/Application Support/LooseEnds.store"
    static let usage = "Aufruf: export [--store <Speicherdatei>] [--out <JSON-Datei>]"

    static func main() {
        guard let arguments = parse(Array(CommandLine.arguments.dropFirst())) else {
            write(usage, to: .standardError)
            exit(2)
        }
        // The repo root, one level above scripts/; only from an absolute #filePath (built with an absolute path).
        let root: URL
        do {
            root = try RawTextExport.root(fromScriptPath: #filePath)
        } catch let failure as RawTextExport.Failure {
            write(failure.message, to: .standardError)
            exit(1)
        } catch {
            write("Export fehlgeschlagen: \(type(of: error))", to: .standardError)
            exit(1)
        }
        let store = URL(fileURLWithPath: NSString(string: arguments.store ?? defaultStore).expandingTildeInPath)
        let defaultOut = root.appendingPathComponent("docs/reference/loose-ends-rawtexts.json").path
        let out = URL(fileURLWithPath: NSString(string: arguments.out ?? defaultOut).expandingTildeInPath)
        do {
            write(try RawTextExport.run(store: store, out: out, root: root), to: .standardOutput)
            write("Geschrieben: \(out.path)", to: .standardOutput)
        } catch let failure as RawTextExport.Failure {
            write(failure.message, to: .standardError)
            exit(1)
        } catch {
            write("Export fehlgeschlagen: \(type(of: error))", to: .standardError)
            exit(1)
        }
    }

    /// Exactly `--store` and `--out`, each at most once and with a value; anything else is nil.
    static func parse(_ arguments: [String]) -> (store: String?, out: String?)? {
        var store: String?
        var out: String?
        var index = 0
        while index < arguments.count {
            guard index + 1 < arguments.count else { return nil }
            let value = arguments[index + 1]
            switch arguments[index] {
            case "--store" where store == nil: store = value
            case "--out" where out == nil: out = value
            default: return nil
            }
            index += 2
        }
        return (store, out)
    }

    static func write(_ line: String, to handle: FileHandle) {
        handle.write(Data((line + "\n").utf8))
    }
}
