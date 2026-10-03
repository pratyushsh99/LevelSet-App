import SwiftUI

struct LegalDocumentView: View {
    let title: String
    let filename: String

    @Environment(\.dismiss) private var dismiss
    @State private var body_: String = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(body_)
                    .font(Theme.body(14))
                    .foregroundStyle(Theme.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
            }
            .background(Theme.canvas)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear(perform: load)
    }

    private func load() {
        guard
            let url = Bundle.main.url(forResource: filename, withExtension: nil),
            let text = try? String(contentsOf: url, encoding: .utf8)
        else {
            body_ = "This document hasn't been added to the app bundle yet."
            return
        }
        body_ = text
    }
}
