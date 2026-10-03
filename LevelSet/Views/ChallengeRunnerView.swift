import SwiftUI

struct ChallengeRunnerView: View {
    let offer: ChallengeOffer
    let onFinished: (_ actualCount: Int, _ succeeded: Bool) -> Void

    var body: some View {
        switch offer.kind {
        case .pushups, .clapPushups:
            PushupChallengeView(offer: offer, onFinished: onFinished)
        case .jumpingJacks:
            JumpingJackChallengeView(offer: offer, onFinished: onFinished)
        case .plank, .wallSit:
            HoldPositionChallengeView(offer: offer, onFinished: onFinished)
        case .walk, .reading:
            TimedChallengeView(offer: offer, onFinished: onFinished)
        }
    }
}
