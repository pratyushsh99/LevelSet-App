import SwiftUI

struct ProfileView: View {
    @Bindable var progress: UserProgress
    let history: [ChallengeCompletion]
    let onAccountDeleted: () -> Void

    @State private var showAppSelection = false
    @State private var showDailyLimitPicker = false
    @State private var showLinkDesktop = false
    @State private var showPushUpRecorder = false
    @State private var debugXPInput = ""
    @ObservedObject private var iconService = AppIconService.shared

    private let milestones = [3, 7, 14, 30]

    private var displayName: String {
        progress.displayName?.isEmpty == false ? progress.displayName! : "LevelSeter"
    }

    private var totalMinutesEarned: Int {
        history.filter(\.succeeded).reduce(0) { $0 + $1.unlockMinutes }
    }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var statsLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16))
            : AnyLayout(HStackLayout(spacing: 12))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Text("Profile")
                        .font(Theme.display(34, .semibold))
                        .foregroundStyle(Theme.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .staggered(0)

                    profileCard.staggered(0)
                    limitsSection.staggered(1)
                    themesSection.staggered(2)
                    milestonesSection.staggered(3)
                    deleteSection.staggered(4)
                    debugSection.staggered(5)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .background(Theme.canvas)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showAppSelection) {
                AppSelectionView(initiallySelected: Set(progress.limitedAppNames)) { names in
                    progress.limitedAppNames = Array(names)
                    showAppSelection = false
                }
            }
            .sheet(isPresented: $showDailyLimitPicker) {
                DailyLimitPickerView(currentMinutes: progress.dailyLimitMinutes) { minutes in
                    progress.setDailyLimit(minutes: minutes)
                }
            }
            .fullScreenCover(isPresented: $showLinkDesktop) {
                LinkDesktopView {
                    DesktopSyncService.syncBalance(secondsRemaining: progress.secondsRemaining())
                }
            }
            .fullScreenCover(isPresented: $showPushUpRecorder) {
                PushUpTrainingRecorderView()
            }
        }
    }

    private var profileCard: some View {
        VStack(spacing: 13) {
            HStack(spacing: 13) {
                IconTile(systemImage: "leaf.fill", size: 48, radius: 12)
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayName)
                        .font(Theme.body(17, .medium))
                        .foregroundStyle(Theme.text)
                    Text("Tier \(progress.tierIndex + 1) · \(progress.currentTier.name)")
                        .font(Theme.body(11))
                        .foregroundStyle(Theme.textFaint)
                }
                Spacer()
            }

            FadingRule()

            statsLayout {
                statColumn("\(history.filter(\.succeeded).count)", "challenges")
                statColumn("\(totalMinutesEarned)m", "earned")
                statColumn("\(progress.xp)", "XP")
                statColumn("\(progress.currentStreak)", "day streak", tint: Theme.accent400)
            }
        }
        .card()
    }

    private func statColumn(_ value: String, _ label: String, tint: Color = Theme.text) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(Theme.mono(17, .semibold))
                .foregroundStyle(tint)
            Text(label)
                .font(Theme.body(10))
                .foregroundStyle(Theme.textFaint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var limitsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) { MicroLabel(text: "Limits"); FadingRule() }
            VStack(spacing: 0) {
                limitRow(icon: "iphone", title: "Apps to limit", value: "\(progress.limitedAppNames.count) apps") { showAppSelection = true }
                FadingRule()
                limitRow(icon: "hourglass", title: "Daily limit", value: "\(progress.dailyLimitMinutes) min") { showDailyLimitPicker = true }
                FadingRule()
                HStack(spacing: 13) {
                    Image(systemName: "bell").font(Theme.body(16)).foregroundStyle(Theme.neutral400).frame(width: 20)
                    Text("Low-time warning").font(Theme.body(14)).foregroundStyle(Theme.text)
                    Spacer()
                    Toggle("Low-time warning", isOn: $progress.notificationsEnabled)
                        .labelsHidden()
                        .tint(Theme.accent)
                        .onChange(of: progress.notificationsEnabled) { _, enabled in
                            guard enabled else { return }
                            Task { _ = await NotificationService.requestAuthorization() }
                        }
                }
                .padding(.vertical, 15)
                FadingRule()
                limitRow(
                    icon: "laptopcomputer",
                    title: "Link Desktop",
                    value: DesktopSyncService.isPaired ? "Linked" : "Not linked"
                ) { showLinkDesktop = true }
            }
            .padding(.horizontal, 14)
            .card(padding: 0)
        }
    }

    private func limitRow(icon: String, title: String, value: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 13) {
                Image(systemName: icon).font(Theme.body(16)).foregroundStyle(Theme.neutral400).frame(width: 20)
                Text(title).font(Theme.body(14)).foregroundStyle(Theme.text)
                Spacer()
                Text(value).font(Theme.mono(12.5, .medium)).foregroundStyle(Theme.textFaint)
                Image(systemName: "chevron.right").font(Theme.body(12)).foregroundStyle(Theme.neutral700)
            }
            .padding(.vertical, 15)
        }
        .buttonStyle(PressableRowStyle())
    }

    private var themesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) { MicroLabel(text: "Themes"); FadingRule() }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 135), spacing: 12)], spacing: 12) {
                ForEach(Array(UserProgress.tiers.enumerated()), id: \.offset) { _, tier in
                    themeTile(tier)
                }
            }
        }
    }

    private func themeTile(_ tier: ProgressTier) -> some View {
        let unlocked = progress.xp >= tier.xpRequired
        let inUse = tier.name == progress.effectiveThemeName

        return Button {
            guard unlocked else { return }
            progress.selectTheme(named: tier.name)
        } label: {
            VStack(spacing: 6) {
                Image(systemName: unlocked ? tierGlyph(tier.name) : "lock.fill")
                    .font(.system(size: 19))
                    .foregroundStyle(unlocked ? Theme.accent400 : Theme.textFaint)
                Text(tier.name)
                    .font(Theme.body(11, .medium))
                    .foregroundStyle(Theme.text)
                Text(unlocked ? (inUse ? "In use" : "Unlocked") : "\(tier.xpRequired) XP")
                    .font(Theme.mono(12, .medium))
                    .foregroundStyle(inUse ? Theme.accent600 : Theme.textFaint)
            }
            .frame(maxWidth: .infinity)
            .card(padding: 11, emphasized: inUse)
            .opacity(unlocked ? 1 : 0.8)
        }
        .buttonStyle(.plain)
        .disabled(!unlocked)
    }

    private func tierGlyph(_ name: String) -> String {
        switch name {
        case "Pine Trail": return "tree.fill"
        case "Sunrise": return "sunrise.fill"
        case "Tidepool": return "water.waves"
        default: return "moon.stars.fill"
        }
    }

    private var milestonesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) { MicroLabel(text: "Streak milestones"); FadingRule() }
            HStack(spacing: 0) {
                ForEach(Array(milestones.enumerated()), id: \.offset) { index, day in
                    milestoneNode(day)
                    if index < milestones.count - 1 {
                        Rectangle()
                            .fill(progress.currentStreak >= day ? Theme.accent : Theme.hairline)
                            .frame(height: 2)
                            .padding(.bottom, 16)
                    }
                }
            }
            .card()
        }
    }

    private func milestoneNode(_ day: Int) -> some View {
        let done = progress.currentStreak >= day
        let isNext = !done && milestones.first { progress.currentStreak < $0 } == day

        return VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(done ? Theme.accent : Theme.surface)
                    .overlay(Circle().stroke(isNext ? Theme.accent : Theme.hairline, lineWidth: isNext ? 1.5 : (done ? 0 : 1)))
                    .frame(width: 22, height: 22)
                if done {
                    Image(systemName: "checkmark").font(Theme.body(11, .bold)).foregroundStyle(Theme.canvas)
                } else {
                    Text("\(day)").font(Theme.mono(9.5, .medium)).foregroundStyle(isNext ? Theme.accent400 : Theme.textFaint)
                }
            }
            Text(done ? "\(day)" : "\(day - progress.currentStreak) left")
                .font(Theme.mono(9.5, .medium))
                .foregroundStyle(done ? Theme.accent400 : Theme.textFaint)
        }
    }

    private var deleteSection: some View {
        VStack(spacing: 8) {
            NavigationLink {
                DeleteAccountWarningView(expectedName: displayName, onConfirmed: onAccountDeleted)
            } label: {
                Text("Delete Account")
            }
            .buttonStyle(SoftButtonStyle(tint: Color(hex: 0xE36B6B), borderColor: Color(hex: 0xE36B6B).opacity(0.4)))

            Text("Everything from your account will be deleted, including your XP, level, streak, and history.")
                .font(Theme.body(10))
                .foregroundStyle(Theme.textFaint)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.top, 4)
    }

    private var debugSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) { MicroLabel(text: "Debug"); FadingRule() }
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    Text("XP").font(Theme.body(14)).foregroundStyle(Theme.text)
                    Spacer()
                    TextField("\(progress.xp)", text: $debugXPInput)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .font(Theme.mono(14, .medium))
                        .foregroundStyle(Theme.text)
                        .frame(width: 90)
                    Button("Set") {
                        guard let value = Int(debugXPInput) else { return }
                        progress.xp = max(0, value)
                        debugXPInput = ""
                    }
                    .font(Theme.body(13, .semibold))
                    .foregroundStyle(Theme.accent)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Theme").font(Theme.body(14)).foregroundStyle(Theme.text)
                    HStack(spacing: 8) {
                        ForEach(UserProgress.tiers, id: \.name) { tier in
                            let selected = tier.name == progress.effectiveThemeName
                            Button(tier.name) {
                                progress.xp = max(progress.xp, tier.xpRequired)
                                progress.selectTheme(named: tier.name)
                            }
                            .font(Theme.body(12, .medium))
                            .foregroundStyle(selected ? Theme.canvas : Theme.text)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(selected ? Theme.accent : Theme.surfaceTint, in: Capsule())
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("App icon").font(Theme.body(14)).foregroundStyle(Theme.text)
                        Spacer()
                        Button("Reapply") {
                            iconService.apply(themeName: progress.effectiveThemeName)
                        }
                        .font(Theme.body(13, .semibold))
                        .foregroundStyle(Theme.accent)
                    }
                    Text("Current: \(iconService.currentIconName)")
                        .font(Theme.mono(11, .medium))
                        .foregroundStyle(Theme.textFaint)
                    Text(iconService.status)
                        .font(Theme.body(11))
                        .foregroundStyle(Theme.textFaint)
                        .fixedSize(horizontal: false, vertical: true)
                }

                #if DEBUG
                HStack {
                    Text("Push-up training data").font(Theme.body(14)).foregroundStyle(Theme.text)
                    Spacer()
                    Button("Record") { showPushUpRecorder = true }
                        .font(Theme.body(13, .semibold))
                        .foregroundStyle(Theme.accent)
                }
                #endif
            }
            .padding(14)
            .card(padding: 0)
        }
    }
}
