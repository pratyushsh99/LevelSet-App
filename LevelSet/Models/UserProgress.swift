import Foundation
import Observation

struct ProgressTier {
    let name: String
    let xpRequired: Int
}

@Observable
final class UserProgress {
    var xp: Int
    var currentStreak: Int
    var dailyLimitMinutes: Int
    var budgetStartDate: Date
    var budgetEndDate: Date
    var bonusMinutesGrantedToday: Int
    var displayName: String?
    var hasCompletedOnboarding: Bool
    var notificationsEnabled: Bool

    var selectedThemeName: String?

    var limitedAppNames: [String]

    static let tiers: [ProgressTier] = [
        ProgressTier(name: "Pine Trail", xpRequired: 0),
        ProgressTier(name: "Sunrise", xpRequired: 500),
        ProgressTier(name: "Tidepool", xpRequired: 1500),
        ProgressTier(name: "Nightwalk", xpRequired: 3000),
    ]

    init(
        xp: Int = 0,
        currentStreak: Int = 0,
        dailyLimitMinutes: Int = 30,
        bonusMinutesGrantedToday: Int = 0,
        displayName: String? = nil,
        hasCompletedOnboarding: Bool = false,
        notificationsEnabled: Bool = false,
        selectedThemeName: String? = nil,
        limitedAppNames: [String] = []
    ) {
        self.xp = xp
        self.currentStreak = currentStreak
        self.dailyLimitMinutes = dailyLimitMinutes
        self.budgetStartDate = .now
        self.budgetEndDate = Date.now.addingTimeInterval(TimeInterval(dailyLimitMinutes * 60))
        self.bonusMinutesGrantedToday = bonusMinutesGrantedToday
        self.displayName = displayName
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.notificationsEnabled = notificationsEnabled
        self.selectedThemeName = selectedThemeName
        self.limitedAppNames = limitedAppNames
        Theme.apply(themeName: effectiveThemeName)
    }

    func secondsRemaining(asOf now: Date = .now) -> Int {
        max(0, Int(budgetEndDate.timeIntervalSince(now)))
    }

    var minutesRemaining: Int { secondsRemaining() / 60 }

    func isLocked(asOf now: Date = .now) -> Bool {
        secondsRemaining(asOf: now) == 0
    }

    var isLocked: Bool { isLocked() }

    func spentMinutes(asOf now: Date = .now) -> Int {
        max(0, dailyLimitMinutes + bonusMinutesGrantedToday - (secondsRemaining(asOf: now) / 60))
    }

    func addXP(_ amount: Int) {
        xp += amount
    }

    @discardableResult
    func redeemXP(cost: Int) -> Bool {
        guard xp >= cost else { return false }
        xp -= cost
        return true
    }

    func grantBonusMinutes(_ minutes: Int) {
        let base = max(budgetEndDate, .now)
        budgetEndDate = base.addingTimeInterval(TimeInterval(minutes * 60))
        bonusMinutesGrantedToday += minutes
        DesktopSyncService.syncBalance(secondsRemaining: secondsRemaining())
    }

    func setDailyLimit(minutes: Int) {
        dailyLimitMinutes = minutes
        budgetStartDate = .now
        budgetEndDate = Date.now.addingTimeInterval(TimeInterval(minutes * 60))
        bonusMinutesGrantedToday = 0
        DesktopSyncService.syncBalance(secondsRemaining: secondsRemaining())
    }

    func greeting(at date: Date = .now) -> String {
        let timeOfDay: String
        switch Calendar.current.component(.hour, from: date) {
        case 0..<12: timeOfDay = "Good morning"
        case 12..<17: timeOfDay = "Good afternoon"
        default: timeOfDay = "Good evening"
        }
        guard let name = displayName, !name.isEmpty else { return "\(timeOfDay)!" }
        return "\(timeOfDay), \(name)."
    }

    var tierIndex: Int {
        Self.tiers.lastIndex { xp >= $0.xpRequired } ?? 0
    }

    var currentTier: ProgressTier { Self.tiers[tierIndex] }

    var nextTier: ProgressTier? {
        let next = tierIndex + 1
        return Self.tiers.indices.contains(next) ? Self.tiers[next] : nil
    }

    func tierProgressFraction(for xpValue: Int? = nil) -> Double {
        let xpValue = xpValue ?? xp
        guard let next = nextTier else { return 1 }
        let span = Double(next.xpRequired - currentTier.xpRequired)
        guard span > 0 else { return 1 }
        return max(0, min(1, Double(xpValue - currentTier.xpRequired) / span))
    }

    var xpToNextTier: Int {
        guard let next = nextTier else { return 0 }
        return max(0, next.xpRequired - xp)
    }

    var effectiveThemeName: String {
        if let selectedThemeName, Self.tiers.first(where: { $0.name == selectedThemeName }).map({ xp >= $0.xpRequired }) == true {
            return selectedThemeName
        }
        return currentTier.name
    }

    func selectTheme(named name: String) {
        guard let tier = Self.tiers.first(where: { $0.name == name }), xp >= tier.xpRequired else { return }
        selectedThemeName = name
        let themeName = effectiveThemeName
        Theme.apply(themeName: themeName)
        Task { @MainActor in AppIconService.apply(themeName: themeName) }
    }
}

extension UserProgress: Codable {
    private enum CodingKeys: String, CodingKey {
        case xp, currentStreak, dailyLimitMinutes, budgetStartDate, budgetEndDate
        case bonusMinutesGrantedToday, displayName, hasCompletedOnboarding
        case notificationsEnabled, selectedThemeName, limitedAppNames
    }

    convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            xp: try container.decode(Int.self, forKey: .xp),
            currentStreak: try container.decode(Int.self, forKey: .currentStreak),
            dailyLimitMinutes: try container.decode(Int.self, forKey: .dailyLimitMinutes),
            bonusMinutesGrantedToday: try container.decode(Int.self, forKey: .bonusMinutesGrantedToday),
            displayName: try container.decodeIfPresent(String.self, forKey: .displayName),
            hasCompletedOnboarding: try container.decode(Bool.self, forKey: .hasCompletedOnboarding),
            notificationsEnabled: try container.decode(Bool.self, forKey: .notificationsEnabled),
            selectedThemeName: try container.decodeIfPresent(String.self, forKey: .selectedThemeName),
            limitedAppNames: try container.decodeIfPresent([String].self, forKey: .limitedAppNames) ?? []
        )
        self.budgetStartDate = try container.decode(Date.self, forKey: .budgetStartDate)
        self.budgetEndDate = try container.decode(Date.self, forKey: .budgetEndDate)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(xp, forKey: .xp)
        try container.encode(currentStreak, forKey: .currentStreak)
        try container.encode(dailyLimitMinutes, forKey: .dailyLimitMinutes)
        try container.encode(budgetStartDate, forKey: .budgetStartDate)
        try container.encode(budgetEndDate, forKey: .budgetEndDate)
        try container.encode(bonusMinutesGrantedToday, forKey: .bonusMinutesGrantedToday)
        try container.encodeIfPresent(displayName, forKey: .displayName)
        try container.encode(hasCompletedOnboarding, forKey: .hasCompletedOnboarding)
        try container.encode(notificationsEnabled, forKey: .notificationsEnabled)
        try container.encodeIfPresent(selectedThemeName, forKey: .selectedThemeName)
        try container.encode(limitedAppNames, forKey: .limitedAppNames)
    }
}
