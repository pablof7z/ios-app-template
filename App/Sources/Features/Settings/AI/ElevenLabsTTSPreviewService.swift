import AVFoundation
import Foundation

enum ElevenLabsTTSPreviewError: LocalizedError {
    case missingAPIKey
    case missingVoiceID
    case server(Int)
    case transport(String)
    case playback(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:    return "No ElevenLabs API key. Connect first."
        case .missingVoiceID:   return "No voice selected. Pick a voice first."
        case .server(let code): return "ElevenLabs error (HTTP \(code))."
        case .transport(let m): return m
        case .playback(let m):  return "Playback failed: \(m)"
        }
    }
}

@MainActor
final class ElevenLabsTTSPreviewService {
    private var audioPlayer: AVAudioPlayer?

    static let samplePhrase = "Hello! This is a preview of the selected ElevenLabs voice."

    func speak(voiceID: String, model: String) async throws {
        guard !voiceID.isEmpty else { throw ElevenLabsTTSPreviewError.missingVoiceID }

        let apiKey: String
        do {
            guard let key = try ElevenLabsCredentialStore.apiKey(), !key.isEmpty else {
                throw ElevenLabsTTSPreviewError.missingAPIKey
            }
            apiKey = key
        } catch let e as ElevenLabsTTSPreviewError {
            throw e
        } catch {
            throw ElevenLabsTTSPreviewError.missingAPIKey
        }

        let effectiveModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty ? "eleven_turbo_v2_5" : model.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let url = URL(string: "https://api.elevenlabs.io/v1/text-to-speech/\(voiceID)") else {
            throw ElevenLabsTTSPreviewError.transport("Invalid voice URL.")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("audio/mpeg", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 20

        let body: [String: Any] = [
            "text": Self.samplePhrase,
            "model_id": effectiveModel,
            "voice_settings": ["stability": 0.5, "similarity_boost": 0.75]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw ElevenLabsTTSPreviewError.transport(error.localizedDescription)
        }

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw ElevenLabsTTSPreviewError.server(http.statusCode)
        }

        configureAudioSession()
        do {
            let player = try AVAudioPlayer(data: data, fileTypeHint: "mp3")
            player.prepareToPlay()
            audioPlayer = player
            player.play()
        } catch {
            throw ElevenLabsTTSPreviewError.playback(error.localizedDescription)
        }
    }

    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [])
        try? session.setActive(true, options: [])
    }
}
