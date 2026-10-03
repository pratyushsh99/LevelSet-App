import SwiftUI

struct LockScreenView: View {
    let progress: UserProgress
    let history: [ChallengeCompletion]
    let onChooseChallenge: () -> Void
    let onUseXPInstead: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var bounce = 0

    private let lockedApps = [
        ("Instagram", "camera.fill"),
        ("TikTok", "music.note"),
        ("YouTube", "play.rectangle.fill"),
        ("Safari", "safari.fill"),
    ]

    private var bestOffer: ChallengeOffer? {
        ChallengeEngine.bestReturn(among: ChallengeEngine.makeOffers(recentHistory: history))
    }

    private var xpReward: RedeemableReward? {
        redeemableCatalog.first { if case .screenTimeMinutes = $0.kind { return true }; return false }
    }

    var body: some View {
        ZStack {
            Theme.lockGround.ignoresSafeArea()
            haloBackground

            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: 24)

                    statusChip
                        .padding(.bottom, 24)

                    VStack(spacing: 7) {
                        IconTile(systemImage: "lock.fill", size: 60, radius: 16, glow: true)
                        Text("\(progress.xp) XP available to spend.")
                            .font(Theme.mono(14, .semibold))
                            .foregroundStyle(Theme.accent400)
                        Text("Your time is up.")
                            .font(.system(size: 26, weight: .medium))
                            .foregroundStyle(Theme.text)
                        Text("These apps are closed until you complete exercises for more time.")
                            .font(Theme.body(13))
                            .foregroundStyle(Theme.textMuted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 22)
                    }

                    HStack(spacing: 16) {
                        ForEach(Array(lockedApps.enumerated()), id: \.element.0) { index, app in
                            lockedTile(name: app.0, symbol: app.1, index: index)
                        }
                    }
                    .padding(.top, 28)

                    Color.clear.frame(height: 32)

                    VStack(spacing: 12) {
                        if let bestOffer {
                            fastestWayBackCard(bestOffer)
                        }
                        Button("Choose a challenge", action: onChooseChallenge)
                            .buttonStyle(PrimaryButtonStyle())
                        if let xpReward {
                            Button("Spend \(xpReward.costXP) XP for \(minutesFor(xpReward)) min", action: onUseXPInstead)
                                .buttonStyle(SoftButtonStyle())
                        }
                    }
                    .padding(.bottom, 20)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)
                }
                .padding(.horizontal, 22)
            }
            .scrollIndicators(.hidden)
        }
        .onAppear {
            bounce += 1
            guard !reduceMotion else {
                appeared = true
                return
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.25)) {
                appeared = true
            }
        }
    }

    private var statusChip: some View {
        HStack(spacing: 7) {
            Image(systemName: "leaf.fill")
                .font(Theme.body(11))
                .foregroundStyle(Theme.accent400)
            Text("Time Limit Passed")
                .font(Theme.mono(13, .medium))
                .tracking(0.5)
                .foregroundStyle(Theme.accent400)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 5)
        .background(Theme.surfaceTint.opacity(0.7), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Theme.accent800, lineWidth: 1))
    }

    private var haloBackground: some View {
        RadialGradient(
            colors: [Theme.accent.opacity(0.18), .clear],
            center: .top,
            startRadius: 10,
            endRadius: 420
        )
        .ignoresSafeArea()
    }

    private func lockedTile(name: String, symbol: String, index: Int) -> some View {
        VStack(spacing: 7) {
            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(Theme.surface.opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .stroke(Theme.hairline, lineWidth: 1)
                    )
                    .frame(width: 54, height: 54)
                    .overlay(
                        Image(systemName: symbol)
                            .font(.system(size: 20))
                            .foregroundStyle(Theme.neutral700)
                    )

                Image(systemName: "lock.fill")
                    .font(Theme.body(9, .bold))
                    .foregroundStyle(Theme.accent400)
                    .padding(4)
                    .background(Theme.surfaceTint, in: Circle())
                    .overlay(Circle().stroke(Theme.accent800, lineWidth: 1))
                    .offset(x: 3, y: 3)
            }
            Text(name)
                .font(Theme.body(9.5))
                .foregroundStyle(Theme.textFaint)
        }
        .staggered(index + 1)
    }

    private func fastestWayBackCard(_ offer: ChallengeOffer) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            MicroLabel(text: "Fastest way back")
            HStack(spacing: 11) {
                IconTile(systemImage: offer.kind.glyph, size: 36)
                VStack(alignment: .leading, spacing: 1) {
                    Text(offer.kind.shortName)
                        .font(Theme.body(14, .medium))
                        .foregroundStyle(Theme.text)
                    Text(offer.subtitle)
                        .font(Theme.body(10.5))
                        .foregroundStyle(Theme.textFaint)
                }
                Spacer(minLength: 6)
                VStack(alignment: .trailing, spacing: 1) {
                    Text("+\(offer.unlockMinutes)m")
                        .font(Theme.mono(14, .semibold))
                        .foregroundStyle(Theme.accent400)
                    Text("+\(offer.rewardXP) XP")
                        .font(Theme.mono(9.5, .medium))
                        .foregroundStyle(Theme.textFaint)
                }
            }
        }
        .card()
    }

    private func minutesFor(_ reward: RedeemableReward) -> Int {
        if case .screenTimeMinutes(let minutes) = reward.kind { return minutes }
        return 0
    }
}
