import Foundation

enum PersistenceStore {
    private static let progressKey = "com.pratyushsharma.levelset.persistence.progress"
    private static let historyKey = "com.pratyushsharma.levelset.persistence.history"

    static func loadProgress() -> UserProgress? {
        guard let data = UserDefaults.standard.data(forKey: progressKey) else { return nil }
        return try? JSONDecoder().decode(UserProgress.self, from: data)
    }

    static func saveProgress(_ progress: UserProgress) {
        guard let data = try? JSONEncoder().encode(progress) else { return }
        UserDefaults.standard.set(data, forKey: progressKey)
    }

    static func loadHistory() -> [ChallengeCompletion]? {
        guard let data = UserDefaults.standard.data(forKey: historyKey) else { return nil }
        return try? JSONDecoder().decode([ChallengeCompletion].self, from: data)
    }

    static func saveHistory(_ history: [ChallengeCompletion]) {
        guard let data = try? JSONEncoder().encode(history) else { return }
        UserDefaults.standard.set(data, forKey: historyKey)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: progressKey)
        UserDefaults.standard.removeObject(forKey: historyKey)
    }
}
