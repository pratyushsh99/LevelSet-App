import SwiftUI

struct RedeemView: View {
    @Bindable var progress: UserProgress
    let history: [ChallengeCompletion]

    @State private var toastMessage: String?
    @State private var redeemPulse = 0

    private var screenTimeRewards: [RedeemableReward] {
        redeemableCatalog.filter {
            if case .screenTimeMinutes = $0.kind { return true }
            return false
        }
    }

    private var otherRewards: [RedeemableReward] {
        redeemableCatalog.filter {
            if case .screenTimeMinutes = $0.kind { return false }
            return true
        }
    }

    private var succeeded: [ChallengeCompletion] { history.filter(\.succeeded) }

    private var xpEarnedToday: Int {
        succeeded.filter { Calendar.current.isDateInToday($0.completedAt) }.reduce(0) { $0 + $1.rewardXP }
    }

    private var xpEarnedThisWeek: Int {
        succeeded.filter { $0.completedAt > .now.addingTimeInterval(-7 * 86_400) }.reduce(0) { $0 + $1.rewardXP }
    }

    private var totalEarnedXP: Int {
        succeeded.reduce(0) { $0 + $1.rewardXP }
    }

    private var totalSpentXP: Int {
        max(0, totalEarnedXP - progress.xp)
    }

