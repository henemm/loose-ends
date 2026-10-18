import OSLog
import SwiftData
import SwiftUI

/// The capture form inside the share sheet: the text field prefilled with the subject or the
/// shared text, the source link shown underneath, one button. Same store, same rules as the app.
struct ShareCaptureView: View {
    let content: SharedContent
    let finish: () -> Void
    let cancel: () -> Void

    @State private var text: String
    @State private var saveFailed = false
    @FocusState private var isFocused: Bool
    private static let logger = Logger(subsystem: "com.henning.looseends", category: "Share")

    init(content: SharedContent, finish: @escaping () -> Void, cancel: @escaping () -> Void) {
        self.content = content
        self.finish = finish
        self.cancel = cancel
        _text = State(initialValue: content.prefill)
    }

    private var canSave: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("What should I remember?", text: $text, axis: .vertical)
                    .lineLimit(3...8)
                    .focused($isFocused)
                if let url = content.sourceURL {
                    Label(url.absoluteString, systemImage: content.channel == .mail ? "envelope" : "link")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if !content.attachments.isEmpty {
                    Section("Attachments") {
                        ForEach(Array(content.attachments.enumerated()), id: \.offset) { _, attachment in
                            ShareAttachmentRow(attachment: attachment)
                        }
                    }
                }
            }
            .navigationTitle("Capture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel, action: cancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: save)
                        .disabled(!canSave)
                }
            }
            .alert("Could not save", isPresented: $saveFailed) {
                Button("OK") {}
            }
        }
        .onAppear { isFocused = content.prefill.isEmpty }
    }

    /// The container stays alive for the whole save; a context outlives its container only on paper.
    private func save() {
        guard canSave else { return }
        do {
            let container = try ModelContainerFactory.make()
            let context = ModelContext(container)
            try CaptureService.save(text, via: content.channel, sourceURL: content.sourceURL,
                                    attachments: content.attachments, in: context)
            finish()
        } catch {
            Self.logger.error("Share capture failed: \(error, privacy: .public)")
            saveFailed = true
        }
    }
}

/// One shared photo or file (#442, design A): symbol, name, size. What is not attached says why, in grey.
private struct ShareAttachmentRow: View {
    let attachment: SharedAttachment

    var body: some View {
        HStack {
            Label(attachment.fileName, systemImage: AttachmentKind.symbol(for: attachment.typeIdentifier))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            Text(detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }

    private var detail: String {
        switch attachment.status {
        case .ready: ByteCountFormatter.string(fromByteCount: Int64(attachment.byteCount), countStyle: .file)
        case .tooLarge: String(localized: "Too large (max. 50 MB) – not attached")
        case .overLimit: String(localized: "More than 10 – not attached")
        }
    }
}
