import SwiftUI

struct AppSelectionView: View {
    let initiallySelected: Set<String>
    let onSave: (Set<String>) -> Void

    private struct MockApp: Identifiable {
        var id: String { name }
        let name: String
        let glyph: String
        let tint: Color
    }

    private let presetSocialApps: [MockApp] = [
        .init(name: "Instagram", glyph: "camera.fill", tint: .pink),
        .init(name: "TikTok", glyph: "music.note", tint: .white),
        .init(name: "YouTube", glyph: "play.rectangle.fill", tint: .red),
        .init(name: "Facebook", glyph: "person.2.fill", tint: .blue),
        .init(name: "Snapchat", glyph: "bolt.fill", tint: .yellow),
        .init(name: "X", glyph: "xmark", tint: .white),
    ]

    @State private var selected: Set<String>

    init(initiallySelected: Set<String> = [], onSave: @escaping (Set<String>) -> Void) {
        self.initiallySelected = initiallySelected
        self.onSave = onSave
        _selected = State(initialValue: initiallySelected)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        MicroLabel(text: "Apps that count against your budget")
                        Text("Pick which apps trigger the lock screen once you hit your daily limit.")
                            .font(Theme.body(12.5))
                            .foregroundStyle(Theme.textMuted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card()

                    VStack(spacing: 10) {
                        HStack {
                            MicroLabel(text: "Social media")
                            Spacer()
                            Button(selected.count == presetSocialApps.count ? "Deselect all" : "Select all") {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    if selected.count == presetSocialApps.count {
                                        selected.removeAll()
                                    } else {
                                        selected = Set(presetSocialApps.map(\.id))
                                    }
                                }
                            }
                            .font(Theme.body(12.5, .semibold))
                            .foregroundStyle(Theme.accent)
                        }
                        ForEach(presetSocialApps) { app in
                            appRow(app)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card()
                }
                .padding(18)
            }
            .background(Theme.canvas)
            .navigationTitle("Apps to limit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { onSave(selected) }
                }
            }
        }
    }

    private func appRow(_ app: MockApp) -> some View {
        let isOn = selected.contains(app.id)

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                if isOn { selected.remove(app.id) } else { selected.insert(app.id) }
            }
        } label: {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(app.tint.opacity(0.15))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: app.glyph)
                            .font(Theme.body(15))
                            .foregroundStyle(app.tint)
                    )
                Text(app.name)
                    .font(Theme.body(14.5, .medium))
                    .foregroundStyle(Theme.text)
                Spacer()
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 19))
                    .foregroundStyle(isOn ? Theme.accent400 : Theme.textFaint)
            }
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .accessibilityValue(isOn ? "Selected" : "Not selected")
        .buttonStyle(PressableRowStyle())
    }
}
