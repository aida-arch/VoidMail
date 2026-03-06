import SwiftUI
import UniformTypeIdentifiers
import PhotosUI
import Speech
import AVFoundation

struct ComposeView: View {
    var replyTo: Email? = nil
    var replyType: EmailDetailView.ReplyType = .reply

    @Environment(\.dismiss) private var dismiss
    @State private var toField = ""
    @State private var ccField = ""
    @State private var bccField = ""
    @State private var subjectField = ""
    @State private var bodyField = ""
    @State private var showCC = false
    @State private var showBCC = false
    @State private var showSchedule = false
    @State private var isAIDrafting = false
    @State private var isSending = false
    @State private var sendSuccess = false
    @State private var scheduledDate: Date = Date().addingTimeInterval(3600)
    @State private var useSchedule = false
    @State private var showFilePicker = false
    @State private var attachedFiles: [(data: Data, filename: String, mimeType: String)] = []
    @State private var appeared = false
    @State private var selectedSenderEmail: String = GoogleAuthService.shared.accounts.first?.email ?? ""
    @State private var isRecording = false
    @State private var isGeneratingSubject = false
    @FocusState private var focusedField: Field?

    enum Field: Hashable { case to, cc, bcc, subject, body }

    private var composeTitle: String {
        if replyTo != nil {
            switch replyType {
            case .reply: return "Reply"
            case .replyAll: return "Reply All"
            case .forward: return "Forward"
            }
        }
        return "Compose"
    }

    private var composeIcon: String {
        if replyTo != nil {
            switch replyType {
            case .reply: return "arrowshape.turn.up.left"
            case .replyAll: return "arrowshape.turn.up.left.2"
            case .forward: return "arrowshape.turn.up.right"
            }
        }
        return "square.and.pencil"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.bgDeep.ignoresSafeArea()

                VStack(spacing: 0) {
                    // MARK: Header with reply context
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 10) {
                            Image(systemName: composeIcon)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.accentSkyBlue)
                            Text(composeTitle.uppercased())
                                .font(Typo.title3)
                                .foregroundColor(.textPrimary)
                                .tracking(-0.3)
                            Spacer()
                        }

