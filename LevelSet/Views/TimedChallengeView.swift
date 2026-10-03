import SwiftUI

struct TimedChallengeView: View {
    let offer: ChallengeOffer
    let onFinished: (_ actualCount: Int, _ succeeded: Bool) -> Void

    @State private var secondsRemaining: Int
    @State private var totalSeconds: Int
    @State private var timer: Timer?

    init(offer: ChallengeOffer, onFinished: @escaping (Int, Bool) -> Void) {
        self.offer = offer
        self.onFinished = onFinished
        let seconds = offer.targetCount * 60
        _secondsRemaining = State(initialValue: seconds)
        _totalSeconds = State(initialValue: seconds)
    }

    private var fraction: Double {
        1 - Double(secondsRemaining) / Double(max(1, totalSeconds))
    }

    var body: some View {
        ZStack {
            Theme.lockGround.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 26) {
                    VStack(spacing: 6) {
                        Image(systemName: offer.kind.glyph)
                            .font(.system(size: 32, weight: .medium))
                            .foregroundStyle(Theme.accent400)
                        Text(offer.kind.shortName)
                            .font(.system(size: 23, weight: .medium))
                            .foregroundStyle(Theme.text)
                    }

                    ZStack {
                        RingProgress(progress: fraction, lineWidth: 12)
                        VStack(spacing: 2) {
                            Text(timeLabel)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .font(Theme.mono(40, .semibold))
                                .foregroundStyle(Theme.text)
                                .monospacedDigit()
                                .contentTransition(.numericText())
                            MicroLabel(text: "remaining")
                        }
                    }
                    .frame(width: 200, height: 200)

                    Text(timedChallengeCopy)
                        .font(Theme.body(12.5))
                        .foregroundStyle(Theme.textMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)

                    Spacer()

                    Button("End challenge") {
                        timer?.invalidate()
                        onFinished(0, false)
                    }
                    .buttonStyle(SoftButtonStyle())
                    .padding(.horizontal, 20)
                }
                .padding(.top, 50)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .onAppear(perform: startTimer)
        .onDisappear { timer?.invalidate() }
    }

    private var timeLabel: String {
        String(format: "%02d:%02d", secondsRemaining / 60, secondsRemaining % 60)
    }

    private var timedChallengeCopy: String {
        switch offer.kind {
        case .walk: return "Will verify against step count once Motion access is granted."
        default: return "Just needs the timer to run out — no sensor required."
        }
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { t in
            if secondsRemaining <= 1 {
                t.invalidate()
                onFinished(offer.targetCount, true)
            } else {
                withAnimation(.easeInOut(duration: 0.3)) {
                    secondsRemaining -= 1
                }
            }
        }
    }
}
