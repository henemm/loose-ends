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
                if let folder, let type = SharedAttachmentFile.attachmentType(registered: provider.registeredTypeIdentifiers) {
                    if let loaded = await attachment(from: provider, type: type, into: folder) {
                        attachments.append(loaded.attachment)
                        kind = loaded.kind
                    }
                } else if provider.hasItemConformingToTypeIdentifier(UTType.emailMessage.identifier) {
                    if let data = await data(from: provider, type: UTType.emailMessage.identifier) {
                        mails.append(SharedContent.decode(data))
                        kind = "data"
                    }
                } else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    if let url = await object(URL.self, from: provider, type: UTType.url.identifier) {
                        urls.append(url)
                        kind = url.isFileURL ? "file" : "url"
                    }
                } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    if let text = await object(String.self, from: provider, type: UTType.plainText.identifier) {
                        texts.append(text)
                        kind = "text"
                    } else if let data = await data(from: provider, type: UTType.plainText.identifier) {
                        texts.append(SharedContent.decode(data))
                        kind = "data"
                    }
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

    /// A link or a text as the class the provider hands out (#580, replaces `loadItem`). A failure is logged with
    /// domain and code only, never the content, and gives nil.
    @MainActor
    private static func object<T: _ObjectiveCBridgeable & Sendable>(
        _ kind: T.Type, from provider: NSItemProvider, type: String
    ) async -> T? where T._ObjectiveCType: NSItemProviderReading {
        do {
            return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<T, any Error>) in
                _ = provider.loadObject(ofClass: kind) { object, error in
                    if let object {
                        continuation.resume(returning: object)
                    } else {
                        continuation.resume(throwing: error ?? CocoaError(.fileReadUnknown))
                    }
                }
            }
        } catch {
            logFailure(error, type: type, step: "object")
            return nil
        }
    }

    /// The provider's bytes for `type` (a mail, or a text no class could take, #580); a file is read by the system.
    @MainActor
    private static func data(from provider: NSItemProvider, type: String) async -> Data? {
        do {
            return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, any Error>) in
                _ = provider.loadDataRepresentation(forTypeIdentifier: type) { data, error in
                    if let data {
                        continuation.resume(returning: data)
                    } else {
                        continuation.resume(throwing: error ?? CocoaError(.fileReadUnknown))
                    }
                }
            }
        } catch {
            logFailure(error, type: type, step: "data")
            return nil
        }
    }
}
