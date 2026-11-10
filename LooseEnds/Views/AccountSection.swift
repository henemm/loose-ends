import AuthenticationServices
import OSLog
import SwiftUI

/// The rows of the settings group "Claude" (#615 S4c-1): signing in with Apple, out, and deleting the account after a
/// question. Every decision comes from `layout(status:problem:)`; the view only draws it. Nothing is sent before a tap.
struct AccountSection: View {
    /// One case per hint sentence under the group.
    enum Hint: Equatable, Sendable { case intro, signedIn, notAllowed, retryLater }

    struct Layout: Equatable, Sendable {
        let showsAppleButton: Bool
        /// False wherever the button is hidden, and while a sign-in runs (#615 S4c-2b): the button stays in the
        /// hierarchy so Apple's dialog keeps its answer, but a second tap cannot start a second sign-in.
        let appleButtonEnabled: Bool
        let showsProgress: Bool
        let showsSignedInRows: Bool
        let hint: Hint
    }

    /// Status to rows. While a request runs (`signingIn`, `deleting`) nothing can be tapped a second time.
    static func layout(status: AccountState.Status, problem: AccountState.Problem?) -> Layout {
        switch status {
        case .signedOut:
            Layout(showsAppleButton: true, appleButtonEnabled: true, showsProgress: false, showsSignedInRows: false,
                   hint: .intro)
        case .signingIn:
            Layout(showsAppleButton: true, appleButtonEnabled: false, showsProgress: true, showsSignedInRows: false,
                   hint: .intro)
        case .signedIn:
            Layout(showsAppleButton: false, appleButtonEnabled: false, showsProgress: false, showsSignedInRows: true,
                   hint: problem == .retryLater ? .retryLater : .signedIn)
        case .deleting:
            Layout(showsAppleButton: false, appleButtonEnabled: false, showsProgress: true, showsSignedInRows: false,
                   hint: .signedIn)
        case .notAllowed:
            Layout(showsAppleButton: true, appleButtonEnabled: true, showsProgress: false, showsSignedInRows: false,
                   hint: .notAllowed)
        case .retryLater:
            Layout(showsAppleButton: true, appleButtonEnabled: true, showsProgress: false, showsSignedInRows: false,
                   hint: .retryLater)
        }
    }

    /// The sentence under the group; the Mac says "this Mac" where iPhone and iPad say "this device".
    static func hintText(_ hint: Hint) -> Text {
        switch hint {
        #if os(macOS)
        case .intro:
            Text("Sign in with Apple so Claude can read your open tasks and add new ones. Without signing in, nothing leaves this Mac.")
        case .signedIn:
            Text("Claude sees your open tasks. Signing out disconnects only this Mac. Deleting the account removes everything the service keeps of yours for Claude.")
        #else
        case .intro:
            Text("Sign in with Apple so Claude can read your open tasks and add new ones. Without signing in, nothing leaves this device.")
        case .signedIn:
            Text("Claude sees your open tasks. Signing out disconnects only this device. Deleting the account removes everything the service keeps of yours for Claude.")
        #endif
        case .notAllowed: Text("This Apple account is not yet cleared for Claude.")
        case .retryLater: Text("The service can't be reached right now. Try again later.")
        }
    }

    private static let logger = Logger(subsystem: "com.henning.looseends", category: "account")

    let account: AccountState
    @State private var confirmsDelete = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let layout = Self.layout(status: account.status, problem: account.lastProblem)
        if layout.showsAppleButton {
            signInRow(enabled: layout.appleButtonEnabled)
        }
        if layout.showsProgress {
            progressRow
        }
        if layout.showsSignedInRows {
            signedInRows
        }
    }

    // MARK: - Rows

    @ViewBuilder private func signInRow(enabled: Bool) -> some View {
        #if os(macOS)
        HStack {
            Text("Connect with Claude")
            Spacer()
            appleButton(enabled: enabled).frame(width: 200)
        }
        #else
        appleButton(enabled: enabled)
        #endif
    }

    private var progressRow: some View {
        HStack(spacing: 8) {
            ProgressView()
            if account.status == .deleting {
                Text("Deleting account …").foregroundStyle(.secondary)
            } else {
                Text("Signing in …").foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("accountProgressRow")
    }

    @ViewBuilder private var signedInRows: some View {
        #if os(macOS)
        let place: LocalizedStringKey = "This Mac"
        #else
        let place: LocalizedStringKey = "This device"
        #endif
        LabeledContent("Signed in with Apple") {
            Text(place)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("accountSignedInRow")
        Button {
            Task { await account.signOut() }
        } label: {
            Text("Sign out").foregroundStyle(.tint)
        }
        .accessibilityIdentifier("accountSignOutRow")
        Button {
            confirmsDelete = true
        } label: {
            Text("Delete account …").foregroundStyle(.tint)
        }
        .accessibilityIdentifier("accountDeleteRow")
        .confirmationDialog("Delete account?", isPresented: $confirmsDelete, titleVisibility: .visible) {
            Button("Delete account", role: .destructive) {
                Task { await account.deleteAccount() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Claude will no longer see your tasks. Your tasks in the app stay as they are.")
        }
    }

    // MARK: - Apple

    /// Apple's own button; under `--ui-testing` a plain button against the stand-in service, because the Apple dialog
    /// does not run reliably in the Simulator.
    @ViewBuilder private func appleButton(enabled: Bool) -> some View {
        if ModelContainerFactory.isUITesting {
            Button {
                Task { await signInForUITest() }
            } label: {
                Label("Sign in with Apple", systemImage: "apple.logo")
            }
            .disabled(!enabled)
            .accessibilityIdentifier("accountAppleButton")
        } else {
            SignInWithAppleButton(.signIn, onRequest: request, onCompletion: complete)
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: 44)
                .disabled(!enabled)
                .accessibilityIdentifier("accountAppleButton")
        }
    }

    private func signInForUITest() async {
        do {
            _ = try account.beginSignIn()
        } catch {
            Self.logger.error("sign-in not started: \(String(describing: type(of: error)), privacy: .public)")
            return
        }
        await account.completeSignIn(identityToken: "UITEST-IDENTITY", code: "UITEST-CODE")
    }

    /// No scopes: the service needs neither name nor mail. Only the hashed nonce goes to Apple.
    private func request(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = []
        do {
            request.nonce = try account.beginSignIn()
        } catch {
            Self.logger.error("sign-in not started: \(String(describing: type(of: error)), privacy: .public)")
        }
    }

    /// Token and code as text to the service; anything missing, a failure or the user's cancel drops the sign-in.
    private func complete(_ result: Result<ASAuthorization, any Error>) {
        guard case .success(let authorization) = result,
              let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken, let token = String(data: tokenData, encoding: .utf8),
              let codeData = credential.authorizationCode, let code = String(data: codeData, encoding: .utf8) else {
            if case .failure(let error) = result {
                Self.logger.info("apple sign-in ended: \(String(describing: type(of: error)), privacy: .public)")
            }
            account.cancelSignIn()
            return
        }
        Task { await account.completeSignIn(identityToken: token, code: code) }
    }
}