                        if let email = replyTo {
                            HStack(spacing: 6) {
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(Color.accentSkyBlue.opacity(0.5))
                                    .frame(width: 2, height: 16)
                                Text("Re: \(email.from.displayName)")
                                    .font(Typo.subhead)
                                    .foregroundColor(.textTertiary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 14)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : -10)

                    // MARK: Fields Card
                    VStack(spacing: 0) {
                        // FROM account selector
                        HStack(spacing: 10) {
                            Text("FROM")
                                .font(Typo.mono)
                                .foregroundColor(.textTertiary)
                                .tracking(1)
                                .frame(width: 46, alignment: .leading)

                            Menu {
                                ForEach(GoogleAuthService.shared.accounts) { account in
                                    Button {
                                        selectedSenderEmail = account.email
                                    } label: {
                                        HStack {
                                            Circle()
                                                .fill(account.colorTag.color)
                                                .frame(width: 8, height: 8)
                                            VStack(alignment: .leading) {
                                                Text(account.label)
                                                Text(account.email)
                                            }
                                            if selectedSenderEmail == account.email {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(GoogleAuthService.shared.accounts.first(where: { $0.email == selectedSenderEmail })?.colorTag.color ?? .accentSkyBlue)
                                        .frame(width: 8, height: 8)
                                    Text(GoogleAuthService.shared.accounts.first(where: { $0.email == selectedSenderEmail })?.label ?? selectedSenderEmail)
                                        .font(Typo.body)
                                        .foregroundColor(.textPrimary)
                                        .lineLimit(1)
                                    if GoogleAuthService.shared.accounts.count > 1 {
                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 11))
                                            .foregroundColor(.textTertiary)
                                    }
                                }
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)

                        VoidDivider().padding(.horizontal, 16)
                        fieldRow(label: "TO", text: $toField, field: .to)

                        if showCC {
                            VoidDivider().padding(.horizontal, 16)
                            fieldRow(label: "CC", text: $ccField, field: .cc)
                        }

                        if showBCC {
                            VoidDivider().padding(.horizontal, 16)
                            fieldRow(label: "BCC", text: $bccField, field: .bcc)
                        }

                        VoidDivider().padding(.horizontal, 16)
                        fieldRow(label: "SUBJ", text: $subjectField, field: .subject)
                    }
                    .background(Color.bgCard)
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)

                    // MARK: Attached Files
                    if !attachedFiles.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(attachedFiles.indices, id: \.self) { index in
                                    attachmentChip(index: index)
                                }

                                // Add more button
                                Button { showFilePicker = true } label: {
                                    Image(systemName: "plus.circle")
                                        .font(.system(size: 20))
                                        .foregroundColor(.accentSkyBlue)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                        }
                    }

                    // MARK: Body Editor
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $bodyField)
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.textPrimary)
                            .scrollContentBackground(.hidden)
                            .focused($focusedField, equals: .body)
                            .padding(.horizontal, 16)
                            .padding(.top, 8)

                        if bodyField.isEmpty {
                            Text("Write your message...")
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(.textTertiary)
                                .padding(.horizontal, 21)
                                .padding(.top, 16)
                                .allowsHitTesting(false)
                        }
                    }

                    Spacer(minLength: 0)

                    // MARK: AI Draft Banner
                    if isAIDrafting {
                        HStack(spacing: 10) {
                            ProgressView().tint(.accentSkyBlue)
                            Text("AI IS DRAFTING...")
                                .font(Typo.mono)
                                .foregroundColor(.accentSkyBlue)
                                .tracking(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.accentSkyBlue.opacity(0.08))
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    // MARK: Schedule Picker
                    if showSchedule {
                        VStack(spacing: 10) {
                            HStack {
                                Image(systemName: "clock.fill")
                                    .foregroundColor(.accentYellow)
                                Text("SCHEDULE SEND")
                                    .font(Typo.mono)
                                    .foregroundColor(.accentYellow)
                                    .tracking(1)
                                Spacer()
                                Toggle("", isOn: $useSchedule)
                                    .tint(.accentGreen)
                                    .labelsHidden()
                            }

                            if useSchedule {
                                DatePicker(
                                    "",
                                    selection: $scheduledDate,
                                    in: Date()...,
                                    displayedComponents: [.date, .hourAndMinute]
                                )
                                .datePickerStyle(.compact)
                                .tint(.accentSkyBlue)
                                .labelsHidden()
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                            }
                        }
                        .padding(16)
                        .background(Color.bgCard)
                        .cornerRadius(12)
                        .padding(.horizontal, 16)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    // MARK: Bottom Toolbar (floating pill)
                    composeToolbar
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(Color.bgCard)
                        )
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.textTertiary)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    sendButton
                }
            }
            .toolbarBackground(Color.bgDeep, for: .navigationBar)
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.item],
                allowsMultipleSelection: true
            ) { result in
                handleFilePicker(result)
            }
        }
        .onAppear {
            prefillReply()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1)) {
                appeared = true
            }
        }
    }

    // MARK: - Send Button

    private var sendButton: some View {
        Button {
            Task { await send() }
        } label: {
            HStack(spacing: 6) {
                if isSending {
                    ProgressView()
                        .tint(canSend ? .bgDeep : .textTertiary)
                        .scaleEffect(0.7)
                } else {
                    Image(systemName: useSchedule ? "clock.arrow.circlepath" : "paperplane.fill")
                        .font(.system(size: 13, weight: .bold))
                }
                Text(useSchedule ? "SCHEDULE" : "SEND")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .tracking(1.5)
            }
            .foregroundColor(canSend ? .bgDeep : .textTertiary)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(canSend ? Color.accentPink : Color.bgCard)
            )
        }
        .buttonStyle(.plain)
        .disabled(!canSend || isSending)
    }

    // MARK: - Field Row

    private func fieldRow(label: String, text: Binding<String>, field: Field) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(Typo.mono)
                .foregroundColor(.textTertiary)
                .tracking(1)
                .frame(width: 46, alignment: .leading)

            TextField("", text: text)
                .font(Typo.body)
                .foregroundColor(.textPrimary)
                .tint(.accentSkyBlue)
                .focused($focusedField, equals: field)
                .textInputAutocapitalization(.never)
                .keyboardType(field == .to || field == .cc || field == .bcc ? .emailAddress : .default)

            if field == .to {
                HStack(spacing: 6) {
                    if !showCC {
                        Button {
                            withAnimation(.spring(response: 0.3)) { showCC = true }
                        } label: {
                            Text("CC")
                                .font(Typo.mono)
                                .foregroundColor(.textTertiary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.bgCard)
                                .clipShape(Capsule())
                        }
                    }
                    if !showBCC {
                        Button {
                            withAnimation(.spring(response: 0.3)) { showBCC = true }
                        } label: {
                            Text("BCC")
                                .font(Typo.mono)
                                .foregroundColor(.textTertiary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.bgCard)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Attachment Chip

    private func attachmentChip(index: Int) -> some View {
        HStack(spacing: 6) {
            Image(systemName: iconForMime(attachedFiles[index].mimeType))
                .font(.system(size: 15))
                .foregroundColor(.accentSkyBlue)

            VStack(alignment: .leading, spacing: 1) {
                Text(attachedFiles[index].filename)
                    .font(Typo.subhead)
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)
                Text(ByteCountFormatter.string(fromByteCount: Int64(attachedFiles[index].data.count), countStyle: .file))
                    .font(Typo.mono)
                    .foregroundColor(.textTertiary)
            }

            Button {
                withAnimation { let _ = attachedFiles.remove(at: index) }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.textTertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.bgCard)
        .cornerRadius(10)
    }

    // MARK: - Compose Toolbar

    // MARK: - Toolbar Icon Button (consistent style)

    private func toolbarIcon(_ icon: String, color: Color = .textTertiary, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(color == .textTertiary ? 0 : 0.12))
                .clipShape(Circle())
        }
    }

    private var composeToolbar: some View {
        HStack(spacing: 10) {
            // AI Draft button
            Button {
                Task { await generateAIDraft() }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14))
                    Text("AI")
                        .font(Typo.mono)
                        .tracking(0.5)
                }
                .foregroundColor(.accentSkyBlue)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.accentSkyBlue.opacity(0.12))
                .clipShape(Capsule())
            }
            .disabled(isAIDrafting)

            Spacer()

            // Attach
            toolbarIcon("paperclip", color: attachedFiles.isEmpty ? .textTertiary : .accentSkyBlue) {
                showFilePicker = true
            }

            // Photos
            toolbarIcon("photo") { showFilePicker = true }

            // Microphone (Speech to Text)
            toolbarIcon(isRecording ? "mic.fill" : "mic", color: isRecording ? .accentPink : .textTertiary) {
                if isRecording { stopRecording() } else { startRecording() }
            }

            // Magic wand (AI Subject)
            toolbarIcon("wand.and.stars", color: isGeneratingSubject ? .accentYellow : .textTertiary) {
                Task { await generateSubject() }
            }
            .disabled(bodyField.isEmpty || isGeneratingSubject)

            // Schedule
            toolbarIcon(showSchedule ? "clock.fill" : "clock", color: showSchedule ? .accentYellow : .textTertiary) {
                withAnimation(.spring(response: 0.3)) { showSchedule.toggle() }
            }
        }
    }

    // MARK: - File Picker Handler

    private func handleFilePicker(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            for url in urls {
                guard url.startAccessingSecurityScopedResource() else { continue }
                defer { url.stopAccessingSecurityScopedResource() }

                if let data = try? Data(contentsOf: url) {
                    let filename = url.lastPathComponent
                    let mimeType = mimeTypeForExtension(url.pathExtension)
                    attachedFiles.append((data: data, filename: filename, mimeType: mimeType))
                }
            }
        case .failure(let error):
            print("[ComposeView] File picker error: \(error.localizedDescription)")
        }
    }

    private func mimeTypeForExtension(_ ext: String) -> String {
        let map: [String: String] = [
            "pdf": "application/pdf",
            "jpg": "image/jpeg", "jpeg": "image/jpeg",
            "png": "image/png", "gif": "image/gif",
            "doc": "application/msword",
            "docx": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
            "xls": "application/vnd.ms-excel",
            "xlsx": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            "pptx": "application/vnd.openxmlformats-officedocument.presentationml.presentation",
            "txt": "text/plain",
            "csv": "text/csv",
            "zip": "application/zip",
            "mp4": "video/mp4",
            "mp3": "audio/mpeg",
            "html": "text/html"
        ]
        return map[ext.lowercased()] ?? "application/octet-stream"
    }

    private func iconForMime(_ mime: String) -> String {
        if mime.contains("pdf") { return "doc.fill" }
        if mime.contains("image") { return "photo.fill" }
        if mime.contains("video") || mime.contains("mp4") { return "video.fill" }
        if mime.contains("audio") || mime.contains("mpeg") { return "waveform" }
        if mime.contains("spreadsheet") || mime.contains("csv") || mime.contains("excel") { return "tablecells.fill" }
        if mime.contains("word") || mime.contains("msword") { return "doc.richtext.fill" }
        if mime.contains("presentation") || mime.contains("powerpoint") || mime.contains("pptx") { return "doc.text.image.fill" }
        if mime.contains("zip") || mime.contains("compressed") { return "doc.zipper" }
        if mime.contains("html") { return "globe" }
        if mime.contains("text/plain") { return "doc.text.fill" }
        return "paperclip"
    }

    // MARK: - Actions

    private var canSend: Bool {
        !toField.isEmpty && (!subjectField.isEmpty || !bodyField.isEmpty)
    }

    private func prefillReply() {
        guard let email = replyTo else {
            focusedField = .to
            return
        }

        switch replyType {
        case .reply:
            toField = email.from.email
            subjectField = "Re: \(email.subject)"
        case .replyAll:
            toField = email.from.email
            ccField = email.cc.map(\.email).joined(separator: ", ")
            subjectField = "Re: \(email.subject)"
        case .forward:
            subjectField = "Fwd: \(email.subject)"
            bodyField = "\n\n---------- Forwarded message ----------\nFrom: \(email.from.displayName) <\(email.from.email)>\nSubject: \(email.subject)\n\n\(email.body)"
        }
        focusedField = .body
    }

    private func generateAIDraft() async {
        withAnimation { isAIDrafting = true }

        let gemini = GeminiService.shared

        if let email = replyTo {
            if let draft = await gemini.generateDraft(
                context: bodyField.isEmpty ? "" : bodyField,
                replyTo: (from: email.from.displayName, subject: email.subject, body: email.body)
            ) {
                bodyField = draft
            } else {
                bodyField = """
                Hi \(email.from.displayName.components(separatedBy: " ").first ?? ""),

                Thanks for the update. I'll review and get back to you shortly.

                Best,
                Aniket
                """
            }
        } else {
            if let draft = await gemini.generateDraft(
                context: subjectField.isEmpty ? "general email" : subjectField
            ) {
                bodyField = draft
            } else {
                bodyField = "Hi,\n\n\n\nBest,\nAniket"
            }
        }

        withAnimation { isAIDrafting = false }
    }

    // MARK: - Speech to Text

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private static var audioEngine = AVAudioEngine()
    @State private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    @State private var recognitionTask: SFSpeechRecognitionTask?

    private func startRecording() {
        SFSpeechRecognizer.requestAuthorization { status in
            guard status == .authorized else { return }
            DispatchQueue.main.async {
                self.beginAudioRecording()
            }
        }
    }

    private func beginAudioRecording() {
        let audioEngine = Self.audioEngine
        if audioEngine.isRunning {
            stopRecording()
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        do {
            try AVAudioSession.sharedInstance().setCategory(.record, mode: .measurement, options: .duckOthers)
            try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
            try audioEngine.start()
            isRecording = true
        } catch {
            print("[ComposeView] Audio engine failed: \(error)")
            return
        }

        recognitionTask = speechRecognizer?.recognitionTask(with: request) { result, error in
            if let result = result {
                DispatchQueue.main.async {
                    let transcription = result.bestTranscription.formattedString
                    // Only append new text
                    if !transcription.isEmpty {
                        self.bodyField = transcription
                    }
                }
            }
            if error != nil || (result?.isFinal ?? false) {
                DispatchQueue.main.async {
                    self.stopRecording()
                }
            }
        }
    }

    private func stopRecording() {
        let audioEngine = Self.audioEngine
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false)
    }

    // MARK: - AI Subject Generation

    private func generateSubject() async {
        isGeneratingSubject = true
        if let subject = await GeminiService.shared.generateEmailSubject(body: bodyField) {
            subjectField = subject
        }
        isGeneratingSubject = false
    }

    private func send() async {
        isSending = true
        let recipients = toField.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        let sender = selectedSenderEmail.isEmpty ? nil : selectedSenderEmail

        let success: Bool
        if attachedFiles.isEmpty {
            success = await GmailService.shared.sendEmail(
                to: recipients,
                subject: subjectField,
                body: bodyField,
                replyToMessageId: replyTo?.id,
                fromEmail: sender
            )
        } else {
            success = await GmailService.shared.sendEmailWithAttachments(
                to: recipients,
                subject: subjectField,
                body: bodyField,
                attachments: attachedFiles,
                replyToMessageId: replyTo?.id,
                fromEmail: sender
            )
        }

        isSending = false
        if success { dismiss() }
    }
}
