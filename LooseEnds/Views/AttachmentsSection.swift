import OSLog
import PhotosUI
import QuickLook
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// The attachments of the detail (#442): photos, files and scans (iPhone and iPad) on the task, a tap
/// shows them (Quick Look), a swipe deletes after asking. The bytes travel with iCloud as assets
/// (`TaskAttachment.data`).
struct AttachmentsSection: View {
    @Environment(\.modelContext) private var modelContext
    let task: TaskItem

    @State private var photoItem: PhotosPickerItem?
    @State private var importsFile = false
    @State private var preview: URL?
    @State private var pendingDelete: TaskAttachment?
    @State private var tooLarge = false
    @State private var scans = false
    private static let logger = Logger(subsystem: "com.henning.looseends", category: "Detail")

    private var attachments: [TaskAttachment] {
        (task.attachments ?? []).sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        Section {
            ForEach(attachments) { attachment in
                Button { show(attachment) } label: {
                    Label {
                        Text(attachment.fileName)
                            .font(.system(.body, design: .serif))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                    } icon: {
                        Image(systemName: AttachmentKind.symbol(for: attachment.typeIdentifier))
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .swipeActions {
                    Button("Delete", systemImage: "trash", role: .destructive) { pendingDelete = attachment }
                }
                .accessibilityIdentifier("attachment_\(attachment.id.uuidString)")
            }
            HStack(spacing: 20) {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label("Photo", systemImage: "photo")
                }
                .accessibilityIdentifier("addPhotoButton")
                Button("File", systemImage: "doc") { importsFile = true }
                    .accessibilityIdentifier("addFileButton")
                #if os(iOS)
                if DocumentScanner.isAvailable {
                    Button("Scan", systemImage: "doc.viewfinder") { scans = true }
                        .accessibilityIdentifier("scanDocumentButton")
                }
                #endif
            }
            .buttonStyle(.borderless)
        } header: {
            Text("Attachments").captionHead()
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task { await addPhoto(item) }
        }
        .fileImporter(isPresented: $importsFile, allowedContentTypes: [.item]) { result in
            switch result {
            case .success(let url): addFile(at: url)
            case .failure(let error): Self.logger.error("Choosing a file failed: \(error, privacy: .public)")
            }
        }
        .quickLookPreview($preview)
        #if os(iOS)
        .fullScreenCover(isPresented: $scans) {
            DocumentScanner { pages in
                scans = false
                addScan(pages)
            }
            .ignoresSafeArea()
        }
        #endif
        .confirmationDialog("Delete this attachment?", isPresented: Binding(
            get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }
        ), titleVisibility: .visible) {
            Button("Delete", role: .destructive) { deletePending() }
                .accessibilityIdentifier("confirmDeleteAttachment")
        }
        .alert("The file is too large (over 50 MB).", isPresented: $tooLarge) {
            Button("OK", role: .cancel) {}
        }
    }

    // MARK: - Adding

    private func addPhoto(_ item: PhotosPickerItem) async {
        defer { photoItem = nil }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { return }
            let type = item.supportedContentTypes.first ?? .jpeg
            let name = String(localized: "Photo") + " " + Date().formatted(date: .numeric, time: .shortened)
            add(data, fileName: name + "." + (type.preferredFilenameExtension ?? "jpg"), type: type)
        } catch {
            Self.logger.error("Loading the photo failed: \(error, privacy: .public)")
        }
    }

    private func addFile(at url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            let type = UTType(filenameExtension: url.pathExtension) ?? .data
            add(data, fileName: url.lastPathComponent, type: type)
        } catch {
            Self.logger.error("Reading the file failed: \(error, privacy: .public)")
        }
    }

    /// The scanned pages as one PDF; cancelling hands back no pages and adds nothing.
    private func addScan(_ pages: [CGImage]) {
        guard !pages.isEmpty else { return }
        guard let data = ScanPDF.pdf(from: pages) else { return }
        add(data, fileName: ScanPDF.fileName(at: Date(), prefix: String(localized: "Scan")), type: .pdf)
    }

    private func add(_ data: Data, fileName: String, type: UTType) {
        guard AttachmentKind.fits(data) else {
            tooLarge = true
            return
        }
        modelContext.insert(TaskAttachment(task: task, data: data, fileName: fileName, typeIdentifier: type.identifier))
        save("attachment")
    }

    // MARK: - Showing and deleting

    /// Quick Look needs a file: the bytes go to a temporary one named like the attachment.
    private func show(_ attachment: TaskAttachment) {
        guard let data = attachment.data else { return }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(attachment.id.uuidString, isDirectory: true)
        let file = folder.appendingPathComponent(attachment.fileName)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try data.write(to: file, options: .atomic)
            preview = file
        } catch {
            Self.logger.error("Preparing the preview failed: \(error, privacy: .public)")
        }
    }

    private func deletePending() {
        guard let attachment = pendingDelete else { return }
        pendingDelete = nil
        modelContext.delete(attachment)
        save("attachment delete")
    }

    private func save(_ what: String) {
        do {
            try modelContext.save()
        } catch {
            Self.logger.error("Saving \(what, privacy: .public) failed: \(error, privacy: .public)")
        }
    }
}
