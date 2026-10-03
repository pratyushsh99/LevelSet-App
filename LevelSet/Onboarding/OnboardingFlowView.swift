import SwiftUI

struct OnboardingFlowView: View {
    let progress: UserProgress
    let onComplete: () -> Void

    private enum Step: Int { case welcome, legal, notifications }

    @State private var step: Step = .welcome
    @State private var name = ""

    var body: some View {
        Group {
            switch step {
            case .welcome:
                WelcomeStepView(name: $name) {
                    progress.displayName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    advance(to: .legal)
                }
            case .legal:
                LegalStepView { advance(to: .notifications) }
            case .notifications:
                NotificationsStepView {
                    progress.notificationsEnabled = true
                    progress.hasCompletedOnboarding = true
                    onComplete()
                }
            }
        }
        .transition(.opacity.combined(with: .move(edge: .trailing)))
        .animation(.easeInOut(duration: 0.3), value: step)
    }

    private func advance(to next: Step) {
        step = next
    }
}
