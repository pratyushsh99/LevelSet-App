import Foundation

enum ChallengeKind: String, Codable, CaseIterable {
    case pushups
    case clapPushups
    case jumpingJacks
    case plank
    case wallSit
    case walk
    case reading

    var displayName: String {
        switch self {
        case .pushups: return "Pushups, camera-tracked"
        case .clapPushups: return "Clap pushups, camera-tracked"
        case .jumpingJacks: return "Jumping jacks, camera-tracked"
        case .plank: return "Plank hold, camera-tracked"
        case .wallSit: return "Wall sit, camera-tracked"
        case .walk: return "Short walk"
        case .reading: return "Reading sprint"
        }
    }

    var shortName: String {
        switch self {
        case .pushups: return "Pushups"
        case .clapPushups: return "Clap pushups"
        case .jumpingJacks: return "Jumping jacks"
        case .plank: return "Plank hold"
        case .wallSit: return "Wall sit"
        case .walk: return "Short walk"
        case .reading: return "Reading sprint"
        }
    }

    var glyph: String {
        switch self {
        case .pushups: return "figure.strengthtraining.traditional"
        case .clapPushups: return "hands.clap.fill"
        case .jumpingJacks: return "figure.highintensity.intervaltraining"
        case .plank: return "figure.core.training"
        case .wallSit: return "figure.stand"
        case .walk: return "figure.walk"
        case .reading: return "book"
        }
    }

    var usesCamera: Bool {
        switch self {
        case .pushups, .clapPushups, .jumpingJacks, .plank, .wallSit: return true
        case .walk, .reading: return false
        }
    }

    var unitLabel: String {
        switch self {
        case .pushups, .clapPushups, .jumpingJacks: return "reps"
        case .plank, .wallSit, .walk, .reading: return "min"
        }
    }
}

struct ChallengeOffer: Identifiable {
    let id = UUID()
    let kind: ChallengeKind
    let targetCount: Int
    let unlockMinutes: Int
    let rewardXP: Int

    var subtitle: String {
        switch kind {
        case .pushups, .clapPushups, .jumpingJacks: return "\(targetCount) reps · camera monitored"
        case .plank, .wallSit: return "Hold \(targetCount) min · camera monitored"
        case .walk: return "\(targetCount) min run, tracked with your step count."
        case .reading: return "\(targetCount) min, timed"
        }
    }

    var shortSubtitle: String {
        switch kind {
        case .pushups, .clapPushups, .jumpingJacks: return "\(targetCount) reps · camera monitored"
        case .plank, .wallSit: return "Hold \(targetCount) min · camera monitored"
        case .walk: return "\(targetCount) min · step count"
        case .reading: return "\(targetCount) min, timed"
        }
    }
}

struct ChallengeCompletion: Identifiable, Codable {
    let id: UUID
    let kind: ChallengeKind
    let targetCount: Int
    let actualCount: Int
    let unlockMinutes: Int
    let rewardXP: Int
    let succeeded: Bool
    let completedAt: Date

    init(id: UUID = UUID(), kind: ChallengeKind, targetCount: Int, actualCount: Int, unlockMinutes: Int, rewardXP: Int, succeeded: Bool, completedAt: Date = .now) {
        self.id = id
        self.kind = kind
        self.targetCount = targetCount
        self.actualCount = actualCount
        self.unlockMinutes = unlockMinutes
        self.rewardXP = rewardXP
        self.succeeded = succeeded
        self.completedAt = completedAt
    }
}

struct RedeemableReward: Identifiable {
    let id = UUID()
    let glyph: String
    let name: String
    let costXP: Int
    let kind: RewardKind

    enum RewardKind {
        case screenTimeMinutes(Int)
        case theme(String)
        case lockSkip
    }
}

let redeemableCatalog: [RedeemableReward] = [
    .init(glyph: "clock.badge.checkmark", name: "+15 min screen time", costXP: 150, kind: .screenTimeMinutes(15)),
    .init(glyph: "clock.badge.checkmark", name: "+30 min screen time", costXP: 280, kind: .screenTimeMinutes(30)),
    .init(glyph: "moon.stars", name: "Unlock \"Nightwalk\" theme", costXP: 400, kind: .theme("Nightwalk")),
    .init(glyph: "ticket", name: "Skip tomorrow's lock, once", costXP: 500, kind: .lockSkip),
]
