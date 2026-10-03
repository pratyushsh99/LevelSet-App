import Foundation

enum DesktopSyncService {
    static let baseURL = URL(string: "https://level-set-zeta.vercel.app")!

    private static let deviceUserIdKey = "com.pratyushsharma.levelset.desktopSync.deviceUserId"
    private static let pairedKey = "com.pratyushsharma.levelset.desktopSync.paired"

    static var deviceUserId: String {
        if let existing = UserDefaults.standard.string(forKey: deviceUserIdKey) {
            return existing
        }
        let generated = UUID().uuidString
        UserDefaults.standard.set(generated, forKey: deviceUserIdKey)
        return generated
    }

    static var isPaired: Bool {
        get { UserDefaults.standard.bool(forKey: pairedKey) }
        set { UserDefaults.standard.set(newValue, forKey: pairedKey) }
    }

    enum PairingError: Error {
        case invalidCode
        case codeExpired
        case server(String)
    }

    private struct PairingConfirmRequest: Encodable {
        let pairingCode: String
        let deviceUserId: String
    }

    private struct SyncBalanceRequest: Encodable {
        let userId: String
        let remainingSeconds: Int
    }

    private struct SyncStatsRequest: Encodable {
        let userId: String
        let xp: Int
        let currentStreak: Int
        let progress: UserProgress
        let history: [ChallengeCompletion]
    }

    static func confirmPairing(code: String) async throws {
        var request = URLRequest(url: baseURL.appending(path: "api/pair/confirm"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            PairingConfirmRequest(pairingCode: code, deviceUserId: deviceUserId)
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw PairingError.server("No response from server.")
        }

        switch http.statusCode {
        case 200:
            isPaired = true
        case 404:
            throw PairingError.invalidCode
        case 410:
            throw PairingError.codeExpired
        default:
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw PairingError.server(message)
        }
    }

    static func syncBalance(secondsRemaining: Int) {
        guard isPaired else { return }

        Task.detached(priority: .background) {
            var request = URLRequest(url: baseURL.appending(path: "api/sync-balance"))
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONEncoder().encode(
                SyncBalanceRequest(userId: deviceUserId, remainingSeconds: secondsRemaining)
            )

            _ = try? await URLSession.shared.data(for: request)
        }
    }

    static func syncStats(progress: UserProgress, history: [ChallengeCompletion]) {
        guard isPaired else { return }

        Task.detached(priority: .background) {
            var request = URLRequest(url: baseURL.appending(path: "api/sync-stats"))
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONEncoder().encode(
                SyncStatsRequest(
                    userId: deviceUserId,
                    xp: progress.xp,
                    currentStreak: progress.currentStreak,
                    progress: progress,
                    history: history
                )
            )

            _ = try? await URLSession.shared.data(for: request)
        }
    }
}
