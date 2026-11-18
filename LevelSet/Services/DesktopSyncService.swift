import Foundation

enum DesktopSyncService {
    static let baseURL = URL(string: "https://level-set-zeta.vercel.app")!

    private static let deviceTokenAccount = "desktopSync.deviceToken"
    private static let pendingDeletionAccount = "desktopSync.pendingAccountDeletion"

    private static var deviceToken: String? {
        KeychainStore.get(account: deviceTokenAccount)
    }

    static var isPaired: Bool {
        deviceToken != nil
    }

    static func removeLegacyCredentials() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "com.pratyushsharma.levelset.desktopSync.deviceUserId")
        defaults.removeObject(forKey: "com.pratyushsharma.levelset.desktopSync.paired")
    }

    enum PairingError: Error {
        case invalidCode
        case codeExpired
        case alreadyUsed
        case server(String)
    }

    private struct PairingConfirmRequest: Encodable {
        let secret: String
    }

    private struct PairingConfirmResponse: Decodable {
        let paired: Bool
        let deviceToken: String?
    }

    private struct SyncBalanceRequest: Encodable {
        let remainingSeconds: Int
    }

    private struct SyncStatsRequest: Encodable {
        let xp: Int
        let currentStreak: Int
        let progress: UserProgress
        let history: [ChallengeCompletion]
    }

    private static func request(_ path: String, method: String, token: String?, body: Data? = nil) -> URLRequest {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = method
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }
        return request
    }

    static func confirmPairing(secret: String) async throws {
        let body = try JSONEncoder().encode(PairingConfirmRequest(secret: secret))
        let token = deviceToken
        let (data, response) = try await URLSession.shared.data(
            for: request("api/pair/confirm", method: "POST", token: token, body: body)
        )
        guard let http = response as? HTTPURLResponse else {
            throw PairingError.server("No response from server.")
        }

        switch http.statusCode {
        case 200:
            let decoded = try JSONDecoder().decode(PairingConfirmResponse.self, from: data)
            if let newToken = decoded.deviceToken {
                guard KeychainStore.set(newToken, account: deviceTokenAccount) else {
                    throw PairingError.server("Couldn't save the device key.")
                }
            }
        case 401 where token != nil:
            KeychainStore.delete(account: deviceTokenAccount)
            try await confirmPairing(secret: secret)
        case 404:
            throw PairingError.invalidCode
        case 409:
            throw PairingError.alreadyUsed
        case 410:
            throw PairingError.codeExpired
        default:
            throw PairingError.server(String(data: data, encoding: .utf8) ?? "Unknown error")
        }
    }

    private static func send(_ path: String, body: Data?) {
        guard let token = deviceToken else { return }
        let request = request(path, method: "POST", token: token, body: body)

        Task.detached(priority: .background) {
            guard let (_, response) = try? await URLSession.shared.data(for: request),
                  let http = response as? HTTPURLResponse else { return }
            if http.statusCode == 401 {
                KeychainStore.delete(account: deviceTokenAccount)
            }
        }
    }

    static func syncBalance(secondsRemaining: Int) {
        send("api/sync-balance", body: try? JSONEncoder().encode(
            SyncBalanceRequest(remainingSeconds: secondsRemaining)
        ))
    }

    static func syncStats(progress: UserProgress, history: [ChallengeCompletion]) {
        send("api/sync-stats", body: try? JSONEncoder().encode(
            SyncStatsRequest(
                xp: progress.xp,
                currentStreak: progress.currentStreak,
                progress: progress,
                history: history
            )
        ))
    }

    static func deleteRemoteAccount() {
        guard let token = deviceToken else { return }
        KeychainStore.set(token, account: pendingDeletionAccount)
        KeychainStore.delete(account: deviceTokenAccount)
        Task { await retryPendingAccountDeletion() }
    }

    static func retryPendingAccountDeletion() async {
        guard let token = KeychainStore.get(account: pendingDeletionAccount) else { return }
        guard let (_, response) = try? await URLSession.shared.data(
            for: request("api/account", method: "DELETE", token: token)
        ), let http = response as? HTTPURLResponse else { return }

        if http.statusCode == 200 || http.statusCode == 401 {
            KeychainStore.delete(account: pendingDeletionAccount)
        }
    }
}
