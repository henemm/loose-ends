import SwiftData
import SwiftUI

/// The onboarding (design briefing, screen 12, #29): Siri, notifications, the starter contexts, each
/// skippable, and "Skip" ends it all. Over the first step, a note when Apple Intelligence is not there.
/// Calm and short, like the rest of the app: it shows, it does not explain itself.
struct OnboardingView: View {
    @Query(sort: \TaskContext.sortOrder) private var contexts: [TaskContext]
    @State private var flow = OnboardingFlow()
    /// Why the model cannot run, nil when it can (`FoundationModelsEnricher.unavailableReason`).
    let modelUnavailableReason: String?
    let requestNotifications: () async -> Void
    let onFinish: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                if flow.step == .siri, let note = OnboardingFlow.modelNote(for: modelUnavailableReason) {
                    modelNote(note)
                }
                stepContent
                Spacer(minLength: 0)
                buttons
            }
            .padding(24)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Paper.ground)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip", action: onFinish)
                        .accessibilityIdentifier("onboardingSkipButton")
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 420)
        #endif
    }

    @ViewBuilder
    private var stepContent: some View {
        switch flow.step {
        case .siri:
            page(symbol: "mic", title: "Capture without opening the app") {
                Text("Say “Add to Loose Ends” to Siri. Control Center and the Action Button open the capture right away.")
            }
        case .notifications:
            page(symbol: "bell", title: "One reminder on the day") {
                Text("At nine in the morning, what is due today. Complete, Next up or Tomorrow straight from the notification.")
            }
        case .contexts:
            page(symbol: "tag", title: "Where things get done") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("These contexts come with the app. Rename, delete or add your own on the start screen.")
                    Text(contexts.map(\.name).formatted(.list(type: .and)))
                        .fontDesign(.serif)
                        .accessibilityIdentifier("onboardingContexts")
                }
            }
        }
    }

    private func page<Body: View>(symbol: String, title: LocalizedStringKey, @ViewBuilder text: () -> Body) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: symbol)
                .font(.largeTitle)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(title)
                .font(.title2.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("onboardingStepTitle")
            text()
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("onboardingStep_\(String(describing: flow.step))")
    }

    @ViewBuilder
    private func modelNote(_ note: OnboardingFlow.ModelNote) -> some View {
        Group {
            switch note {
            case .turnedOff:
                Text("Apple Intelligence is off. Turn it on in Settings so new tasks get a title and a duration.")
            case .notReady:
                Text("Apple Intelligence is still getting ready. Tasks captured meanwhile are sorted once it is.")
            case .notEligible:
                Text("This device has no Apple Intelligence. Tasks keep the words you said; due dates, importance and urgency are still found.")
            }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .accessibilityIdentifier("onboardingModelNote")
    }

    @ViewBuilder
    private var buttons: some View {
        VStack(spacing: 12) {
            switch flow.step {
            case .notifications:
                Button {
                    Task {
                        await requestNotifications()
                        next()
                    }
                } label: {
                    Text("Allow notifications").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("onboardingAllowNotifications")
                Button("Not now", action: next)
                    .accessibilityIdentifier("onboardingNextButton")
            case .siri, .contexts:
                Button(action: next) {
                    Text(flow.isLastStep ? LocalizedStringKey("Start") : LocalizedStringKey("Continue")).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("onboardingNextButton")
            }
        }
        .controlSize(.large)
    }

    private func next() {
        if !flow.advance() { onFinish() }
    }
}
