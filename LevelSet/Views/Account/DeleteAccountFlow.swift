import SwiftUI

enum DeleteAccountConfirmationPhrase {
    static let text = "I request to delete my account"
}

struct DeleteAccountWarningView: View {
    let expectedName: String
    let onConfirmed: () -> Void

    var body: some View {
        List {
            Section {
                VStack(alignment: .center, spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.red)
                    Text("Delete your account?")
                        .font(.title2.bold())
                    Text("This permanently erases everything LevelSet has stored for this session. There is no undo, and nothing can be recovered afterward.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .listRowBackground(Color.clear)
            }

            Section("This will delete") {
                Label("Your XP, streak, and challenge history", systemImage: "chart.bar")
                Label("Your saved apps-to-limit selection", systemImage: "apps.iphone")
                Label("Your name and notification preference", systemImage: "person.crop.circle")
            }
            .foregroundStyle(.primary)

            Section {
                NavigationLink {
                    DeleteAccountNameStepView(expectedName: expectedName, onConfirmed: onConfirmed)
                } label: {
                    Text("Continue")
                        .foregroundStyle(.red)
                        .fontWeight(.semibold)
                }
            }
        }
        .navigationTitle("Delete Account")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DeleteAccountNameStepView: View {
    let expectedName: String
    let onConfirmed: () -> Void

    @State private var typedName = ""
    @FocusState private var focused: Bool

    private var matches: Bool {
        typedName.trimmingCharacters(in: .whitespacesAndNewlines)
            .caseInsensitiveCompare(expectedName) == .orderedSame
    }

    var body: some View {
        List {
            Section {
                Text("Type your name — **\(expectedName)** — to confirm it's you.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .listRowBackground(Color.clear)

            Section {
                TextField("Your name", text: $typedName)
                    .focused($focused)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
            }

            Section {
                NavigationLink {
                    DeleteAccountPhraseStepView(onConfirmed: onConfirmed)
                } label: {
                    Text("Continue")
                        .foregroundStyle(matches ? .red : .secondary)
                        .fontWeight(.semibold)
                }
                .disabled(!matches)
            }
        }
        .navigationTitle("Confirm Your Name")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { focused = true }
    }
}

struct DeleteAccountPhraseStepView: View {
    let onConfirmed: () -> Void

    @State private var typedPhrase = ""
    @State private var showFinalConfirmation = false
    @FocusState private var focused: Bool

    private var matches: Bool {
        typedPhrase.trimmingCharacters(in: .whitespacesAndNewlines) == DeleteAccountConfirmationPhrase.text
    }

    var body: some View {
        List {
            Section {
                Text("Type the following exactly, including capitalization:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(DeleteAccountConfirmationPhrase.text)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.semibold)
                    .textSelection(.enabled)
            }
            .listRowBackground(Color.clear)

            Section {
                TextField("Type the phrase above", text: $typedPhrase)
                    .focused($focused)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            Section {
                Button(role: .destructive) {
                    showFinalConfirmation = true
                } label: {
                    Text("Delete My Account")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .disabled(!matches)
            }
        }
        .navigationTitle("Final Confirmation")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { focused = true }
        .confirmationDialog(
            "This can't be undone",
            isPresented: $showFinalConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Permanently", role: .destructive, action: onConfirmed)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your XP, streaks, challenge history, and app selection will be permanently erased.")
        }
    }
}
