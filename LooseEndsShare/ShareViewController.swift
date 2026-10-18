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

    /// The temp copies of shared files (#442); deleted before the request completes or is cancelled.
    private var attachmentFolder: URL?

    private func present() async {
        let items = (extensionContext?.inputItems as? [NSExtensionItem]) ?? []
        do {
            attachmentFolder = try SharedAttachmentFile.makeDirectory()
        } catch {
            Self.logger.error("Creating the attachment folder failed: \(error, privacy: .public)")
        }
        let content = await Self.collect(from: items, into: attachmentFolder)
        let form = ShareCaptureView(
            content: content,
            finish: { [weak self] in
                self?.removeAttachments()
                self?.extensionContext?.completeRequest(returningItems: nil)
            },
            cancel: { [weak self] in
                self?.removeAttachments()
                self?.extensionContext?.cancelRequest(withError: CocoaError(.userCancelled))
            }
        )
        let host = UIHostingController(rootView: form)
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)
    }

    private func removeAttachments() {
        if let attachmentFolder { SharedAttachmentFile.remove(attachmentFolder) }
        attachmentFolder = nil
    }

    /// Reads every attachment once, one after the other (little memory). A provider that fails is logged and
    /// skipped, never fatal. Photos and files are copied into `folder`; text, links and mails as before.
    @MainActor
    private static func collect(from items: [NSExtensionItem], into folder: URL?) async -> SharedContent {
        var texts: [String] = []
        var urls: [URL] = []
        var mails: [String] = []
        var attachments: [SharedAttachment] = []
        for item in items {
            if let text = item.attributedContentText?.string, !text.isEmpty {
                texts.append(text)
            }
            for provider in item.attachments ?? [] {
                var kind: String?
                do {
                    if let folder, let type = SharedAttachmentFile.attachmentType(registered: provider.registeredTypeIdentifiers) {
                        if let loaded = await attachment(from: provider, type: type, into: folder) {
                            attachments.append(loaded.attachment)
                            kind = loaded.kind
                        }
                    } else if provider.hasItemConformingToTypeIdentifier(UTType.emailMessage.identifier) {
                        let loaded = try await provider.loadItem(forTypeIdentifier: UTType.emailMessage.identifier)
                        kind = loadedKind(loaded, branch: "mail")
                        if let raw = string(from: loaded) { mails.append(raw) }
                    } else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                        let loaded = try await provider.loadItem(forTypeIdentifier: UTType.url.identifier)
                        kind = loadedKind(loaded, branch: "url")
                        if let url = loaded as? URL { urls.append(url) }
                    } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                        let loaded = try await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier)
                        kind = loadedKind(loaded, branch: "text")
                        if let text = string(from: loaded) { texts.append(text) }
                    }
                } catch {
                    logger.error("Reading a shared item failed: \(error, privacy: .public)")
                }
                // #24 AC-1: type identifiers and the loaded kind only, never the content.
                let line = SharedContent.probeLine(typeIdentifiers: provider.registeredTypeIdentifiers, loaded: kind)
                logger.info("\(line, privacy: .public)")
            }
        }
        return SharedContent.make(texts: texts, urls: urls, mails: mails,
                                  attachments: SharedAttachment.classify(attachments))
    }

    private typealias Adoption = CheckedContinuation<SharedAttachment, any Error>

    /// The provider's file, copied inside the handler (it is gone afterwards); else its data, written straight
    /// to a temp file and copied the same way. Failures are logged with the type only, never a name.
    @MainActor
    private static func attachment(from provider: NSItemProvider, type: String,
                                   into folder: URL) async -> (attachment: SharedAttachment, kind: String)? {
        let name = provider.suggestedName
        let prefix = String(localized: "Photo")
        let date = Date.now
        do {
            let adopted = try await withCheckedThrowingContinuation { (continuation: Adoption) in
                _ = provider.loadFileRepresentation(forTypeIdentifier: type) { url, error in
                    guard let url else {
                        continuation.resume(throwing: error ?? CocoaError(.fileReadUnknown))
                        return
                    }
                    continuation.resume(with: Result<SharedAttachment, any Error> {
                        try SharedAttachmentFile.adopt(url, typeIdentifier: type, suggestedName: name,
                                                       into: folder, at: date, photoPrefix: prefix)
                    })
                }
            }
            return (adopted, "file")
        } catch {
            logFailure(error, type: type, step: "file")
        }
        do {
            let adopted = try await withCheckedThrowingContinuation { (continuation: Adoption) in
                _ = provider.loadDataRepresentation(forTypeIdentifier: type) { data, error in
                    guard let data else {
                        continuation.resume(throwing: error ?? CocoaError(.fileReadUnknown))
                        return
                    }
                    let staged = folder.appendingPathComponent("staged-\(UUID().uuidString)")
                    defer { SharedAttachmentFile.remove(staged) }
                    continuation.resume(with: Result<SharedAttachment, any Error> {
                        try data.write(to: staged)
                        return try SharedAttachmentFile.adopt(staged, typeIdentifier: type, suggestedName: name,
                                                              into: folder, at: date, photoPrefix: prefix)
                    })
                }
            }
            return (adopted, "data")
        } catch {
            logFailure(error, type: type, step: "data")
            return nil
        }
    }

    private static func logFailure(_ error: any Error, type: String, step: String) {
        let error = error as NSError
        logger.error("Shared \(step, privacy: .public) failed: type=\(type, privacy: .public) \(error.domain, privacy: .public) \(error.code, privacy: .public)")
    }

    /// What an attachment delivered: raw `data`, a `file`, or else the branch's own kind (#24).
    private static func loadedKind(_ loaded: any NSSecureCoding, branch: String) -> String {
        if loaded is Data { return "data" }
        if let url = loaded as? URL, url.isFileURL { return "file" }
        return branch
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
