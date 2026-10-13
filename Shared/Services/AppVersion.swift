import Foundation

/// The version this build reports, as TestFlight shows it: "0.1.0 (45)" (#391). Shared by the settings
/// on iPhone, iPad and Mac and by the watch app, so every device can say which build it runs.
enum AppVersion {
    /// `short` is the marketing version, `build` the TestFlight build number (the CI run number).
    static func text(short: String?, build: String?) -> String {
        switch (short?.nonEmpty, build?.nonEmpty) {
        case let (short?, build?): "\(short) (\(build))"
        case let (short?, nil): short
        case let (nil, build?): "(\(build))"
        case (nil, nil): "–"
        }
    }

    static func text(bundle: Bundle = .main) -> String {
        text(short: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
             build: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String)
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
