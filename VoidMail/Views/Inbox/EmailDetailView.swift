import SwiftUI
import QuickLook
import AVFoundation

struct EmailDetailView: View {
    let email: Email
    @Environment(\.dismiss) private var dismiss
    @StateObject private var tts = DeepgramService.shared
    @State private var showReplySheet = false
    @State private var replyType: ReplyType = .reply
    @State private var aiSummary: String?
    @State private var isLoadingSummary = false
    @State private var smartReplies: [String] = []
    @State private var downloadingAttachmentId: String?
    @State private var previewURL: URL?
    @State private var translatedBody: String?
    @State private var isTranslating = false
    @State private var showTranslateMenu = false
    @State private var translateError: String?
    @State private var audioURL: URL?

    enum ReplyType { case reply, replyAll, forward }

    var body: some View {
        ZStack {
            Color.bgDeep.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // MARK: Big Subject
                    Text(email.subject)
                        .font(Typo.title2)
                        .foregroundColor(.textPrimary)
                        .tracking(-0.5)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)

                    // MARK: Sender Info
                    senderHeader
                        .padding(.horizontal, 20)
                        .padding(.top, 20)

                    VoidDivider()
                        .padding(.horizontal, 20)
                        .padding(.top, 16)

                    // MARK: AI Summary
                    if isLoadingSummary {
                        HStack(spacing: 8) {
                            ProgressView().tint(.accentSkyBlue)
                            Text("GENERATING SUMMARY...")
                                .font(Typo.mono)
                                .foregroundColor(.accentSkyBlue)
                                .tracking(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                    } else if let summary = aiSummary ?? email.aiSummary {
                        AISummaryCard(summary: summary)
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                    }

                    // MARK: AI Translate
                    if isTranslating {
                        HStack(spacing: 8) {
                            ProgressView().tint(.accentPink)
                            Text("TRANSLATING...")
                                .font(Typo.mono)
                                .foregroundColor(.accentPink)
                                .tracking(1)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                    }

                    if let error = translateError {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 13))
                            Text(error)
                                .font(Typo.mono)
                        }
                        .foregroundColor(.accentYellow)
                        .padding(.horizontal, 20)
                        .padding(.top, 6)
                    }

                    HStack(spacing: 10) {
                        Menu {
                            Button("Spanish") { Task { await translateTo("Spanish") } }
                            Button("French") { Task { await translateTo("French") } }
                            Button("German") { Task { await translateTo("German") } }
                            Button("Japanese") { Task { await translateTo("Japanese") } }
                            Button("Hindi") { Task { await translateTo("Hindi") } }
                            Button("Chinese (Simplified)") { Task { await translateTo("Chinese (Simplified)") } }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "globe")
                                    .font(.system(size: 14))
                                Text("AI TRANSLATE")
                                    .font(Typo.mono)
                                    .tracking(0.5)
                            }
                            .foregroundColor(.accentPink)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.accentPink.opacity(0.1))
                            .cornerRadius(8)
                        }
                        .disabled(isTranslating)

                        if translatedBody != nil {
                            Button {
                                translatedBody = nil
                                translateError = nil
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.uturn.backward")
                                        .font(.system(size: 12))
                                    Text("ORIGINAL")
                                        .font(Typo.mono)
                                        .tracking(0.5)
                                }
                                .foregroundColor(.textSecondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.bgCard)
                                .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)

                    // MARK: Listen to Email (TTS)
                    audioPlayerSection
                        .padding(.horizontal, 20)
                        .padding(.top, 12)

                    // MARK: Email Body — 16px readable
                    Text(translatedBody ?? email.body)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.textSecondary)
                        .lineSpacing(6)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)

                    // MARK: Attachments — Downloadable
                    if !email.attachments.isEmpty {
                        attachmentsSection
                            .padding(.top, 24)
                    }

                    // MARK: Smart Replies
                    if !smartReplies.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            SectionDivider(label: "Quick Replies")
                                .padding(.horizontal, 20)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(smartReplies, id: \.self) { reply in
                                        Button {
                                            replyType = .reply
                                            showReplySheet = true
                                        } label: {
                                            Text(reply)
                                                .font(Typo.subhead)
                                                .foregroundColor(.accentSkyBlue)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                                .background(Color.accentSkyBlue.opacity(0.1))
                                                .cornerRadius(8)
                                        }
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                        .padding(.top, 16)
                    }

                    Spacer().frame(height: 40)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 14) {
                    // Quick reply actions
                    Button {
                        replyType = .reply
                        showReplySheet = true
                    } label: {
                        Image(systemName: "arrowshape.turn.up.left")
                            .font(.system(size: 15))
                            .foregroundColor(.accentSkyBlue)
                    }
                    Button {
                        replyType = .replyAll
                        showReplySheet = true
                    } label: {
                        Image(systemName: "arrowshape.turn.up.left.2")
                            .font(.system(size: 15))
                            .foregroundColor(.accentGreen)
                    }
                    Button {
                        replyType = .forward
                        showReplySheet = true
                    } label: {
                        Image(systemName: "arrowshape.turn.up.right")
                            .font(.system(size: 15))
                            .foregroundColor(.accentPink)
                    }

                    // Existing actions
                    Button {
                        Task { await GmailService.shared.toggleStar(email.id) }
                    } label: {
                        Image(systemName: email.isStarred ? "star.fill" : "star")
                            .foregroundColor(email.isStarred ? .accentPink : .textTertiary)
                    }
                    Button {
                        Task { await GmailService.shared.archiveEmail(email.id) }
                        dismiss()
                    } label: {
                        Image(systemName: "archivebox")
                            .foregroundColor(.textTertiary)
                    }
                    Button {
                        Task { await GmailService.shared.deleteEmail(email.id) }
                        dismiss()
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.textTertiary)
                    }
                }
            }
        }
        .toolbarBackground(Color.bgDeep, for: .navigationBar)
        .sheet(isPresented: $showReplySheet) {
            ComposeView(replyTo: email, replyType: replyType)
        }
        .quickLookPreview($previewURL)
        .task {
            // Generate AI summary if not already available
            if email.aiSummary == nil && aiSummary == nil {
                isLoadingSummary = true
                aiSummary = await GeminiService.shared.summarizeEmail(
                    subject: email.subject,
                    body: email.body,
                    from: email.from.displayName
                )
                isLoadingSummary = false
            }
            // Fetch smart reply suggestions
            smartReplies = await GeminiService.shared.generateSmartReplies(
                to: (from: email.from.displayName, subject: email.subject, body: email.body)
            )
        }
    }

    // MARK: - Audio Player (Listen to Email)

    private var audioPlayerSection: some View {
        VStack(spacing: 0) {
            if let url = audioURL {
                // Full audio player card
                VStack(spacing: 10) {
                    HStack(spacing: 12) {
                        // Play/Pause button
                        Button {
                            tts.togglePlayPause(url: url)
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.accentGreen.opacity(0.15))
                                    .frame(width: 44, height: 44)
                                Image(systemName: tts.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.accentGreen)
                            }
                        }

                        // Progress bar + time
                        VStack(alignment: .leading, spacing: 4) {
                            // Progress bar
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.bgCardHover)
                                        .frame(height: 4)
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.accentGreen)
                                        .frame(width: geo.size.width * tts.playbackProgress, height: 4)
                                }
                            }
                            .frame(height: 4)

                            // Duration
                            HStack {
                                Text(DeepgramService.formatDuration(tts.audioDuration * tts.playbackProgress))
                                    .font(Typo.monoSmall)
                                    .foregroundColor(.textSecondary)
                                Spacer()
                                Text(DeepgramService.formatDuration(tts.audioDuration))
                                    .font(Typo.monoSmall)
                                    .foregroundColor(.textTertiary)
                            }
                        }

                        // Stop button
                        Button {
                            tts.stop()
                            audioURL = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.textTertiary)
                        }
                    }
                }
                .padding(14)
                .background(Color.bgCard)
                .cornerRadius(10)
            } else {
                // Generate button
                Button {
                    Task { await generateAudio() }
                } label: {
                    HStack(spacing: 6) {
                        if tts.isGenerating {
                            ProgressView()
                                .tint(.accentGreen)
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 15))
                        }
                        Text(tts.isGenerating ? "GENERATING AUDIO..." : "LISTEN TO EMAIL")
                            .font(Typo.mono)
                            .tracking(0.5)
                    }
                    .foregroundColor(.accentGreen)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.accentGreen.opacity(0.1))
                    .cornerRadius(8)
                }
                .disabled(tts.isGenerating)
            }

            // Error
            if let ttsError = tts.error {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                    Text(ttsError)
                        .font(Typo.monoSmall)
                }
                .foregroundColor(.accentYellow)
                .padding(.top, 6)
            }
        }
    }

    // MARK: - Generate Audio

    private func generateAudio() async {
        // Check if we already have cached audio
        if let cached = tts.cachedURL(for: email.id) {
            audioURL = cached
            tts.play(url: cached)
            return
        }

        let textForAudio = email.body.isEmpty ? email.snippet : email.body
        guard !textForAudio.isEmpty else { return }

        // Prepare readable text: subject + from + body
        let fullText = "Email from \(email.from.displayName). Subject: \(email.subject). \(textForAudio)"

        if let url = await tts.generateAudio(emailId: email.id, text: fullText) {
            audioURL = url
            tts.play(url: url)
        }
    }

    // MARK: - Sender Header

    private var senderHeader: some View {
        HStack(spacing: 14) {
            InitialsAvatar(email.from.displayName, size: 48)

            VStack(alignment: .leading, spacing: 3) {
                Text(email.from.displayName)
                    .font(Typo.headline)
                    .foregroundColor(.textPrimary)
                Text(email.from.email)
                    .font(Typo.mono)
                    .foregroundColor(.textTertiary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(email.date.relativeFormatted)
                    .monoTimestamp()
                if !email.to.isEmpty {
                    Text("TO ME")
                        .font(Typo.mono)
                        .foregroundColor(.textTertiary)
                        .tracking(1)
                }
            }
        }
    }

    // MARK: - Attachments — Tappable for Download & Preview

    private var attachmentsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionDivider(label: "Attachments · \(email.attachments.count)")
                .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(email.attachments) { attachment in
                        Button {
                            Task { await downloadAndPreview(attachment) }
                        } label: {
                            HStack(spacing: 8) {
                                if downloadingAttachmentId == attachment.id {
                                    ProgressView()
                                        .tint(.accentSkyBlue)
                                        .frame(width: 20, height: 20)
                                } else {
                                    Image(systemName: attachment.icon)
                                        .font(.system(size: 16))
                                        .foregroundColor(.accentSkyBlue)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(attachment.name)
                                        .font(Typo.subhead)
                                        .foregroundColor(.textPrimary)
                                        .lineLimit(1)
                                    HStack(spacing: 4) {
                                        Text(attachment.formattedSize)
                                            .font(Typo.mono)
                                            .foregroundColor(.textTertiary)
                                        if attachment.isDownloadable {
                                            Image(systemName: "arrow.down.circle")
                                                .font(.system(size: 13))
                                                .foregroundColor(.accentSkyBlue)
                                        }
                                    }
                                }
                            }
                            .padding(12)
                            .background(Color.bgCard)
                            .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Download & Preview Attachment

    private func downloadAndPreview(_ attachment: Attachment) async {
        guard let messageId = attachment.messageId,
              let attachmentId = attachment.attachmentId else {
            return
        }

        downloadingAttachmentId = attachment.id

        if let data = await GmailService.shared.downloadAttachment(
            messageId: messageId,
            attachmentId: attachmentId
        ) {
            // Save to temp directory
            let tempDir = FileManager.default.temporaryDirectory
            let fileURL = tempDir.appendingPathComponent(attachment.name)

            do {
                try data.write(to: fileURL)
                previewURL = fileURL
            } catch {
                print("[EmailDetailView] Failed to save attachment: \(error)")
            }
        }

        downloadingAttachmentId = nil
    }

    // MARK: - Translate

    private func translateTo(_ language: String) async {
        isTranslating = true
        translateError = nil

        // Use body if available, otherwise fall back to snippet
        let textToTranslate = email.body.isEmpty ? email.snippet : email.body

        guard !textToTranslate.isEmpty else {
            translateError = "No email content to translate"
            isTranslating = false
            return
        }

        let result = await GeminiService.shared.translateEmail(body: textToTranslate, to: language)

        if let translated = result, !translated.isEmpty {
            translatedBody = translated
        } else {
            translateError = "Translation failed — try again"
        }

        isTranslating = false
    }

}
