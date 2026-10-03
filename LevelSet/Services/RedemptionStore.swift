import Foundation

enum RedemptionError: Error {
    case insufficientXP
}

enum RedemptionStore {
    @discardableResult
    static func redeem(_ reward: RedeemableReward, for progress: UserProgress) throws -> String {
        guard progress.redeemXP(cost: reward.costXP) else {
            throw RedemptionError.insufficientXP
        }
        switch reward.kind {
        case .screenTimeMinutes(let minutes):
            progress.grantBonusMinutes(minutes)
            return "+\(minutes) min added to today's budget"
        case .theme(let name):
            return "\"\(name)\" theme unlocked"
        case .lockSkip:
            progress.grantBonusMinutes(progress.dailyLimitMinutes)
            return "Tomorrow's lock will be skipped once"
        }
    }
}
