import Foundation

struct ChallengeEngine {
    private static let baseTargets: [ChallengeKind: Int] = [
        .pushups: 8,
        .clapPushups: 6,
        .jumpingJacks: 20,
        .plank: 1,
        .wallSit: 1,
        .walk: 3,
        .reading: 2,
    ]

    private static let minutesPerUnit: [ChallengeKind: Double] = [
        .pushups: 1.7,
        .clapPushups: 2.3,
        .jumpingJacks: 0.6,
        .plank: 12.0,
        .wallSit: 10.0,
        .walk: 3.0,
        .reading: 3.3,
    ]

    private static let xpPerUnit: [ChallengeKind: Double] = [
        .pushups: 3.75,
        .clapPushups: 5.0,
        .jumpingJacks: 1.5,
        .plank: 25.0,
        .wallSit: 20.0,
        .walk: 6.0,
        .reading: 6.7,
    ]

    static func makeOffers(recentHistory: [ChallengeCompletion]) -> [ChallengeOffer] {
        ChallengeKind.allCases.map { kind in
            let history = recentHistory.filter { $0.kind == kind }.suffix(10)
            let target = adjustedTarget(base: baseTargets[kind] ?? 5, history: Array(history))
            let minutes = Int((Double(target) * (minutesPerUnit[kind] ?? 2)).rounded())
            let xp = Int((Double(target) * (xpPerUnit[kind] ?? 5)).rounded())
            return ChallengeOffer(kind: kind, targetCount: target, unlockMinutes: minutes, rewardXP: xp)
        }
    }

    static func bestReturn(among offers: [ChallengeOffer]) -> ChallengeOffer? {
        offers.max(by: { $0.unlockMinutes < $1.unlockMinutes })
    }

    static func relativeGenerosity(of kind: ChallengeKind) -> Double? {
        let countable: [ChallengeKind] = [.walk, .pushups, .clapPushups, .jumpingJacks]
        guard countable.contains(kind), let value = minutesPerUnit[kind] else { return nil }
        let maxValue = countable.compactMap { minutesPerUnit[$0] }.max() ?? value
        guard maxValue > 0 else { return 0 }
        return value / maxValue
    }

    static func minutesPerUnit(for kind: ChallengeKind) -> Double {
        minutesPerUnit[kind] ?? 2
    }

    private static func adjustedTarget(base: Int, history: [ChallengeCompletion]) -> Int {
        guard !history.isEmpty else { return base }

        let successRate = Double(history.filter(\.succeeded).count) / Double(history.count)
        let recentStreak = trailingSuccessStreak(history)

        var multiplier = 1.0
        if successRate >= 0.85 && recentStreak >= 3 {
            multiplier = 1.25
        } else if successRate < 0.5 {
            multiplier = 0.75
        }

        let scaled = Double(base) * multiplier
        return max(1, Int(scaled.rounded()))
    }

    private static func trailingSuccessStreak(_ history: [ChallengeCompletion]) -> Int {
        var streak = 0
        for completion in history.reversed() {
            if completion.succeeded { streak += 1 } else { break }
        }
        return streak
    }
}
