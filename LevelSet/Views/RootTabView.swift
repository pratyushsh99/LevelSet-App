import SwiftUI
import Combine

struct RootTabView: View {
    @State private var progress: UserProgress
    @State private var history: [ChallengeCompletion]

    @State private var showLock = false
    @State private var showPicker = false
    @State private var activeChallenge: ChallengeOffer?
    @State private var celebration: CelebrationPayload?
    @State private var hasWarnedLowTime = false
    @State private var dismissedLockManually = false

    @Environment(\.scenePhase) private var scenePhase

    init() {
        if let restoredProgress = PersistenceStore.loadProgress() {
            _progress = State(initialValue: restoredProgress)
            _history = State(initialValue: PersistenceStore.loadHistory() ?? [])
        } else {
            let seededProgress = UserProgress()
            let seededHistory = SampleData.seed(seededProgress)
            _progress = State(initialValue: seededProgress)
            _history = State(initialValue: seededHistory)
        }
    }

    private func persistAndSync() {
        PersistenceStore.saveProgress(progress)
        PersistenceStore.saveHistory(history)
        DesktopSyncService.syncStats(progress: progress, history: history)
    }

    var body: some View {
        Group {
            if progress.hasCompletedOnboarding {
                mainTabs
            } else {
                OnboardingFlowView(progress: progress) {
                    persistAndSync()
                }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                persistAndSync()
            }
        }
    }

    private var mainTabs: some View {
        TabView {
            HomeView(
                progress: progress,
                history: history,
                onEarnTime: { showPicker = true },
                onStartChallenge: { activeChallenge = $0 }
            )
                .tabItem { Label("Home", systemImage: "house.fill") }

            ProgressTabView(progress: progress, history: history)
                .tabItem { Label("Progress", systemImage: "chart.bar.fill") }

            RedeemView(progress: progress, history: history)
                .tabItem { Label("Redeem", systemImage: "sparkles") }

            ProfileView(progress: progress, history: history, onAccountDeleted: resetEverything)
                .tabItem { Label("Profile", systemImage: "person.crop.circle.fill") }
        }
        .id(progress.effectiveThemeName)
        .tint(Theme.accent)
        .toolbarBackground(Theme.canvas, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .fullScreenCover(isPresented: $showLock) {
            LockScreenView(
                progress: progress,
                history: history,
                onChooseChallenge: {
                    showLock = false
                    dismissedLockManually = true
                    showPicker = true
                },
                onUseXPInstead: {
                    showLock = false
                    dismissedLockManually = true
                }
            )
        }
        .sheet(isPresented: $showPicker) {
            ChallengePickerView(recentHistory: history) { offer in
                showPicker = false
                activeChallenge = offer
            }
        }
        .fullScreenCover(item: $activeChallenge) { offer in
            ChallengeRunnerView(offer: offer) { actualCount, succeeded in
                activeChallenge = nil
                let xpBefore = progress.xp
                recordCompletion(offer: offer, actualCount: actualCount, succeeded: succeeded)
                if succeeded {
                    celebration = CelebrationPayload(offer: offer, xpBefore: xpBefore)
                }
            }
        }
        .sheet(item: $celebration) { payload in
            let nextOffer = ChallengeEngine.bestReturn(among: ChallengeEngine.makeOffers(recentHistory: history))
            CelebrationView(
                offer: payload.offer,
                progress: progress,
                xpBefore: payload.xpBefore,
                nextOffer: nextOffer?.id != payload.offer.id ? nextOffer : nil,
                onStartNext: { activeChallenge = $0 }
            )
        }
        .onOpenURL { url in
            guard url.host == "challenge" else { return }
            showPicker = true
        }
        .onAppear {
            LiveActivityService.start(
                endDate: progress.budgetEndDate,
                dailyLimitMinutes: progress.dailyLimitMinutes,
                isLocked: progress.isLocked
            )
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { now in
            if progress.isLocked(asOf: now) {
                if !showLock && activeChallenge == nil && !showPicker && !dismissedLockManually {
                    showLock = true
                }
            } else {
                maybeWarnLowTime(asOf: now)
            }
        }
        .onChange(of: progress.budgetEndDate) { _, newEndDate in
            hasWarnedLowTime = false
            dismissedLockManually = false
            LiveActivityService.update(endDate: newEndDate, isLocked: progress.isLocked)
        }
    }

    private func recordCompletion(offer: ChallengeOffer, actualCount: Int, succeeded: Bool) {
        let completion = ChallengeCompletion(
            kind: offer.kind,
            targetCount: offer.targetCount,
            actualCount: actualCount,
            unlockMinutes: offer.unlockMinutes,
            rewardXP: offer.rewardXP,
            succeeded: succeeded
        )
        history.insert(completion, at: 0)
        if succeeded {
            progress.addXP(offer.rewardXP)
            progress.grantBonusMinutes(offer.unlockMinutes)
        }
        persistAndSync()
    }

    private func maybeWarnLowTime(asOf now: Date) {
        guard progress.notificationsEnabled, !hasWarnedLowTime else { return }
        let totalSeconds = progress.dailyLimitMinutes * 60
        let warnAt = min(60, totalSeconds / 2)
        guard progress.secondsRemaining(asOf: now) <= warnAt else { return }
        hasWarnedLowTime = true
        NotificationService.scheduleLowTimeWarning(minutesRemaining: progress.minutesRemaining)
    }

    private func resetEverything() {
        history = []
        hasWarnedLowTime = false
        LiveActivityService.end()
        progress = UserProgress()
        PersistenceStore.clear()
    }
}

struct CelebrationPayload: Identifiable {
    let offer: ChallengeOffer
    let xpBefore: Int
    var id: UUID { offer.id }
}
