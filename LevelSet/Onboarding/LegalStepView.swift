import SwiftUI

struct LegalStepView: View {
    let onContinue: () -> Void

    @State private var agreed = false
    @State private var showingDocument: LegalDocument?

    private enum LegalDocument: Identifiable {
        case privacy, terms
        var id: Self { self }
        var title: String { self == .privacy ? "Privacy Policy" : "Terms of Service" }
        var filename: String { self == .privacy ? "PrivacyPolicy.txt" : "TermsOfService.txt" }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 20)

                Image(systemName: "doc.text.fill")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(Theme.accent400)

                VStack(spacing: 8) {
                    Text("Before we get started")
                        .font(Theme.display(24))
                        .foregroundStyle(Theme.heading)
                    Text("Quick agreement, then we're moving.")
                        .font(Theme.body(14.5))
                        .foregroundStyle(Theme.textMuted)
                }

                VStack(alignment: .leading, spacing: 14) {
                    Button { showingDocument = .privacy } label: {
                        linkRow(title: "Privacy Policy")
                    }
                    Button { showingDocument = .terms } label: {
                        linkRow(title: "Terms of Service")
                    }

                    Divider().padding(.vertical, 2)

                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { agreed.toggle() }
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: agreed ? "checkmark.square.fill" : "square")
                                .font(.system(size: 20))
                                .foregroundStyle(agreed ? Theme.accent400 : Theme.textFaint)
                            Text("I agree to the Privacy Policy and Terms of Service")
                                .font(Theme.body(13.5))
                                .foregroundStyle(Theme.text)
                                .multilineTextAlignment(.leading)
                        }
                    }
                }
                .card()
                .padding(.horizontal, 24)

                Spacer()

                Button("Continue", action: onContinue)
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!agreed)

                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)
            }
            .padding(.vertical, 24)
        }
        .background(Theme.canvas)
        .sheet(item: $showingDocument) { doc in
            LegalDocumentView(title: doc.title, filename: doc.filename)
        }
    }

    private func linkRow(title: String) -> some View {
        HStack {
            Text(title)
                .font(Theme.body(14.5, .semibold))
                .foregroundStyle(Theme.accent)
                .underline()
            Spacer()
            Image(systemName: "arrow.up.right")
                .font(Theme.body(12, .semibold))
                .foregroundStyle(Theme.accent)
        }
    }
}
