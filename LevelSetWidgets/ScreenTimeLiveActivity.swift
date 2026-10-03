import ActivityKit
import WidgetKit
import SwiftUI

private enum WidgetColor {
    static let pine = Color(red: 0.09, green: 0.20, blue: 0.17)
    static let gold = Color(red: 0.878, green: 0.596, blue: 0.184)
    static let grass = Color(red: 0.31, green: 0.56, blue: 0.29)
}

struct ScreenTimeLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ScreenTimeActivityAttributes.self) { context in
            lockScreenView(context: context)
                .activityBackgroundTint(WidgetColor.pine)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "leaf.fill")
                        .foregroundStyle(WidgetColor.gold)
                        .font(.title3)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.isLocked {
                        Text("Locked")
                            .font(.headline)
                            .foregroundStyle(.white)
                    } else {
                        Text(timerInterval: Date.now...context.state.endDate, countsDown: true)
                            .font(.system(.title3, design: .rounded).monospacedDigit())
                            .foregroundStyle(.white)
                            .frame(width: 64)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.isLocked
                         ? "Open LevelSet to earn more time"
                         : "until your apps lock")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                }
            } compactLeading: {
                Image(systemName: "leaf.fill")
                    .foregroundStyle(WidgetColor.gold)
            } compactTrailing: {
                if context.state.isLocked {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(WidgetColor.gold)
                } else {
                    Text(timerInterval: Date.now...context.state.endDate, countsDown: true)
                        .font(.system(.caption, design: .rounded).monospacedDigit())
                        .frame(width: 44)
                }
            } minimal: {
                Image(systemName: "leaf.fill")
                    .foregroundStyle(WidgetColor.gold)
            }
            .widgetURL(URL(string: "levelset://home"))
            .keylineTint(WidgetColor.gold)
        }
    }

    private func lockScreenView(context: ActivityViewContext<ScreenTimeActivityAttributes>) -> some View {
        HStack(spacing: 14) {
            Image(systemName: context.state.isLocked ? "lock.fill" : "leaf.fill")
                .font(.title2)
                .foregroundStyle(WidgetColor.gold)

            VStack(alignment: .leading, spacing: 3) {
                Text(context.state.isLocked ? "Screen time locked" : "Screen time remaining")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))

                if context.state.isLocked {
                    Text("Open LevelSet to earn more time")
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(.white)
                } else {
                    Text(timerInterval: Date.now...context.state.endDate, countsDown: true)
                        .font(.system(.title2, design: .rounded).monospacedDigit())
                        .foregroundStyle(.white)
                }
            }
            Spacer()
        }
        .padding(16)
    }
}
