import SwiftUI

struct WelcomeStepView: View {
    @Binding var name: String
    let onContinue: () -> Void

    @FocusState private var focused: Bool

    private let checklist: [(number: String, icon: String, label: String)] = [
        ("02", "doc.text", "Terms and privacy"),
        ("03", "iphone", "Pick the apps to limit"),
        ("04", "bell", "Turn on the low-time warning"),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                HStack(spacing: 5) {
                    Capsule().fill(Theme.accent).frame(height: 2)
                    Capsule().fill(Theme.hairline).frame(height: 2)
                    Capsule().fill(Theme.hairline).frame(height: 2)
                    Capsule().fill(Theme.hairline).frame(height: 2)
                }
                .padding(.top, 10)

                MicroLabel(text: "Step 1 of 4 · your name")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 9)

                VStack(alignment: .leading, spacing: 0) {
                    IconTile(systemImage: "leaf.fill", size: 64, radius: 16, glow: true)
                        .padding(.top, 46)

                    Text("Trade effort\nfor time.")
                        .font(Theme.display(34, .semibold))
                        .foregroundStyle(Theme.text)
                        .lineSpacing(2)
                        .padding(.top, 22)

                    Text("Build a little movement into your day. Complete exercise challenges to earn more screen time, one small win at a time.")
                        .font(Theme.body(14))
                        .foregroundStyle(Theme.textMuted)
                        .lineSpacing(3)
                        .padding(.top, 12)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 5) {
                    Text("What should we call you?")
                        .font(Theme.body(11))
                        .foregroundStyle(Theme.textMuted)
                    TextField("Your name", text: $name)
                        .focused($focused)
                        .font(Theme.body(16, .medium))
                        .padding(.vertical, 13)
                        .padding(.horizontal, 14)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(focused ? Theme.accent : Theme.hairline, lineWidth: focused ? 1.5 : 1)
                        )
                        .textContentType(.givenName)
                        .textInputAutocapitalization(.words)
                        .foregroundStyle(Theme.text)
                        .submitLabel(.done)
                        .onSubmit(onContinue)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 30)

                VStack(alignment: .leading, spacing: 9) {
                    MicroLabel(text: "Set-up checklist")
                    VStack(alignment: .leading, spacing: 7) {
                        ForEach(checklist, id: \.number) { item in
                            HStack(spacing: 9) {
                                Text(item.number)
                                    .font(Theme.mono(10, .medium))
                                    .foregroundStyle(Theme.neutral700)
                                Image(systemName: item.icon)
                                    .font(Theme.body(13))
                                    .foregroundStyle(Theme.textFaint)
                                Text(item.label)
                                    .font(Theme.body(11.5))
                                    .foregroundStyle(Theme.textMuted)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .card(padding: 13)
                .padding(.top, 26)

                VStack(spacing: 9) {
                    Button {
                        onContinue()
                    } label: {
                        HStack(spacing: 7) {
                            Text("Continue")
                            Image(systemName: "arrow.right")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    Button("Prefer not to say") {
                        name = ""
                        onContinue()
                    }
                    .buttonStyle(SoftButtonStyle(tint: Theme.textFaint, borderColor: .clear))
                }
                .padding(.top, 11)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 20)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.canvas)
    }
}
