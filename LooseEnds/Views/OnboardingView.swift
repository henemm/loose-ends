import SwiftData
import SwiftUI

/// The onboarding (design briefing, screen 12, #29): Siri, notifications, the starter contexts, each
/// skippable, and "Skip" ends it all.
/// Calm and short, like the rest of the app: it shows, it does not explain itself.
struct OnboardingView: View {
    @Query(sort: \TaskContext.sortOrder) private var contexts: [TaskContext]
    @State private var flow = OnboardingFlow()
    let requestNotifications: () async -> Void
    let onFinish: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
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
                Text("Say “Capture in Loose Ends” to Siri. Or add the Shortcuts control with “Capture a task” to Control Center. Both save without opening the app.")
            }
        case .notifications:
            page(symbol: "bell", title: "One reminder on the day") {
                Text("At nine in the morning, what is due today. Complete, Next up or Tomorrow straight from the notification.")
            }
        case .contexts:
            page(symbol: "tag", title: "Where things get done") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("These tags come with the app. Rename, delete or add your own on the start screen.")
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
