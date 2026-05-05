import AVFoundation
import Observation
import SwiftUI

struct ElevenLabsVoiceBrowserView: View {
    @Environment(AppStateStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel = ElevenLabsVoiceBrowserViewModel()
    @State private var searchText = ""

    var body: some View {
        Group {
            switch viewModel.phase {
            case .needsAPIKey:
                missingKeyView
            case .loading where viewModel.voices.isEmpty:
                loadingView
            case .error(let message) where viewModel.voices.isEmpty:
                errorView(message)
            default:
                voicesList
            }
        }
        .navigationTitle("Voice")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search voices")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await viewModel.reload() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(viewModel.phase == .loading)
                .accessibilityLabel("Refresh voices")
            }
        }
        .task {
            await viewModel.loadIfNeeded()
        }
        .onDisappear {
            viewModel.stopPreview()
        }
    }

    private var voicesList: some View {
        List {
            if case .error(let message) = viewModel.phase {
                Section {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                }
            }

            ForEach(filteredGroups, id: \.category) { group in
                Section(ElevenLabsVoiceCategoryOrder.display(group.category)) {
                    ForEach(group.voices) { voice in
                        rowButton(for: voice)
                    }
                }
            }

            if filteredGroups.isEmpty && viewModel.phase != .loading {
                Section {
                    Text("No voices match this search.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { await viewModel.reload() }
    }

    private func rowButton(for voice: ElevenLabsVoice) -> some View {
        Button {
            select(voice)
        } label: {
            ElevenLabsVoiceRow(
                voice: voice,
                isSelected: voice.voiceID == store.state.settings.elevenLabsVoiceID,
                isPlaying: viewModel.playingVoiceID == voice.voiceID,
                isLoadingPreview: viewModel.loadingPreviewVoiceID == voice.voiceID,
                canPreview: voice.previewURL != nil,
                onTogglePreview: { viewModel.togglePreview(for: voice) }
            )
        }
        .buttonStyle(.plain)
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Loading voices")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36))
                .foregroundStyle(.orange)
            Text(message)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, AppTheme.Spacing.lg)
            Button {
                Task { await viewModel.reload() }
            } label: {
                Label("Try again", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.glassProminent)
            .tint(Color(red: 0, green: 0.78, blue: 0.62))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    private var missingKeyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform.slash")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("Connect ElevenLabs to browse voices")
                .font(.headline)
                .multilineTextAlignment(.center)
            Text("Add your ElevenLabs API key in the previous screen to load the voice library.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppTheme.Spacing.lg)
            Button {
                dismiss()
            } label: {
                Label("Back to ElevenLabs Settings", systemImage: "chevron.backward")
            }
            .buttonStyle(.glassProminent)
            .tint(Color(red: 0, green: 0.78, blue: 0.62))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    private var filteredGroups: [ElevenLabsVoiceGroup] {
        let terms = searchText.lowercased().split(whereSeparator: \.isWhitespace).map(String.init)
        let filtered: [ElevenLabsVoice]
        if terms.isEmpty {
            filtered = viewModel.voices
        } else {
            filtered = viewModel.voices.filter { voice in
                terms.allSatisfy { voice.searchText.contains($0) }
            }
        }
        let grouped = Dictionary(grouping: filtered, by: \.category)
        return grouped
            .map { ElevenLabsVoiceGroup(category: $0.key, voices: $0.value.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }) }
            .sorted { lhs, rhs in
                let l = ElevenLabsVoiceCategoryOrder.sortKey(lhs.category)
                let r = ElevenLabsVoiceCategoryOrder.sortKey(rhs.category)
                if l != r { return l < r }
                return lhs.category.localizedCaseInsensitiveCompare(rhs.category) == .orderedAscending
            }
    }

    private func select(_ voice: ElevenLabsVoice) {
        var settings = store.state.settings
        guard settings.elevenLabsVoiceID != voice.voiceID else { return }
        settings.elevenLabsVoiceID = voice.voiceID
        store.updateSettings(settings)
        Haptics.success()
    }
}

struct ElevenLabsVoiceGroup: Hashable {
    let category: String
    let voices: [ElevenLabsVoice]
}

@MainActor
@Observable
final class ElevenLabsVoiceBrowserViewModel {
    enum Phase: Equatable {
        case idle
        case loading
        case loaded
        case error(String)
        case needsAPIKey
    }

    private(set) var phase: Phase = .idle
    private(set) var voices: [ElevenLabsVoice] = []
    private(set) var playingVoiceID: String?
    private(set) var loadingPreviewVoiceID: String?

    private let service = ElevenLabsVoicesService()
    private let player = ElevenLabsPreviewPlayer()

    init() {
        Task { @MainActor [weak self] in
            let stream = NotificationCenter.default.notifications(named: .AVPlayerItemDidPlayToEndTime)
            for await _ in stream {
                guard let self else { return }
                self.handlePlaybackEnded()
            }
        }
    }

    func loadIfNeeded() async {
        guard voices.isEmpty, phase != .loading else { return }
        await reload()
    }

    func reload() async {
        let apiKey: String?
        do {
            apiKey = try ElevenLabsCredentialStore.loadAPIKey()
        } catch {
            apiKey = nil
        }
        guard let apiKey, !apiKey.isEmpty else {
            phase = .needsAPIKey
            voices = []
            return
        }

        phase = .loading
        do {
            let result = try await service.fetchVoices(apiKey: apiKey)
            voices = result
            phase = .loaded
        } catch ElevenLabsVoicesError.unauthorized {
            phase = .needsAPIKey
            voices = []
        } catch {
            phase = .error(error.localizedDescription)
        }
    }

    func togglePreview(for voice: ElevenLabsVoice) {
        if playingVoiceID == voice.voiceID {
            stopPreview()
            return
        }
        guard let url = voice.previewURL else { return }
        player.play(url: url)
        playingVoiceID = voice.voiceID
        loadingPreviewVoiceID = nil
        Haptics.light()
    }

    func stopPreview() {
        player.stop()
        playingVoiceID = nil
        loadingPreviewVoiceID = nil
    }

    private func handlePlaybackEnded() {
        playingVoiceID = nil
        loadingPreviewVoiceID = nil
    }
}

@MainActor
final class ElevenLabsPreviewPlayer {
    private var player: AVPlayer?

    func play(url: URL) {
        player?.pause()
        configureAudioSession()
        let item = AVPlayerItem(url: url)
        let newPlayer = AVPlayer(playerItem: item)
        newPlayer.automaticallyWaitsToMinimizeStalling = false
        player = newPlayer
        newPlayer.play()
    }

    func stop() {
        player?.pause()
        player = nil
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [])
        try? session.setActive(true, options: [])
    }
}