    private var bestWeekXP: Int {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: succeeded) { entry in
            calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: entry.completedAt)
        }
        return grouped.values.map { $0.reduce(0) { $0 + $1.rewardXP } }.max() ?? 0
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Text("Redeem")
                        .font(Theme.display(34, .semibold))
                        .foregroundStyle(Theme.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .staggered(0)

                    balanceCard.staggered(0)
                    rewardSection(title: "Screen time", rewards: screenTimeRewards, startIndex: 1)
                    rewardSection(title: "Other prizes", rewards: otherRewards, startIndex: 2)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .background(Theme.canvas)
            .toolbar(.hidden, for: .navigationBar)
            .overlay(alignment: .bottom) { toast }
        }
        .sensoryFeedback(.success, trigger: redeemPulse)
    }

    private var balanceCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("XP BALANCE")
                        .font(Theme.microLabel)
                        .tracking(1)
                        .foregroundStyle(Theme.accent300)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        CountingNumber(value: progress.xp, font: Theme.mono(36, .semibold), color: Theme.text)
                        Text("XP")
                            .font(Theme.body(13))
                            .foregroundStyle(Theme.accent300)
                    }
                    Text("+\(xpEarnedToday) XP today · \(xpEarnedThisWeek) XP this week")
                        .font(Theme.body(11))
                        .foregroundStyle(Theme.accent300)
                }
                Spacer()
                Image(systemName: "sparkles")
                    .font(.system(size: 26))
                    .foregroundStyle(Theme.accent300)
                    .shadow(color: Theme.accent.opacity(0.8), radius: 10)
                    .symbolEffect(.bounce, value: redeemPulse)
            }

            HStack(spacing: 14) {
                balanceStat("Earned", "\(totalEarnedXP)")
                Rectangle().fill(Theme.text.opacity(0.18)).frame(width: 1, height: 26)
                balanceStat("Spent", "\(totalSpentXP)")
                Rectangle().fill(Theme.text.opacity(0.18)).frame(width: 1, height: 26)
                balanceStat("Best week", "\(bestWeekXP)")
            }
        }
        .padding(22)
        .background(Theme.sectionGradient, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.sectionGlow, lineWidth: 1))
    }

    private func balanceStat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(Theme.body(9.5))
                .tracking(0.6)
                .foregroundStyle(Theme.accent300.opacity(0.85))
            Text(value)
                .font(Theme.mono(14, .medium))
                .foregroundStyle(Theme.text)
        }
    }

    private func rewardSection(title: String, rewards: [RedeemableReward], startIndex: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                MicroLabel(text: title)
                FadingRule()
            }
            ForEach(rewards) { reward in
                rewardRow(reward)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .staggered(startIndex)
    }

    private func rewardRow(_ reward: RedeemableReward) -> some View {
        let affordable = progress.xp >= reward.costXP
        let isBetterDeal = isBetterDealPerMinute(reward)

        return VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 12) {
                IconTile(systemImage: reward.glyph, size: 36, emphasized: affordable)
                VStack(alignment: .leading, spacing: 2) {
                    Text(reward.name)
                        .font(Theme.body(14, .medium))
                        .foregroundStyle(Theme.text)
                    Text(rewardDetail(reward))
                        .font(Theme.mono(10.5, .medium))
                        .foregroundStyle(Theme.textFaint)
                }
                Spacer(minLength: 6)

            }

            Button("Redeem · \(reward.costXP) XP") { redeem(reward) }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!affordable)

            if isBetterDeal {
                HStack(spacing: 7) {
                    AccentTag(text: "Better deal!")
                    Text("Saves \(savings(reward)) XP!")
                        .font(Theme.body(10.5))
                        .foregroundStyle(Theme.textFaint)
                }
            }

            if !affordable {
                let fraction = min(1, Double(progress.xp) / Double(reward.costXP))
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.neutral900)
                        Capsule().fill(Theme.neutral700).frame(width: geo.size.width * fraction)
                    }
                }
                .frame(height: 3)
                Text("\(reward.costXP - progress.xp) XP to unlock")
                    .font(Theme.body(10.5))
                    .foregroundStyle(Theme.textFaint)
            }
        }
        .card(padding: 18)

        .animation(.easeInOut(duration: 0.25), value: affordable)
    }

    private func rewardDetail(_ reward: RedeemableReward) -> String {
        switch reward.kind {
        case .screenTimeMinutes(let minutes):
            let perMinute = Double(reward.costXP) / Double(max(1, minutes))
            let perMinuteText = String(format: "%.1f", perMinute)
            return "\(reward.costXP) XP · \(perMinuteText) XP per minute"
        case .theme:
            return "\(reward.costXP) XP · permanent"
        case .lockSkip:
            return "\(reward.costXP) XP · once"
        }
    }

    private func isBetterDealPerMinute(_ reward: RedeemableReward) -> Bool {
        guard case .screenTimeMinutes(let minutes) = reward.kind, minutes > 0 else { return false }
        let others = screenTimeRewards.filter { $0.id != reward.id }
        guard !others.isEmpty else { return false }
        let thisRate = Double(reward.costXP) / Double(minutes)
        return others.allSatisfy { other in
            guard case .screenTimeMinutes(let otherMinutes) = other.kind, otherMinutes > 0 else { return true }
            return thisRate < Double(other.costXP) / Double(otherMinutes)
        }
    }

    private func savings(_ reward: RedeemableReward) -> Int {
        guard case .screenTimeMinutes(let minutes) = reward.kind, minutes > 0 else { return 0 }
        let thisRate = Double(reward.costXP) / Double(minutes)
        let worstOther = screenTimeRewards
            .filter { $0.id != reward.id }
            .compactMap { other -> Double? in
                guard case .screenTimeMinutes(let otherMinutes) = other.kind, otherMinutes > 0 else { return nil }
                return Double(other.costXP) / Double(otherMinutes)
            }
            .max() ?? thisRate
        return max(0, Int(((worstOther - thisRate) * Double(minutes)).rounded()))
    }

    @ViewBuilder
    private var toast: some View {
        if let toastMessage {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                Text(toastMessage)
                    .font(Theme.body(13, .medium))
            }
            .foregroundStyle(Theme.canvas)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(Theme.text, in: Capsule())
            .padding(.bottom, 16)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func redeem(_ reward: RedeemableReward) {
        guard let message = try? RedemptionStore.redeem(reward, for: progress) else { return }
        redeemPulse += 1
        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
            toastMessage = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation(.easeOut(duration: 0.3)) { toastMessage = nil }
        }
    }
}
