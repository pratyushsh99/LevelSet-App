import SwiftUI

struct DailyLimitPickerView: View {
    let currentMinutes: Int
    let onSet: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedMinutes: Int

    init(currentMinutes: Int, onSet: @escaping (Int) -> Void) {
        self.currentMinutes = currentMinutes
        self.onSet = onSet
        _selectedMinutes = State(initialValue: currentMinutes)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Daily limit", selection: $selectedMinutes) {
                    ForEach(1...180, id: \.self) { minute in
                        Text("\(minute) min").tag(minute)
                    }
                }
                .pickerStyle(.wheel)
                .labelsHidden()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.canvas)
            .navigationTitle("Daily Limit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Set") {
                        onSet(selectedMinutes)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.height(320)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
    }
}
