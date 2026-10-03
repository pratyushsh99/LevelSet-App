import SwiftUI

struct NotificationsStepView: View {
    let onFinish: () -> Void

    @State private var requesting = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 20)

                ZStack {
                    Circle().fill(Theme.accent900).frame(width: 84, height: 84)
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundStyle(Theme.accent400)
                }

                VStack(spacing: 8) {
                    Text("Stay ahead of the lock")
                        .font(Theme.display(24))
                        .foregroundStyle(Theme.heading)
                    Text("We'll give you a heads-up when you're close to today's screen-time limit, so there's time to start a challenge before apps lock.")
                        .font(Theme.body(14.5))
                        .foregroundStyle(Theme.textMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                }

                Spacer()

                VStack(spacing: 10) {
                    Button(requesting ? "Requesting…" : "Enable notifications") {
                        requesting = true
                        Task {
                            _ = await NotificationService.requestAuthorization()
                            onFinish()
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(requesting)

                    Button("Not now", action: onFinish)
                        .buttonStyle(SoftButtonStyle())
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
            }
            .padding(.vertical, 24)
        }
        .background(Theme.canvas)
    }
}
