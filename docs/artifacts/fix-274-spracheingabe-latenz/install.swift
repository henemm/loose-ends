import Speech

@main struct I {
    static func main() async throws {
        let l = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: "de_DE"))!
        let t = SpeechTranscriber(locale: l, transcriptionOptions: [], reportingOptions: [.volatileResults], attributeOptions: [])
        print("vorher", await AssetInventory.status(forModules: [t]))
        if let r = try await AssetInventory.assetInstallationRequest(supporting: [t]) { try await r.downloadAndInstall() }
        print("nachher", await AssetInventory.status(forModules: [t]))
        print("installed locales", await SpeechTranscriber.installedLocales.map(\.identifier))
    }
}
