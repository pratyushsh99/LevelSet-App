import SwiftUI

/// Debug tool for collecting labelled push-up sessions. See `Training/README.md`.
struct PushUpTrainingRecorderView: View {
    @StateObject private var recorder = PushUpTrainingRecorder()
    @Environment(\.dismiss) private var dismiss
    @AppStorage("pushUpTrainingParticipant") private var participant = ""
    @State private var label: PushUpRecordingLabel = .good
    @State private var awaitingSave = false
    @State private var reportedReps = 10
    @State private var saveError: String?
    @State private var confirmDeleteAll = false

    var body: some View {
        ZStack {
            Theme.lockGround.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    header

                    cameraPanel
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(Theme.hairline, lineWidth: 1)
                        )

                    if awaitingSave {
                        saveCard
                    } else if !recorder.isRecording {
                        setupCard
                        savedCard
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 16)
            }
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .bottom) {
                if !awaitingSave {
                    recordButton
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Theme.lockGround)
                }
            }
        }
        .onAppear { recorder.start() }
        .onDisappear { recorder.stop() }
        .alert("Couldn't save recording", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveError ?? "")
        }
        .confirmationDialog("Delete all \(recorder.savedRecordings.count) recordings?", isPresented: $confirmDeleteAll, titleVisibility: .visible) {
            Button("Delete all", role: .destructive) { recorder.deleteAllRecordings() }
        }
    }

    private var header: some View {
        HStack {
            Button { recorder.stop(); dismiss() } label: {
                Image(systemName: "xmark")
                    .font(Theme.body(15))
                    .foregroundStyle(Theme.text)
                    .frame(width: 44, height: 44)
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Theme.hairline, lineWidth: 1))
            }
            .accessibilityLabel("Close recorder")
            Spacer()
            Text("Push-up training data")
                .font(Theme.body(15, .medium))
                .foregroundStyle(Theme.text)
            Spacer()
            Color.clear.frame(width: 44)
        }
    }

    private var cameraPanel: some View {
        ZStack {
            CameraPreviewView(session: recorder.session)
            SkeletonOverlayView(model: recorder.skeleton)

            VStack {
                HStack {
                    Text(recorder.trackingStatus.label.uppercased())
                        .font(Theme.mono(9.5, .semibold))
                        .tracking(0.6)
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Theme.canvasDeep.opacity(0.7), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    Spacer()
                    if recorder.isRecording {
                        HStack(spacing: 6) {
                            Circle().fill(Color.red).frame(width: 8, height: 8)
                            Text(String(format: "REC %.0fs", recorder.elapsed))
                                .font(Theme.mono(11, .semibold))
                                .monospacedDigit()
                                .foregroundStyle(Theme.text)
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Theme.canvasDeep.opacity(0.7), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
                .padding(12)
                Spacer()
            }
        }
        .aspectRatio(3.0 / 4.0, contentMode: .fit)
    }

    private var setupCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                MicroLabel(text: "Participant")
                TextField("Initials", text: $participant)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .font(Theme.mono(14, .medium))
                    .foregroundStyle(Theme.text)
            }

            VStack(alignment: .leading, spacing: 8) {
                MicroLabel(text: "What you'll do")
                FlowingLabelPicker(selection: $label)
                Text(label.instructions)
                    .font(Theme.body(13))
                    .foregroundStyle(Theme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("Prop the phone where you would for a real challenge and change the angle between sessions. Only pose points are saved, never video.")
                .font(Theme.body(12))
                .foregroundStyle(Theme.textFaint)
                .fixedSize(horizontal: false, vertical: true)
        }
        .card()
    }

    private var saveCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            MicroLabel(text: label.title)
            if label.countsReps {
                Stepper(value: $reportedReps, in: 0...200) {
                    HStack {
                        Text("Reps you did").font(Theme.body(14)).foregroundStyle(Theme.text)
                        Spacer()
                        Text("\(reportedReps)").font(Theme.mono(16, .semibold)).foregroundStyle(Theme.text)
                    }
                }
                Text("Count every rep, including bad ones. The trainer checks this against the motion it detects.")
                    .font(Theme.body(12))
                    .foregroundStyle(Theme.textFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("\(Int(recorder.elapsed)) s, body visible in \(recorder.visibleFrameCount) frames")
                .font(Theme.mono(11, .medium))
                .foregroundStyle(Theme.textFaint)
            HStack(spacing: 10) {
                Button("Discard") { awaitingSave = false }
                    .buttonStyle(SoftButtonStyle())
                Button("Save") {
                    do {
                        try recorder.save(label: label, participant: participant, reportedReps: reportedReps)
                        awaitingSave = false
                    } catch {
                        saveError = error.localizedDescription
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .card()
    }

    private var savedCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            MicroLabel(text: "Saved recordings")
            let counts = Dictionary(grouping: recorder.savedRecordings) {
                $0.lastPathComponent.split(separator: "-").first.map(String.init) ?? ""
            }
            ForEach(PushUpRecordingLabel.allCases, id: \.self) { item in
                HStack {
                    Text(item.title).font(Theme.body(13)).foregroundStyle(Theme.text)
                    Spacer()
                    Text("\(counts[item.rawValue]?.count ?? 0)")
                        .font(Theme.mono(13, .medium))
                        .foregroundStyle(Theme.textMuted)
                }
            }
            if !recorder.savedRecordings.isEmpty {
                HStack(spacing: 10) {
                    ShareLink(items: recorder.savedRecordings) {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(SoftButtonStyle())
                    Button("Delete all", role: .destructive) { confirmDeleteAll = true }
                        .buttonStyle(SoftButtonStyle(tint: Color(hex: 0xE36B6B), borderColor: Color(hex: 0xE36B6B).opacity(0.4)))
                }
                .padding(.top, 4)
            }
        }
        .card()
    }

    private var recordButton: some View {
        Group {
            if recorder.isRecording {
                Button("Stop recording") {
                    recorder.endRecording()
                    awaitingSave = true
                }
                .buttonStyle(PrimaryButtonStyle(tint: Color(hex: 0xE36B6B)))
            } else {
                Button("Start recording") { recorder.beginRecording() }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(participant.trimmingCharacters(in: .whitespaces).isEmpty
                              || recorder.trackingStatus == .permissionDenied)
            }
        }
    }
}

private struct FlowingLabelPicker: View {
    @Binding var selection: PushUpRecordingLabel

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(PushUpRecordingLabel.allCases, id: \.self) { item in
                let selected = item == selection
                Button(item.title) { selection = item }
                    .font(Theme.body(12, .medium))
                    .foregroundStyle(selected ? Theme.canvas : Theme.text)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(selected ? Theme.accent : Theme.surfaceTint, in: Capsule())
            }
        }
    }
}
