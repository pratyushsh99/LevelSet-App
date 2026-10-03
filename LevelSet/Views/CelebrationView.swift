import SwiftUI

struct CelebrationView: View {
    let offer: ChallengeOffer
    let progress: UserProgress
    let xpBefore: Int
    let nextOffer: ChallengeOffer?
    let onStartNext: (ChallengeOffer) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var badgePopped = false
    @State private var landed = false

    private var streakMessage: String {
        let milestones = [3, 7, 14, 30]
        if let next = milestones.first(where: { $0 > progress.currentStreak }) {
            return "Day \(progress.currentStreak) streak. \(next - progress.currentStreak) days to \(next)."
        }
        return "Day \(progress.currentStreak) streak — a new best."
    }

    var body: some View {
        ZStack {
            Theme.canvasSunken.ignoresSafeArea()
            if !reduceMotion {
                ConfettiView().offset(y: -80).allowsHitTesting(false)
            }

            ScrollView {
                VStack(spacing: 18) {
                    header

                    VStack(spacing: 12) {
                        rewardCard(
                            kicker: "time unlocked",
                            value: "+\(offer.unlockMinutes)m",
                            valueColor: Theme.accent400,
                            caption: "locks at \(progress.budgetEndDate.formatted(.dateTime.hour().minute())) now",
                            emphasized: true
                        )
                        rewardCard(
                            kicker: "xp earned",
                            value: "+\(offer.rewardXP) XP",
                            valueColor: Theme.text,
                            caption: "\(progress.xp) total",
                            emphasized: false
                        )
                    }

                    tierCard

                    Spacer()

                    VStack(spacing: 9) {
                        Button("Back to my apps") { dismiss() }
                            .buttonStyle(PrimaryButtonStyle())
                        if let nextOffer {
                            Button("One more · +\(nextOffer.unlockMinutes)m for \(nextOffer.kind.shortName.lowercased())") {
                                dismiss()
                                onStartNext(nextOffer)
                            }
                            .buttonStyle(SoftButtonStyle())
                        }
                    }
                }
                .padding(20)
                .padding(.top, 30)
            }
            .scrollIndicators(.hidden)
        }
        .sensoryFeedback(.success, trigger: landed)
        .onAppear {
            landed = true
            guard !reduceMotion else {
                badgePopped = true
                return
            }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) { badgePopped = true }
        }
    }

    private var header: some View {
        VStack(spacing: 5) {
            ZStack {
                Circle().fill(Theme.surfaceTint).frame(width: 74, height: 74)
                    .overlay(Circle().stroke(Theme.accent800, lineWidth: 1))
                    .shadow(color: Theme.accent.opacity(0.45), radius: 20)
                Image(systemName: "checkmark")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Theme.accent400)
            }
            .scaleEffect(badgePopped ? 1 : 0.4)
            .opacity(badgePopped ? 1 : 0)
            .padding(.bottom, 12)

            Text("\(offer.targetCount) of \(offer.targetCount). Done.")
                .font(Theme.display(32, .semibold))
                .foregroundStyle(Theme.text)
            Text(nextTargetHint)
                .font(Theme.body(12.5))
                .foregroundStyle(Theme.textFaint)
        }
    }

    private var nextTargetHint: String {
        "Your \(offer.kind.shortName.lowercased()) target rises next time."
    }

    private func rewardCard(kicker: String, value: String, valueColor: Color, caption: String, emphasized: Bool) -> some View {
        VStack(spacing: 5) {
            Text(kicker.uppercased())
                .font(Theme.microLabel)
                .tracking(0.7)
                .foregroundStyle(emphasized ? Theme.accent : Theme.textFaint)
            Text(value)
                .font(Theme.mono(26, .semibold))
                .foregroundStyle(valueColor)
            Text(caption)
                .font(Theme.body(10.5))
                .foregroundStyle(Theme.textFaint)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .card(emphasized: emphasized)
        .scaleEffect(badgePopped ? 1 : 0.7)
        .opacity(badgePopped ? 1 : 0)
        .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.6).delay(0.15), value: badgePopped)
    }

    private var tierCard: some View {
        let tier = progress.currentTier
        let oldFraction = progress.tierProgressFraction(for: xpBefore)
        let newFraction = progress.tierProgressFraction()

        return VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .lastTextBaseline) {
                Text("Tier \(progress.tierIndex + 1) · \(tier.name)")
                    .font(Theme.microLabel)
                    .tracking(0.7)
                    .foregroundStyle(Theme.textFaint)
                Spacer()
                if progress.nextTier != nil {
                    Text("\(progress.xpToNextTier) XP to \(progress.nextTier!.name)")
                        .font(Theme.mono(10.5, .medium))
                        .foregroundStyle(Theme.textFaint)
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.accent900)
                    Capsule().fill(Theme.accent700)
                        .frame(width: geo.size.width * oldFraction)
                    Capsule().fill(Theme.accent)
                        .shadow(color: Theme.accent.opacity(0.9), radius: 4)
                        .frame(width: geo.size.width * newFraction)
                        .mask(alignment: .trailing) {
                            Rectangle().frame(width: geo.size.width * max(0, newFraction - oldFraction))
                        }
                }
            }
            .frame(height: 4)
            Text(streakMessage)
                .font(Theme.body(10.5))
                .foregroundStyle(Theme.textMuted)
        }
        .card()
    }
}
