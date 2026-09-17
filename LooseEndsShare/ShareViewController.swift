import OSLog
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// The share sheet's entry (design briefing, screen 1, "Aus Mail"): collects text, links and mails
/// from the shared items, then shows the capture form. Saves into the shared store; the app
/// enriches on its next launch (ADR-4).
final class ShareViewController: UIViewController {
    private static let logger = Logger(subsystem: "com.henning.looseends", category: "Share")

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        Task { await present() }
    }

    private func present() async {
        let items = (extensionContext?.inputItems as? [NSExtensionItem]) ?? []
        let content = await Self.collect(from: items)
        let form = ShareCaptureView(
            content: content,
            finish: { [weak self] in self?.extensionContext?.completeRequest(returningItems: nil) },
            cancel: { [weak self] in self?.extensionContext?.cancelRequest(withError: CocoaError(.userCancelled)) }
        )
        let host = UIHostingController(rootView: form)
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)
    }

    /// Reads every attachment once. A provider that fails is logged and skipped, never fatal.
    @MainActor
    private static func collect(from items: [NSExtensionItem]) async -> SharedContent {
        var texts: [String] = []
        var urls: [URL] = []
        var mails: [String] = []
        for item in items {
            if let text = item.attributedContentText?.string, !text.isEmpty {
                texts.append(text)
            }
            for provider in item.attachments ?? [] {
                do {
                    if provider.hasItemConformingToTypeIdentifier(UTType.emailMessage.identifier) {
                        let loaded = try await provider.loadItem(forTypeIdentifier: UTType.emailMessage.identifier)
                        if let raw = string(from: loaded) { mails.append(raw) }
                    } else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                        let loaded = try await provider.loadItem(forTypeIdentifier: UTType.url.identifier)
                        if let url = loaded as? URL { urls.append(url) }
                    } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                        let loaded = try await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier)
                        if let text = string(from: loaded) { texts.append(text) }
                    }
                } catch {
                    logger.error("Reading a shared item failed: \(error, privacy: .public)")
                }
            }
        }
        return SharedContent.make(texts: texts, urls: urls, mails: mails)
    }

    private static func string(from loaded: any NSSecureCoding) -> String? {
        if let text = loaded as? String { return text }
        if let attributed = loaded as? NSAttributedString { return attributed.string }
        if let data = loaded as? Data { return String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) }
        if let url = loaded as? URL, url.isFileURL {
            do {
                return try String(contentsOf: url, encoding: .utf8)
            } catch {
                logger.error("Reading a shared file failed: \(error, privacy: .public)")
            }
        }
        return nil
    }
}
