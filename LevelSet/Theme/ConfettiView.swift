import SwiftUI

private struct ConfettiPiece: Identifiable {
    let id = UUID()
    let x: CGFloat
    let fall: CGFloat
    let spin: Double
    let delay: Double
    let duration: Double
    let color: Color
    let width: CGFloat

    static func random(colors: [Color]) -> ConfettiPiece {
        ConfettiPiece(
            x: .random(in: -150...150),
            fall: .random(in: 260...460),
            spin: .random(in: 120...520),
            delay: .random(in: 0...0.25),
            duration: .random(in: 0.9...1.6),
            color: colors.randomElement() ?? Theme.accent,
            width: .random(in: 5...8)
        )
    }
}

struct ConfettiView: View {
    var count = 26

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pieces: [ConfettiPiece] = []
    @State private var launched = false

    var body: some View {
        ZStack {
            ForEach(pieces) { piece in
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(piece.color)
                    .frame(width: piece.width, height: piece.width * 1.6)
                    .rotationEffect(.degrees(launched ? piece.spin : 0))
                    .offset(x: piece.x, y: launched ? piece.fall : -60)
                    .opacity(launched ? 0 : 1)
                    .animation(
                        .easeIn(duration: piece.duration).delay(piece.delay),
                        value: launched
                    )
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            guard !reduceMotion else { return }
            pieces = (0..<count).map { _ in
                ConfettiPiece.random(colors: [Theme.accent, Theme.accent400, Theme.accent600])
            }
            launched = true
        }
    }
}
