import SwiftUI

struct HomeView: View {
    @Bindable var progress: UserProgress
    let history: [ChallengeCompletion]
    let onEarnTime: () -> Void
    let onStartChallenge: (ChallengeOffer) -> Void

    private enum TimelineDotState { case past, accent, future }

    private var offers: [ChallengeOffer] { ChallengeEngine.makeOffers(recentHistory: history) }
    private var nextUp: ChallengeOffer? { ChallengeEngine.bestReturn(among: offers) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    header.staggered(0)
                    greeting.staggered(0)
                    budgetCard.staggered(1)
                    tierCard.staggered(2)
                    if let nextUp {
                        nextUpCard(nextUp).staggered(3)
                    }
                    todayCard.staggered(4)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .background(Theme.canvas)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var header: some View {
        HStack(spacing: 9) {
            IconTile(systemImage: "leaf.fill", size: 26, radius: 7)
            Text("LevelSet")
                .font(Theme.body(17, .medium))
                .foregroundStyle(Theme.text)
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .font(Theme.body(12))
                    .foregroundStyle(Theme.accent400)
                Text("\(progress.currentStreak)")
                    .font(Theme.mono(12, .semibold))
                    .foregroundStyle(Theme.accent300)
                Text("days")
                    .font(Theme.body(10))
                    .foregroundStyle(Theme.accent600)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Theme.surfaceTint, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Theme.accent800, lineWidth: 1))
        }
    }

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(progress.greeting())
                .font(Theme.display(34, .semibold))
                .foregroundStyle(Theme.heading)
            Text(Date.now.formatted(.dateTime.weekday(.wide).month().day()))
                .font(Theme.body(11.5))
                .foregroundStyle(Theme.textFaint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var tierCard: some View {
        let tier = progress.currentTier
        let next = progress.nextTier

        return VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text("Tier \(progress.tierIndex + 1) · \(tier.name)")
                    .font(Theme.microLabel)
                    .tracking(0.8)
                    .foregroundStyle(Theme.accent)
                Spacer()
                Text("\(progress.xp)")
                    .font(Theme.mono(18, .semibold))
                    .foregroundStyle(Theme.text)
                Text("XP")
                    .font(Theme.body(10.5))
                    .foregroundStyle(Theme.textFaint)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.accent900)
                    Capsule()
                        .fill(Theme.accent)
                        .shadow(color: .clear, radius: 0)
                        .frame(width: geo.size.width * progress.tierProgressFraction())
                }
            }
            .frame(height: 4)

            if let next {
                HStack {
                    Text("\(progress.xpToNextTier) XP to ")
                        .foregroundStyle(Theme.textFaint)
                    + Text(next.name)
                        .foregroundStyle(Theme.neutral400)
                    Spacer()
                    Text("\(next.xpRequired) XP")
                        .font(Theme.mono(10.5, .medium))
                        .foregroundStyle(Theme.textFaint)
                }
                .font(Theme.body(10.5))
            }
        }
        .card()
    }

    private var budgetCard: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let secondsRemaining = progress.secondsRemaining(asOf: context.date)
            let totalSeconds = max(1, (progress.dailyLimitMinutes + progress.bonusMinutesGrantedToday) * 60)
            let usedFraction = 1 - Double(secondsRemaining) / Double(totalSeconds)
            let locked = secondsRemaining == 0

            VStack(spacing: 24) {
                HStack {
                    MicroLabel(text: "Your screen time")
                    Spacer()
                    AccentTag(text: locked ? "Time to move" : "Available")
                }

                ZStack {
                    RingProgress(progress: max(0, min(1, 1 - usedFraction)), lineWidth: 10)
                    VStack(spacing: 6) {
                        Text(timeLabel(secondsRemaining))
                            .font(Theme.mono(42, .semibold))
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                            .foregroundStyle(Theme.text)
                            .contentTransition(.numericText())
                        Text(locked ? "Ready for a reset" : "Minutes remaining")
                            .font(.caption)
                            .foregroundStyle(Theme.textMuted)
                    }
                    .padding(14)
                }
                .frame(width: 204, height: 204)
                .padding(.vertical, 6)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Screen time remaining")
                .accessibilityValue("\(secondsRemaining / 60) minutes, \(secondsRemaining % 60) seconds")

                if !locked {
                    Text("Available until \(progress.budgetEndDate.formatted(.dateTime.hour().minute()))")
                        .font(.caption)
                        .foregroundStyle(Theme.textMuted)
                }

                VStack(spacing: 10) {
                    budgetRow("Daily limit", "\(progress.dailyLimitMinutes) min", Theme.text)
                    budgetRow("Earned today", "+\(progress.bonusMinutesGrantedToday) min", Theme.accent400)
                    budgetRow("Used today", "\(progress.spentMinutes(asOf: context.date)) min", Theme.text)
                }

                Button(action: onEarnTime) {
                    Label("Earn more time", systemImage: "plus.circle.fill")
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .card(padding: 22)
        }
    }

    private func budgetRow(_ label: String, _ value: String, _ color: Color) -> some View {
        HStack {
            Text(label).foregroundStyle(Theme.textMuted)
            Spacer()
            Text(value).font(Theme.mono(11.5, .medium)).foregroundStyle(color)
        }
        .font(Theme.body(11.5))
    }

    private func nextUpCard(_ offer: ChallengeOffer) -> some View {
        VStack(spacing: 20) {
            HStack(spacing: 11) {
                IconTile(systemImage: offer.kind.glyph, size: 38)
                VStack(alignment: .leading, spacing: 1) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(offer.kind.shortName)
                            .font(Theme.body(14.5, .medium))
                            .foregroundStyle(Theme.text)
                        AccentTag(text: "Best return")
                    }
                    Text(offer.subtitle)
                        .font(Theme.body(11))
                        .foregroundStyle(Theme.textFaint)
                }
                Spacer(minLength: 6)
                VStack(alignment: .trailing, spacing: 1) {
                    Text("+\(offer.unlockMinutes)m")
                        .font(Theme.mono(15, .semibold))
                        .foregroundStyle(Theme.accent400)
                    Text("+\(offer.rewardXP) XP")
                        .font(Theme.mono(10, .medium))
                        .foregroundStyle(Theme.textFaint)
                }
            }
            Button("Start now") { onStartChallenge(offer) }
                .buttonStyle(PrimaryButtonStyle())
        }
        .card(emphasized: true)
    }

    private var todayEvents: [(time: Date, title: String, detail: String?, state: TimelineDotState)] {
        var events: [(time: Date, title: String, detail: String?, state: TimelineDotState)] = [
            (progress.budgetStartDate, "Budget opened", timeLabel(progress.dailyLimitMinutes * 60), .past),
        ]

        let todays = history
            .filter { Calendar.current.isDateInToday($0.completedAt) && $0.succeeded }
            .sorted { $0.completedAt < $1.completedAt }

        for entry in todays {
            events.append((
                entry.completedAt,
                "\(entry.kind.shortName) · \(entry.actualCount) \(entry.kind.unitLabel)",
                "+\(timeLabel(entry.unlockMinutes * 60))",
                .accent
            ))
        }

        events.append((
            progress.budgetEndDate,
            progress.isLocked ? "Locked" : "Screen time ends",
            nil,
            .future
        ))

        return events
    }

    private var todayCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                MicroLabel(text: "Today")
                Spacer()
                Text("\(todayEvents.count) Events")
                    .font(Theme.mono(10, .medium))
                    .foregroundStyle(Theme.textFaint)
            }
            VStack(spacing: 0) {
                ForEach(Array(todayEvents.enumerated()), id: \.offset) { index, event in
                    timelineRow(event, isLast: index == todayEvents.count - 1)
                }
            }
        }
        .card()
    }

    private func timelineRow(
        _ event: (time: Date, title: String, detail: String?, state: TimelineDotState),
        isLast: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(spacing: 0) {
                dot(for: event.state).padding(.top, 4)
                if !isLast {
                    Rectangle().fill(Theme.hairline).frame(width: 1)
                }
            }
            .frame(width: 9)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(event.time, format: .dateTime.hour().minute())
                    .font(Theme.mono(10.5, .medium))
                    .foregroundStyle(Theme.textFaint)
                    .frame(minWidth: 54, alignment: .leading)
                Text(event.title)
                    .font(Theme.body(12))
                    .foregroundStyle(event.state == .accent ? Theme.text : Theme.textMuted)
                Spacer()
                if let detail = event.detail {
                    Text(detail)
                        .font(Theme.mono(11, .medium))
                        .foregroundStyle(event.state == .accent ? Theme.accent400 : Theme.neutral400)
                } else if event.state == .future {
                    Image(systemName: "lock.fill")
                        .font(Theme.body(11))
                        .foregroundStyle(Theme.textFaint)
                }
            }
            .padding(.bottom, isLast ? 0 : 11)
        }
    }

    @ViewBuilder
    private func dot(for state: TimelineDotState) -> some View {
        switch state {
        case .past:
            Circle().fill(Theme.neutral700).frame(width: 7, height: 7)
        case .accent:
            Circle().fill(Theme.accent).frame(width: 7, height: 7)
                .shadow(color: Theme.accent.opacity(0.8), radius: 4)
        case .future:
            Circle().strokeBorder(Theme.neutral700, lineWidth: 1.5).frame(width: 7, height: 7)
        }
    }

    private func timeLabel(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}
