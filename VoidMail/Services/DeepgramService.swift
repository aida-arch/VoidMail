import Foundation
import AVFoundation

// MARK: - Deepgram Text-to-Speech Service
// Converts email text to audio using Deepgram's TTS API.

@MainActor
class DeepgramService: ObservableObject {
    static let shared = DeepgramService()

    private let apiKey: String = {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "DEEPGRAM_API_KEY") as? String, !key.isEmpty else {
            return ""
        }
        return key
    }()
    private let baseURL = "https://api.deepgram.com/v1/speak"

    @Published var isGenerating = false
    @Published var isPlaying = false
    @Published var playbackProgress: Double = 0
    @Published var audioDuration: Double = 0
    @Published var error: String?

    private var audioPlayer: AVAudioPlayer?
    private var progressTimer: Timer?
    private var cachedAudioURLs: [String: URL] = [:]  // Cache audio by email ID

    // MARK: - Generate Audio from Email

    /// Generates TTS audio for an email body. Returns the local file URL.
    /// Splits long text into chunks to avoid Deepgram's payload size limit.
    func generateAudio(emailId: String, text: String, voice: String = "aura-asteria-en") async -> URL? {
        // Return cached audio if already generated
        if let cached = cachedAudioURLs[emailId] {
            return cached
        }

        isGenerating = true
        error = nil

        guard !apiKey.isEmpty else {
            error = "Deepgram API key not configured"
            isGenerating = false
            return nil
        }

        do {
            // Trim to reasonable max and split into chunks
            let trimmedText = String(text.prefix(5000))
            let chunks = splitIntoChunks(trimmedText, maxLength: 1500)

            var allAudioData = Data()

            for chunk in chunks {
                guard let chunkData = try await fetchTTSAudio(text: chunk, voice: voice) else {
                    continue
                }
                allAudioData.append(chunkData)
            }

            guard !allAudioData.isEmpty else {
                error = "Failed to generate audio"
                isGenerating = false
                return nil
            }

            // Save combined audio to temp file
            let tempDir = FileManager.default.temporaryDirectory
            let fileURL = tempDir.appendingPathComponent("voidmail_tts_\(emailId).mp3")
            try allAudioData.write(to: fileURL)
            cachedAudioURLs[emailId] = fileURL

            isGenerating = false
            return fileURL

        } catch {
            debugLog("[DeepgramService] generateAudio error: \(error.localizedDescription)")
            self.error = "Failed to generate audio"
            isGenerating = false
            return nil
        }
    }

    /// Fetch TTS audio for a single text chunk from Deepgram
    private func fetchTTSAudio(text: String, voice: String) async throws -> Data? {
        let urlString = "\(baseURL)?model=\(voice)&encoding=mp3"
        guard let url = URL(string: urlString) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let body: [String: Any] = ["text": text]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            debugLog("[DeepgramService] Chunk TTS error \(code)")
            return nil
        }

        return data
    }

    /// Split text into chunks at sentence boundaries, respecting maxLength
    private func splitIntoChunks(_ text: String, maxLength: Int) -> [String] {
        guard text.count > maxLength else { return [text] }

        var chunks: [String] = []
        var remaining = text

        while !remaining.isEmpty {
            if remaining.count <= maxLength {
                chunks.append(remaining)
                break
            }

            // Find the last sentence-ending punctuation within maxLength
            let searchRange = remaining.prefix(maxLength)
            var splitIndex = searchRange.startIndex

            // Look for sentence boundaries: . ! ? followed by space or end
            for char in [". ", "! ", "? ", ".\n", "!\n", "?\n"] {
                if let range = searchRange.range(of: char, options: .backwards) {
                    let candidate = range.upperBound
                    if candidate > splitIndex {
                        splitIndex = candidate
                    }
                }
            }

            // If no sentence boundary found, split at last space
            if splitIndex == searchRange.startIndex {
                if let spaceRange = searchRange.range(of: " ", options: .backwards) {
                    splitIndex = spaceRange.upperBound
                } else {
                    // No space found — hard split
                    splitIndex = remaining.index(remaining.startIndex, offsetBy: maxLength)
                }
            }

            let chunk = String(remaining[remaining.startIndex..<splitIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !chunk.isEmpty {
                chunks.append(chunk)
            }
            remaining = String(remaining[splitIndex...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return chunks
    }

    // MARK: - Play Audio

    func play(url: URL) {
        do {
            // Configure audio session
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)

            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
            audioDuration = audioPlayer?.duration ?? 0
            audioPlayer?.play()
            isPlaying = true

            // Start progress tracking
            startProgressTracking()
        } catch {
            debugLog("[DeepgramService] play error: \(error.localizedDescription)")
            self.error = "Failed to play audio"
        }
    }

    // MARK: - Pause

    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        stopProgressTracking()
    }

    // MARK: - Resume

    func resume() {
        audioPlayer?.play()
        isPlaying = true
        startProgressTracking()
    }

    // MARK: - Stop

    func stop() {
        audioPlayer?.stop()
        audioPlayer?.currentTime = 0
        isPlaying = false
        playbackProgress = 0
        stopProgressTracking()
    }

    // MARK: - Toggle Play/Pause

    func togglePlayPause(url: URL) {
        if isPlaying {
            pause()
        } else if audioPlayer != nil && audioPlayer?.currentTime ?? 0 > 0 {
            resume()
        } else {
            play(url: url)
        }
    }

    // MARK: - Seek

    func seek(to progress: Double) {
        guard let player = audioPlayer else { return }
        player.currentTime = progress * player.duration
        playbackProgress = progress
    }

    // MARK: - Progress Tracking

    private func startProgressTracking() {
        stopProgressTracking()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, let player = self.audioPlayer else { return }
                if player.isPlaying {
                    self.playbackProgress = player.currentTime / player.duration
                } else if player.currentTime >= player.duration - 0.1 {
                    // Playback finished
                    self.isPlaying = false
                    self.playbackProgress = 0
                    self.stopProgressTracking()
                }
            }
        }
    }

    private func stopProgressTracking() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    // MARK: - Format Duration

    static func formatDuration(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    // MARK: - Cleanup

    func clearCache() {
        for (_, url) in cachedAudioURLs {
            try? FileManager.default.removeItem(at: url)
        }
        cachedAudioURLs.removeAll()
    }

    func hasCachedAudio(for emailId: String) -> Bool {
        cachedAudioURLs[emailId] != nil
    }

    func cachedURL(for emailId: String) -> URL? {
        cachedAudioURLs[emailId]
    }
}
