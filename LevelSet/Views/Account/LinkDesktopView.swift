import SwiftUI
import UIKit

struct LinkDesktopView: View {
    let onPaired: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var status: Status = .scanning
    @State private var isProcessing = false

    private enum Status: Equatable {
        case scanning
        case success
        case failure(String)
    }

    private struct PairingPayload: Decodable {
        let type: String
        let code: String
    }

    var body: some View {
        NavigationStack {
            ZStack {
                switch status {
                case .scanning:
                    QRScannerView(onCodeScanned: handleScannedValue)
                        .ignoresSafeArea()
                    scanningOverlay
                case .success:
                    VStack(spacing: 12) {
                        resultView(
                            systemImage: "checkmark.circle.fill",
                            tint: Theme.accent,
                            title: "Desktop linked!",
                            message: "Your earned screen time now syncs to that browser."
                        )
                        deviceIdCopyRow
                    }
                case .failure(let message):
                    resultView(
                        systemImage: "xmark.circle.fill",
                        tint: Color(hex: 0xE36B6B),
                        title: "Couldn't link",
                        message: message
                    )
                }
            }
            .background(Theme.canvas)
            .navigationTitle("Link Desktop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private var scanningOverlay: some View {
        VStack {
            Spacer()
            Text("Point your camera at the QR code on your computer's /pair page.")
                .font(Theme.body(14, .medium))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.bottom, 48)
        }
    }

    private var deviceIdCopyRow: some View {
        VStack(spacing: 6) {
            Text("Paste this into the browser extension's settings:")
                .font(Theme.body(12))
                .foregroundStyle(Theme.textFaint)
            Button {
                UIPasteboard.general.string = DesktopSyncService.deviceUserId
            } label: {
                HStack(spacing: 8) {
                    Text(DesktopSyncService.deviceUserId)
                        .font(Theme.mono(12, .medium))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Image(systemName: "doc.on.doc")
                        .font(Theme.body(12))
                }
                .foregroundStyle(Theme.accent)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Theme.surfaceTint.opacity(0.6), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .padding(.horizontal, 32)
    }

    private func resultView(systemImage: String, tint: Color, title: String, message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 52))
                .foregroundStyle(tint)
            Text(title)
                .font(Theme.display(22, .semibold))
                .foregroundStyle(Theme.text)
            Text(message)
                .font(Theme.body(14))
                .foregroundStyle(Theme.textFaint)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if case .failure = status {
                Button("Try Again") { status = .scanning }
                    .buttonStyle(SoftButtonStyle(tint: Theme.accent, borderColor: Theme.accent.opacity(0.4)))
                    .padding(.top, 8)
            }
        }
        .padding()
    }

    private func handleScannedValue(_ value: String) {
        guard !isProcessing else { return }
        isProcessing = true

        guard let data = value.data(using: .utf8),
              let payload = try? JSONDecoder().decode(PairingPayload.self, from: data),
              payload.type == "levelset-pairing" else {
            status = .failure("That QR code wasn't a LevelSet pairing code.")
            isProcessing = false
            return
        }

        Task {
            do {
                try await DesktopSyncService.confirmPairing(code: payload.code)
                status = .success
                onPaired()
            } catch DesktopSyncService.PairingError.codeExpired {
                status = .failure("That code expired. Refresh the /pair page and try again.")
            } catch DesktopSyncService.PairingError.invalidCode {
                status = .failure("That pairing code wasn't recognized.")
            } catch {
                status = .failure("Something went wrong. Check your connection and try again.")
            }
            isProcessing = false
        }
    }
}
