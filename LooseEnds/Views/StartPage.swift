import OSLog
import SwiftData
import SwiftUI

/// The date under the knot and the one sentence of the day (#426). The iPhone start list and the
/// wide start page (#408) show the same two lines.
struct StartHeader: View {
    let tasks: [TaskItem]
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let metrics = StartMetrics(typeSize)
        // Once a minute, so the line turns to the look back at 16:00 without a save (#426).
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    // The knot, first of its three places (#180, rule 1). Grey like the date: it is
                    // the mark, not something to tap (ADR-14).
                    ThreadGlyph(form: .knot, lineWidth: 1.5)
                        .frame(width: metrics(30), height: metrics(16))
                    Text(timeline.date, format: .dateTime.weekday(.wide).day().month(.wide))
                        .font(metrics.caption)
                        .textCase(.uppercase)
                        .tracking(metrics.captionTracking)
                }
                .foregroundStyle(.secondary)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("startHeader")
                // The one fact that stands out today, from 16:00 a look back (#426). Content, so New York.
                Text(StartHeadlineText.sentence(StartHeadline.of(tasks, now: timeline.date)))
                    .font(metrics.headline)
                    .tracking(-0.3)
                    .lineSpacing(0)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("startHeadline")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// What the wide window shows while no view is chosen (#408, draft "Papier und Faden", cut 1): the
/// sentence of the day, a field to say something, and "Now". iPad in a wide window and the Mac;
/// the iPhone opens its start list instead.
struct StartPage: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var typeSize
    @Binding var selection: ViewSelection?
    let tasks: [TaskItem]
    @State private var text = ""
    @State private var saveFailed = false
    private static let logger = Logger(subsystem: "com.henning.looseends", category: "StartPage")

    var body: some View {
        let metrics = StartMetrics(typeSize)
        List {
            StartHeader(tasks: tasks)
                .padding(.top, 14)
                .padding(.bottom, 16)
                .listRowSeparator(.hidden)
                .startRow(metrics)
                .paperRow()
            captureField
                .padding(.bottom, 8)
                .listRowSeparator(.hidden)
                .startRow(metrics)
                .paperRow()
            NowBlock(tasks: ViewRules.now(in: tasks).all) { task in
                Button { selection = .task(task.id) } label: {
                    TaskRow(task: task, identifierPrefix: "startNowRow_")
                        .padding(.vertical, 11)
                        .environment(\.startMetrics, metrics)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .startRow(metrics)
                .paperRow()
            }
        }
        .listStyle(.plain)
        .paperGround()
        .frame(maxWidth: 720)
        .frame(maxWidth: .infinity)
        // The paper runs edge to edge: outside the 720 pt column the window showed white bars (build 71).
        .background(Paper.ground.ignoresSafeArea())
        .accessibilityIdentifier("startPage")
    }

    /// Saving is the same write path as the capture sheet; the text is kept as typed (ADR-3).
    private var captureField: some View {
        TextField("What should I remember?", text: $text)
            .textFieldStyle(.plain)
            .font(StartMetrics(typeSize).rowTitle)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(.background, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.separator))
            .onSubmit(save)
            .submitLabel(.done)
            .accessibilityIdentifier("startCaptureField")
            .alert("Could not save", isPresented: $saveFailed) {
                Button("OK") {}
            }
    }

    private func save() {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        do {
            try CaptureService.save(text, via: .app, in: modelContext)
            text = ""
        } catch {
            Self.logger.error("Capture from the start page failed: \(error, privacy: .public)")
            saveFailed = true
        }
    }
}
