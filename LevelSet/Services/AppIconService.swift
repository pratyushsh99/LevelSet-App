import UIKit

@MainActor
final class AppIconService: ObservableObject {
    static let shared = AppIconService()

    @Published private(set) var status = "No icon change requested yet"

    private let alternateIconNames: [String: String] = [
        "Sunrise": "AppIcon-Sunrise",
        "Tidepool": "AppIcon-Tidepool",
        "Nightwalk": "AppIcon-Nightwalk",
    ]

    static func apply(themeName: String) {
        shared.apply(themeName: themeName)
    }

    var currentIconName: String {
        UIApplication.shared.alternateIconName ?? "AppIcon"
    }

    func apply(themeName: String) {
        let application = UIApplication.shared
        guard application.supportsAlternateIcons else {
            status = "This build has no alternate icons. Run xcodegen generate, then clean build."
            return
        }
        let desired = alternateIconNames[themeName]
        guard application.alternateIconName != desired else {
            status = "Already using \(desired ?? "AppIcon")"
            return
        }
        status = "Switching to \(desired ?? "AppIcon")…"
        Task {
            do {
                try await application.setAlternateIconName(desired)
                status = "Now using \(desired ?? "AppIcon")"
            } catch {
                status = "Icon change failed: \(error.localizedDescription)"
            }
        }
    }
}
