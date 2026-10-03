import Foundation

enum SampleData {
    static func seed(_ progress: UserProgress) -> [ChallengeCompletion] {
        progress.xp = 640
        progress.currentStreak = 12

        let samples: [(daysAgo: Int, kind: ChallengeKind, target: Int, minutes: Int, xp: Int, succeeded: Bool)] = [
            (0, .pushups, 8, 14, 30, true),
            (1, .jumpingJacks, 20, 12, 30, true),
            (1, .reading, 3, 10, 20, true),
            (2, .plank, 1, 12, 25, true),
            (3, .walk, 5, 15, 30, true),
            (4, .clapPushups, 6, 14, 30, false),
            (5, .wallSit, 1, 10, 20, true),
            (6, .pushups, 8, 14, 30, true),
        ]

        return samples.map { sample in
            let date = Calendar.current.date(byAdding: .day, value: -sample.daysAgo, to: .now) ?? .now
            return ChallengeCompletion(
                kind: sample.kind,
                targetCount: sample.target,
                actualCount: sample.succeeded ? sample.target : sample.target / 2,
                unlockMinutes: sample.minutes,
                rewardXP: sample.xp,
                succeeded: sample.succeeded,
                completedAt: date
            )
        }
    }
}
