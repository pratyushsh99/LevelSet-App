import SwiftUI

struct ProgressTabView: View {
    let progress: UserProgress
    let history: [ChallengeCompletion]

    private enum RangeOption: String, CaseIterable { case week = "Week", month = "Month", all = "All" }
    private enum ActivityGroup: String, CaseIterable {
        case pushups = "Pushups", walks = "Walks", holds = "Holds", reading = "Reading"

        var tint: Color {
            switch self {
            case .pushups: Theme.accent
            case .walks: Theme.accent600
            case .holds: Theme.accent700
            case .reading: Theme.accent800
            }
        }

        static func group(for kind: ChallengeKind) -> ActivityGroup {
            switch kind {
            case .pushups, .clapPushups, .jumpingJacks: return .pushups
            case .walk: return .walks
            case .plank, .wallSit: return .holds
            case .reading: return .reading
            }
        }
    }

    @State private var range: RangeOption = .week

    private var scopedHistory: [ChallengeCompletion] {
        let cutoff: TimeInterval
        switch range {
        case .week: cutoff = 7 * 86_400
        case .month: cutoff = 30 * 86_400
        case .all: return history
        }
        return history.filter { $0.completedAt > .now.addingTimeInterval(-cutoff) }
    }

    private var successRate: Double {
        guard !scopedHistory.isEmpty else { return 0 }
        return Double(scopedHistory.filter(\.succeeded).count) / Double(scopedHistory.count)
    }

    private var last7Days: [(label: String, minutes: Int, isToday: Bool)] {
        let calendar = Calendar.current
        return (0..<7).reversed().map { offset in
            let day = calendar.date(byAdding: .day, value: -offset, to: .now) ?? .now
            let minutes = history
                .filter { $0.succeeded && calendar.isDate($0.completedAt, inSameDayAs: day) }
                .reduce(0) { $0 + $1.unlockMinutes }
            let label = calendar.veryShortStandaloneWeekdaySymbols[calendar.component(.weekday, from: day) - 1]
            return (label, minutes, offset == 0)
        }
    }

    private var activityTotals: [(group: ActivityGroup, minutes: Int)] {
        let succeeded = scopedHistory.filter(\.succeeded)
        return ActivityGroup.allCases.compactMap { group in
            let minutes = succeeded.filter { ActivityGroup.group(for: $0.kind) == group }.reduce(0) { $0 + $1.unlockMinutes }
            return minutes > 0 ? (group, minutes) : nil
        }
    }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var statsLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16))
            : AnyLayout(HStackLayout(spacing: 12))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerRow.staggered(0)
                    weeklyChart.staggered(1)
                    statGrid.staggered(2)
                    if !activityTotals.isEmpty {
                        activityCard.staggered(3)
                    }
                    if !history.isEmpty {
                        recentCard.staggered(4)
                    }
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

    private var headerRow: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Progress")
                .font(Theme.display(34, .semibold))
                .foregroundStyle(Theme.text)
            Picker("Range", selection: $range) {
                ForEach(RangeOption.allCases, id: \.self) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .tint(Theme.accent)
            .frame(maxWidth: .infinity)
        }
    }

    private var weeklyChart: some View {
        let days = last7Days
        let weekTotal = days.reduce(0) { $0 + $1.minutes }
        let maxMinutes = max(1, days.map(\.minutes).max() ?? 1)

        return VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                MicroLabel(text: "Minutes earned per day")
                Text("\(weekTotal)m this week")
                    .font(Theme.body(11))
                    .foregroundStyle(Theme.accent400)
            }
            HStack(alignment: .bottom, spacing: 7) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    VStack(spacing: 7) {
                        GrowingBar(
                            fraction: Double(day.minutes) / Double(maxMinutes),
                            tint: day.isToday ? Theme.accent : Theme.accent700,
                            maxHeight: 110
                        )
                        .frame(maxWidth: .infinity)
                        Text(day.label)
                            .font(Theme.mono(9.5, .medium))
                            .foregroundStyle(day.isToday ? Theme.accent400 : Theme.textFaint)
                    }
                }
            }
            .frame(height: 140)
        }
        .card(padding: 14)
    }

    private var statGrid: some View {
        statsLayout {
            statTile(value: "\(scopedHistory.count)", label: "Challenges\nthis \(range == .week ? "week" : range == .month ? "month" : "total")")
            statTile(value: "\(Int(successRate * 100))%", label: "Completed\n\(scopedHistory.filter(\.succeeded).count) of \(scopedHistory.count)", tint: Theme.accent400)
            statTile(value: "\(progress.currentStreak)", label: "Day streak\nbest yet")
        }
    }

    private func statTile(value: String, label: String, tint: Color = Theme.text) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(Theme.mono(21, .semibold))
                .foregroundStyle(tint)
            Text(label)
                .font(Theme.body(10.5))
                .foregroundStyle(Theme.textFaint)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 13)
    }

    private var activityCard: some View {
        let totals = activityTotals
        let sum = max(1, totals.reduce(0) { $0 + $1.minutes })

        return VStack(alignment: .leading, spacing: 12) {
            MicroLabel(text: "Activity chart")
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    ForEach(totals, id: \.group) { entry in
                        Rectangle()
                            .fill(entry.group.tint)
                            .frame(width: geometry.size.width * CGFloat(entry.minutes) / CGFloat(sum))
                    }
                }
            }
            .frame(height: 8)
            .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))

            VStack(spacing: 7) {
                ForEach(totals, id: \.group) { entry in
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(entry.group.tint)
                            .frame(width: 7, height: 7)
                        Text(entry.group.rawValue)
                            .font(Theme.body(11.5))
                            .foregroundStyle(Theme.neutral400)
                        Spacer()
                        Text("\(entry.minutes)m")
                            .font(Theme.mono(11.5, .medium))
                            .foregroundStyle(Theme.text)
                    }
                }
            }
        }
        .card()
    }

    private var recentCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            MicroLabel(text: "Recent")
            ForEach(Array(history.prefix(6).enumerated()), id: \.element.id) { index, entry in
                VStack(spacing: 0) {
                    HStack(spacing: 11) {
                        Image(systemName: entry.kind.glyph)
                            .font(Theme.body(15, .medium))
                            .foregroundStyle(Theme.neutral400)
                            .frame(width: 18)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(entry.kind.shortName)
                                .font(Theme.body(12.5))
                                .foregroundStyle(Theme.text)
                            Text("\(entry.completedAt.formatted(.relative(presentation: .named))) · \(entry.actualCount) of \(entry.targetCount)")
                                .font(Theme.body(10))
                                .foregroundStyle(Theme.textFaint)
                        }
                        Spacer()
                        if entry.succeeded {
                            Text("+\(entry.unlockMinutes)m")
                                .font(Theme.mono(12, .medium))
                                .foregroundStyle(Theme.accent400)
                        } else {
                            Text("skipped")
                                .font(Theme.body(11, .medium))
                                .foregroundStyle(Theme.textFaint)
                        }
                    }
                    .padding(.vertical, 9)
                    if index < min(history.count, 6) - 1 {
                        FadingRule()
                    }
                }
            }
        }
        .card(padding: 14)
    }
}
