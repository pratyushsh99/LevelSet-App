import SwiftUI

struct ChallengePickerView: View {
    let recentHistory: [ChallengeCompletion]
    let onPick: (ChallengeOffer) -> Void

    @Environment(\.dismiss) private var dismiss

    private var offers: [ChallengeOffer] {
        ChallengeEngine.makeOffers(recentHistory: recentHistory)
    }

    private var bestOffer: ChallengeOffer? {
        ChallengeEngine.bestReturn(among: offers)
    }

    private var cameraOffers: [ChallengeOffer] {
        offers.filter { $0.id != bestOffer?.id && $0.kind.usesCamera }
    }

    private var offCameraOffers: [ChallengeOffer] {
        offers.filter { $0.id != bestOffer?.id && !$0.kind.usesCamera }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Make your next move")
                        .font(Theme.display(28, .semibold))
                        .foregroundStyle(Theme.text)
                    Text("Choose a challenge to earn screen time and XP. Difficulty adapts as you progress.")
                        .font(Theme.body(12))
                        .foregroundStyle(Theme.textFaint)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 4)

                    FadingRule()

                    if let bestOffer {
                        sectionHeader("Best return").padding(.top, 8)
                        offerRow(bestOffer, emphasized: true).staggered(0)
                    }

                    if !cameraOffers.isEmpty {
                        sectionHeader("Camera-tracked").padding(.top, 3)
                        ForEach(Array(cameraOffers.enumerated()), id: \.element.id) { index, offer in
                            offerRow(offer, emphasized: false).staggered(index + 1)
                        }
                    }

                    if !offCameraOffers.isEmpty {
                        sectionHeader("Off-camera").padding(.top, 3)
                        ForEach(Array(offCameraOffers.enumerated()), id: \.element.id) { index, offer in
                            offerRow(offer, emphasized: false).staggered(index + cameraOffers.count + 1)
                        }
                    }
                }
                .padding(20)
            }
            .background(Theme.canvas)
            .navigationTitle("Earn back time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.textMuted)
                }
            }
        }
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack(spacing: 8) {
            MicroLabel(text: title)
            FadingRule()
        }
    }

    private func offerRow(_ offer: ChallengeOffer, emphasized: Bool) -> some View {
        Button {
            onPick(offer)
        } label: {
            VStack(spacing: 9) {
                HStack(spacing: 11) {
                    IconTile(systemImage: offer.kind.glyph, size: 36, emphasized: emphasized)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(offer.kind.shortName)
                            .font(Theme.body(14, .medium))
                            .foregroundStyle(Theme.text)
                        Text(offer.shortSubtitle)
                            .font(Theme.body(10.5))
                            .foregroundStyle(Theme.textFaint)
                    }
                    Spacer(minLength: 6)
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("+\(offer.unlockMinutes)m")
                            .font(Theme.mono(15, .semibold))
                            .foregroundStyle(emphasized ? Theme.accent400 : Theme.text)
                        Text("+\(offer.rewardXP) XP")
                            .font(Theme.mono(9.5, .medium))
                            .foregroundStyle(Theme.textFaint)
                    }
                }

                if let genFraction = ChallengeEngine.relativeGenerosity(of: offer.kind) {
                    VStack(alignment: .leading, spacing: 8) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(emphasized ? Theme.accent900 : Theme.neutral900)
                                Capsule()
                                    .fill(emphasized ? Theme.accent : Theme.neutral700)
                                    .frame(width: geo.size.width * genFraction)
                            }
                        }
                        .frame(height: 3)
                        Text("\(ChallengeEngine.minutesPerUnit(for: offer.kind), specifier: "%.1f") min per \(offer.kind.unitLabel == "reps" ? "rep" : "unit")")
                            .font(Theme.mono(9.5, .medium))
                            .foregroundStyle(Theme.textMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .card(emphasized: emphasized)
        }
        .buttonStyle(PressableRowStyle())
    }
}
