import SwiftUI
import UIKit

struct PushupChallengeView: View {
    let offer: ChallengeOffer
    let onFinished: (_ actualCount: Int, _ succeeded: Bool) -> Void

    @StateObject private var counter = PushupCounter()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var repBump = false
    @State private var livePulse = false
    @State private var repLedger: [PushUpFeedback] = []

    private var fraction: Double {
        min(1, Double(counter.repCount) / Double(max(1, offer.targetCount)))
    }

    private var formGood: Bool { counter.formQuality == .good }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var statsLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16))
            : AnyLayout(HStackLayout(spacing: 12))
    }

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
                    if !repLedger.isEmpty { repLedgerStrip }

                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 16)
            }
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .bottom) {
                Button("End challenge") {
                    counter.stop()
                    onFinished(counter.repCount, false)
                }
                .buttonStyle(SoftButtonStyle())
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Theme.lockGround)
            }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: counter.repCount)
        .onAppear {
            counter.start(targetReps: offer.targetCount) {
                onFinished(offer.targetCount, true)
            }
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                livePulse = true
            }
        }
        .onDisappear { counter.stop() }
        .onChange(of: counter.repCount) { _, newValue in
            guard newValue > 0 else { return }
            repLedger.append(counter.formQuality)
            guard !reduceMotion else { return }
            withAnimation(.spring(response: 0.22, dampingFraction: 0.45)) { repBump = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.65)) { repBump = false }
            }
        }
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
            Text("\(offer.kind == .clapPushups ? "Clap pushups" : "Pushups") · \(offer.targetCount) reps")
                .font(Theme.body(15, .medium))
                .foregroundStyle(Theme.text)
            Spacer()
            Color.clear.frame(width: 44)
        }
    }

    private var cameraPanel: some View {
        ZStack {
            CameraPreviewView(session: counter.session)

            SkeletonOverlayView(model: counter.skeleton)

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
                    Text("\(counter.repCount)")
                        .font(Theme.mono(56, .semibold))
                        .foregroundStyle(Theme.text)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .scaleEffect(repBump ? 1.14 : 1)
                    Text("/ \(offer.targetCount)")
                        .font(Theme.body(15))
                        .foregroundStyle(Theme.neutral500)
                    Spacer()
                    if let state = counter.pushUpState {
                        Text(stateLabel(state))
                            .font(Theme.mono(11, .semibold))
                            .tracking(0.6)
                            .foregroundStyle(state == .transition ? Theme.neutral300 : Theme.accent300)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(Theme.canvasDeep.opacity(0.7), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .animation(.easeInOut(duration: 0.15), value: state)
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

    private func stateLabel(_ state: PushUpState) -> String {
        switch state {
        case .up: return "UP"
        case .down: return "DOWN"
        case .transition: return "MOVING"
        }
    }

    private var cameraPermissionMessage: some View {
        VStack(spacing: 10) {
            Image(systemName: "camera.fill")
                .font(.title2)
            Text("Camera access is required to count reps")
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
            statsLayout {
                statColumn("Remaining", "\(max(0, offer.targetCount - counter.repCount)) reps")
                if !dynamicTypeSize.isAccessibilitySize {
                    Rectangle().fill(Theme.hairline).frame(width: 1, height: 32)
                }
                statColumn("Unlocks", "+\(offer.unlockMinutes)m", tint: Theme.accent400)
                if !dynamicTypeSize.isAccessibilitySize {
                    Rectangle().fill(Theme.hairline).frame(width: 1, height: 32)
                }
                statColumn("Reward", "+\(offer.rewardXP)")
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

    private func statColumn(_ label: String, _ value: String, tint: Color = Theme.text) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            MicroLabel(text: label)
            Text(value)
                .font(Theme.mono(16, .semibold))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var repLedgerStrip: some View {
        VStack(alignment: .leading, spacing: 7) {
            MicroLabel(text: "Rep ledger")
            HStack(spacing: 4) {
                ForEach(Array(repLedger.enumerated()), id: \.offset) { index, quality in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(quality == .good ? Theme.accent : Theme.neutral700)
                        .frame(height: 16)
                        .overlay(alignment: .bottom) {
                            if quality != .good {
                                Text("\(index + 1)")
                                    .font(Theme.body(7, .bold))
                                    .foregroundStyle(Theme.canvasDeep)
                            }
                        }
                }
            }
            .frame(height: 16)
        }
        .card(padding: 12)
    }
}
