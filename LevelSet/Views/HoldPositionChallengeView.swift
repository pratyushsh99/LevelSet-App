import SwiftUI
import UIKit

struct HoldPositionChallengeView: View {
    let offer: ChallengeOffer
    let onFinished: (_ actualCount: Int, _ succeeded: Bool) -> Void

    @StateObject private var counter: HoldPoseCounter
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var livePulse = false

    private var targetSeconds: Int { offer.targetCount * 60 }

    init(offer: ChallengeOffer, onFinished: @escaping (Int, Bool) -> Void) {
        self.offer = offer
        self.onFinished = onFinished
        _counter = StateObject(wrappedValue: HoldPoseCounter(kind: offer.kind == .plank ? .plank : .wallSit))
    }

    private var fraction: Double {
        min(1, Double(counter.heldSeconds) / Double(max(1, targetSeconds)))
    }

    private var formGood: Bool { counter.formQuality == .good }

    var body: some View {
        ZStack {
            Theme.lockGround.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    header

                    cameraPanel
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(Theme.hairline, lineWidth: 1)
                        )

                    statCard

                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 16)
            }
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .bottom) {
                Button("End challenge") {
                    counter.stop()
                    onFinished(counter.heldSeconds, false)
                }
                .buttonStyle(SoftButtonStyle())
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Theme.lockGround)
            }
        }
        .sensoryFeedback(.selection, trigger: counter.isInPosition)
        .onAppear {
            counter.start(targetSeconds: targetSeconds) {
                onFinished(targetSeconds, true)
            }
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                livePulse = true
            }
        }
        .onDisappear { counter.stop() }
    }

    private var header: some View {
        HStack {
            Button { counter.stop(); dismiss() } label: {
                Image(systemName: "xmark")
                    .font(Theme.body(15))
                    .foregroundStyle(Theme.text)
                    .frame(width: 44, height: 44)
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Theme.hairline, lineWidth: 1))
            }
            .accessibilityLabel("Close challenge")
            Spacer()
            Text(offer.kind.shortName)
                .font(Theme.body(15, .medium))
                .foregroundStyle(Theme.text)
            Spacer()
            Color.clear.frame(width: 44)
        }
    }

    private var cameraPanel: some View {
        ZStack {
            CameraPreviewView(session: counter.session)

            LinearGradient(
                colors: [Theme.canvasDeep.opacity(0.5), .clear, Theme.canvasSunken.opacity(0.85)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack {
                HStack {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(counter.trackingStatus.isReady ? Theme.accent400 : Theme.neutral500)
                            .frame(width: 6, height: 6)
                            .shadow(color: Theme.accent.opacity(0.8), radius: 4)
                        Text(counter.trackingStatus.label.uppercased())
                            .font(Theme.mono(9.5, .semibold))
                            .tracking(0.6)
                            .foregroundStyle(Theme.text)
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Theme.canvasDeep.opacity(0.7), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Theme.hairline, lineWidth: 1))

                    Spacer()

                    Text("FORM: \(counter.formQuality.rawValue.replacingOccurrences(of: "form: ", with: "").uppercased())")
                        .font(Theme.mono(9.5, .semibold))
                        .tracking(0.4)
                        .foregroundStyle(formGood ? Theme.accent300 : Theme.neutral300)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Theme.surfaceTint.opacity(0.85), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Theme.accent800, lineWidth: 1))
                        .animation(.easeInOut(duration: 0.25), value: counter.formQuality)
                }
                .padding(12)

                Spacer()

                HStack(alignment: .lastTextBaseline, spacing: 9) {
                    Text(timeLabel(counter.heldSeconds))
                        .font(Theme.mono(48, .semibold))
                        .foregroundStyle(Theme.text)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text("of \(timeLabel(targetSeconds))")
                        .font(Theme.body(15))
                        .foregroundStyle(Theme.neutral500)
                    Spacer()
                    if !counter.isInPosition {
                        Text("PAUSED")
                            .font(Theme.mono(10, .semibold))
                            .foregroundStyle(Theme.accent400)
                    }
                }
                .padding(.horizontal, 15)
                .padding(.bottom, 16)
            }

            if counter.trackingStatus == .permissionDenied {
                cameraPermissionMessage
            }
        }
        .aspectRatio(3.0 / 4.0, contentMode: .fit)
    }

    private var cameraPermissionMessage: some View {
        VStack(spacing: 10) {
            Image(systemName: "camera.fill").font(.title2)
            Text("Camera access is required to track your hold")
                .font(Theme.body(14, .semibold))
                .multilineTextAlignment(.center)
            Link("Open Settings", destination: URL(string: UIApplication.openSettingsURLString)!)
                .font(Theme.body(14, .semibold))
                .foregroundStyle(Theme.accent400)
        }
        .foregroundStyle(Theme.text)
        .padding(20)
        .background(Theme.canvasDeep.opacity(0.92), in: RoundedRectangle(cornerRadius: 18))
        .padding(24)
    }

    private var statCard: some View {
        VStack(spacing: 11) {
            HStack(spacing: 13) {
                statColumn("Held only while in position", "")
                Spacer()
                statColumn("Unlocks", "+\(offer.unlockMinutes)m", tint: Theme.accent400, alignment: .trailing)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.accent900)
                    Capsule().fill(Theme.accent)
                        .shadow(color: Theme.accent.opacity(0.7), radius: 4)
                        .frame(width: geo.size.width * fraction)
                        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: fraction)
                }
            }
            .frame(height: 4)
        }
        .card()
    }

    private func statColumn(_ label: String, _ value: String, tint: Color = Theme.text, alignment: HorizontalAlignment = .leading) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            MicroLabel(text: label)
            if !value.isEmpty {
                Text(value)
                    .font(Theme.mono(16, .semibold))
                    .foregroundStyle(tint)
            }
        }
    }

    private func timeLabel(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
