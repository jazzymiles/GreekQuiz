import SwiftUI
import AVFoundation
import WebKit
import MediaPlayer

// CardView остается без изменений

struct ContentView: View {
    
    @Environment(\.locale) private var locale
    @StateObject private var dictionaryService = DictionaryService()

    @State private var currentWordIndex = 0
    @State private var userInput = ""
    @State private var showAnswer = false
    @State private var isCorrect = false
    @State private var isShowingFeedback = false
    @State private var selectedAnswer: String? = nil
    @State private var cardOptions: [String] = []
    @State private var showCardTranslation: Bool = false

    @State private var showingDictionarySelection = false
    @State private var showingRules = false
    @State private var showingSettings = false
    
    @State private var showingHelp = false

    @State private var talkShowTimer: Timer?
    @State private var isTalkShowPlaying: Bool = false

    @AppStorage("score") private var score = 0
    @AppStorage("currentQuizMode") private var quizMode: QuizMode = .keyboard
    @AppStorage("showTranscription") private var showTranscription: Bool = true
    @AppStorage("autoPlaySound") private var autoPlaySound: Bool = true
    @AppStorage("playAnswerSound") private var playAnswerSound: Bool = true
    @AppStorage("useAllWordsInQuiz") private var useAllWordsInQuiz: Bool = false
    @AppStorage("colorSchemePreference") private var colorSchemePreference: String = "system"
    @AppStorage("dictionarySourcePreference") private var dictionarySource: DictionarySource = .standard
    @AppStorage("customDictionaryURL") private var customDictionaryURL: String = ""
    @AppStorage("studiedLanguage") private var studiedLanguage: String = "el"
    @AppStorage("answerLanguage") private var answerLanguage: String = "ru"
    @AppStorage("interfaceLanguage") private var interfaceLanguage: String = "en"

    @FocusState private var isTextFieldFocused: Bool

    private let synthesizer = AVSpeechSynthesizer()
    @Environment(\.colorScheme) var currentSystemColorScheme: ColorScheme

    private var rulesHtmlFileName: String {
        if answerLanguage == "en" || answerLanguage == "el" {
            return "rules-en"
        } else {
            return "rules-el"
        }
    }
    
    private var helpHtmlFileName: String {
        return "help-\(interfaceLanguage)"
    }

    private func getWord(for word: Word, langCode: String) -> String {
        switch langCode {
        case "ru":
            return word.ru
        case "el":
            return word.el
        case "en":
            return word.en ?? "N/A"
        default:
            return ""
        }
    }

    private func currentQuestionWord() -> String {
        guard !dictionaryService.activeWords.isEmpty, currentWordIndex < dictionaryService.activeWords.count else { return "" }
        let word = dictionaryService.activeWords[currentWordIndex]
        return getWord(for: word, langCode: studiedLanguage)
    }

    private func currentAnswerWord() -> String {
        guard !dictionaryService.activeWords.isEmpty, currentWordIndex < dictionaryService.activeWords.count else { return "" }
        let word = dictionaryService.activeWords[currentWordIndex]
        return getWord(for: word, langCode: answerLanguage)
    }

    var body: some View {
        
        ZStack {
            backgroundColor()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                headerButtons
                    .padding(.horizontal)
                    .padding(.top, 10)

                Picker("title_quiz_mode", selection: $quizMode) {
                    ForEach(QuizMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 10)
                .onChange(of: quizMode, perform: handleModeChange)
                
                quizContainer
                
                Spacer()
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)

            statusOverlay
        }
        .preferredColorScheme(getPreferredColorScheme())
        .onAppear {
            let hasLaunchedBefore = UserDefaults.standard.bool(forKey: "hasLaunchedBefore")

            if !hasLaunchedBefore {
                print("First launch: Triggering automatic dictionary download.")
                Task {
                    await dictionaryService.downloadAndSaveDictionaries(
                        source: .standard,
                        customURL: "",
                        interfaceLanguage: interfaceLanguage
                    )
                    UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
                }
            } else {
                if dictionaryService.activeWords.isEmpty {
                     dictionaryService.loadSelectedWords(interfaceLanguage: interfaceLanguage)
                }
            }

            let currentMode = quizMode
            DispatchQueue.main.async {
                quizMode = currentMode
            }

            if quizMode == .quiz {
                generateCardOptions()
            }
        }
        .onDisappear {
            stopTalkShow()
        }
        .onReceive(NotificationCenter.default.publisher(for: .talkShowTogglePlayPause)) { _ in
            if self.quizMode == .talkShow {
                self.togglePlayPause()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .talkShowSkipToNext)) { _ in
            if self.quizMode == .talkShow {
                self.skipToNextTalkShowWord()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .talkShowSkipToPrevious)) { _ in
            if self.quizMode == .talkShow {
                self.skipToPreviousTalkShowWord()
            }
        }
        .onChange(of: dictionaryService.activeWords) { _ in
            resetAfterDictionaryChange()
        }
        .onChange(of: interfaceLanguage) { newLanguage in
            dictionaryService.loadSelectedWords(interfaceLanguage: newLanguage)
        }
    }

    // MARK: - Subviews
    private var headerButtons: some View {
        HStack(spacing: 8) {
            
            HeaderButton(imageName: "questionmark.circle", action: { showingHelp = true })
                // ✨ ИЗМЕНЕНИЕ: Вызываем новое View для помощи
                .sheet(isPresented: $showingHelp) { HelpSheetView(htmlFileName: helpHtmlFileName) }
            
            Spacer()
            
            HeaderButton(imageName: "character.book.closed", action: { showingRules = true })
                .sheet(isPresented: $showingRules) { RulesSheetView(htmlFileName: rulesHtmlFileName) }

            HeaderButton(imageName: "books.vertical", action: { showingDictionarySelection = true })
                .sheet(isPresented: $showingDictionarySelection) {
                    DictionarySelectionView(
                        dictionaryService: dictionaryService,
                        speakWord: speakWord,
                        interfaceLanguage: interfaceLanguage
                    )
                }

            HeaderButton(imageName: "gearshape", action: { showingSettings = true })
                .sheet(isPresented: $showingSettings) {
                    SettingsView(
                        showTranscription: $showTranscription,
                        autoPlaySound: $autoPlaySound,
                        playAnswerSound: $playAnswerSound,
                        useAllWordsInQuiz: $useAllWordsInQuiz,
                        colorSchemePreference: $colorSchemePreference,
                        dictionarySource: $dictionarySource,
                        customDictionaryURL: $customDictionaryURL,
                        studiedLanguage: $studiedLanguage,
                        answerLanguage: $answerLanguage,
                        interfaceLanguage: $interfaceLanguage,
                        onDownloadDictionaries: {
                            showingSettings = false

                            Task {
                                await dictionaryService.downloadAndSaveDictionaries(
                                    source: dictionarySource,
                                    customURL: customDictionaryURL,
                                    interfaceLanguage: interfaceLanguage
                                )
                            }
                        }
                    )
                }
        }
    }

    @ViewBuilder
    private var quizContainer: some View {
        if !dictionaryService.activeWords.isEmpty && currentWordIndex < dictionaryService.activeWords.count {
            let currentWord = dictionaryService.activeWords[currentWordIndex]

            switch quizMode {
            case .keyboard:
                KeyboardQuizView(
                    word: currentWord,
                    answerWord: currentAnswerWord(),
                    studiedLanguage: studiedLanguage,
                    showTranscription: showTranscription,
                    speakWord: speakWord,
                    userInput: $userInput,
                    showAnswer: $showAnswer,
                    isTextFieldFocused: $isTextFieldFocused,
                    onCheckAnswer: checkAnswer,
                    onNextWord: nextWord
                )
            case .quiz:
                MultipleChoiceQuizView(
                    word: currentWord,
                    options: cardOptions,
                    studiedLanguage: studiedLanguage,
                    answerLanguage: answerLanguage,
                    showTranscription: showTranscription,
                    speakWord: speakWord,
                    selectedAnswer: $selectedAnswer,
                    showAnswer: $showAnswer,
                    onSelectAnswer: { selectedOption in
                        self.selectedAnswer = selectedOption
                        if self.playAnswerSound {
                            self.speakWord(selectedOption, self.answerLanguage)
                        }
                    },
                    onCheckAnswer: checkCardAnswer,
                    onNextWord: nextWord
                )
            case .cards:
                CardModeView(
                    word: currentWord,
                    studiedLanguage: studiedLanguage,
                    answerLanguage: answerLanguage,
                    showTranscription: showTranscription,
                    speakWord: speakWord,
                    showCardTranslation: $showCardTranslation,
                    onNextWord: nextWord,
                    onPreviousWord: previousWord
                )
            case .talkShow:
                TalkShowView(
                    questionWord: currentQuestionWord(),
                    answerWord: currentAnswerWord(),
                    isPlaying: $isTalkShowPlaying,
                    onTogglePlayPause: togglePlayPause,
                    onSkipToPrevious: skipToPreviousTalkShowWord,
                    onSkipToNext: skipToNextTalkShowWord
                )
            }
        } else {
            VStack {
                Spacer()
                
                if dictionaryService.isDownloading {
                    VStack(spacing: 20) {
                        ProgressView()
                        Text("loading_dictionaries_message")
                            .foregroundColor(.gray)
                    }
                } else {
                    VStack(spacing: 20) {
                        Text("select_at_least_one_dictionary")
                            .font(.body)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        Image(systemName: "books.vertical")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 40, height: 40)
                            .foregroundColor(.gray)
                            .fontWeight(.light)
                    }
                }
                
                Spacer()
            }
            .frame(maxWidth: 300, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private var statusOverlay: some View {
        if dictionaryService.isDownloading {
            Color.black.opacity(0.4).ignoresSafeArea()

            VStack(spacing: 12) {
                HStack(spacing: 4) {
                    Text(dictionaryService.downloadStatusText)
                    Text(dictionaryService.downloadCounterText)
                }
                .font(.headline)

                Text(dictionaryService.currentDictionaryName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                ProgressView(value: dictionaryService.downloadProgressValue)
                    .progressViewStyle(LinearProgressViewStyle())
            }
            .padding(20)
            .background(Material.regular)
            .foregroundColor(Color.primary)
            .cornerRadius(20)
            .shadow(radius: 10)
            .transition(.opacity.combined(with: .scale))
            .padding(.horizontal, 40)

        } else if !dictionaryService.statusMessage.isEmpty {
            VStack {
                Spacer()
                Text(dictionaryService.statusMessage)
                    .padding()
                    .background(Material.regular)
                    .cornerRadius(10)
                    .shadow(radius: 5)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            withAnimation {
                                dictionaryService.statusMessage = ""
                            }
                        }
                    }
            }
            .padding(.bottom, 30)
        }
    }


    // MARK: - Quiz Logic
    private func checkAnswer() {
        let correctAnswers = parseAcceptedAnswers(from: currentAnswerWord())
        if correctAnswers.contains(userInput.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()) {
            handleCorrectAnswer()
        } else {
            handleIncorrectAnswer()
        }
    }

    private func checkCardAnswer() {
        guard let selected = selectedAnswer else {
            handleIncorrectAnswer()
            return
        }
        let correctAnswers = parseAcceptedAnswers(from: currentAnswerWord())
        if correctAnswers.contains(selected.lowercased()) {
            handleCorrectAnswer()
        } else {
            handleIncorrectAnswer()
        }
    }

    private func handleCorrectAnswer() {
        isCorrect = true
        showAnswer = true
        score += 1
        isShowingFeedback = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            isShowingFeedback = false
        }
    }

    private func handleIncorrectAnswer() {
        isCorrect = false
        showAnswer = true
    }

    private func nextWord() {
        if !dictionaryService.activeWords.isEmpty {
            currentWordIndex = (currentWordIndex + 1) % dictionaryService.activeWords.count
            resetForNewWord()
        }
    }

    private func previousWord() {
        if !dictionaryService.activeWords.isEmpty {
            currentWordIndex = (currentWordIndex - 1 + dictionaryService.activeWords.count) % dictionaryService.activeWords.count
            resetForNewWord()
        }
    }

    private func resetForNewWord() {
        userInput = ""
        showAnswer = false
        isCorrect = false
        selectedAnswer = nil
        showCardTranslation = false
        isTextFieldFocused = true

        if quizMode == .quiz {
            generateCardOptions()
        }

        if autoPlaySound && !dictionaryService.activeWords.isEmpty && quizMode != .talkShow {
            speakWord(currentQuestionWord(), studiedLanguage)
        }
    }

    private func resetAfterDictionaryChange() {
        currentWordIndex = 0
        resetForNewWord()
    }

    private func generateCardOptions() {
        guard !dictionaryService.activeWords.isEmpty, currentWordIndex < dictionaryService.activeWords.count else {
            cardOptions = []
            return
        }

        let correctAnswer = parseAcceptedAnswers(from: currentAnswerWord()).first ?? currentAnswerWord()

        var options = Set([correctAnswer])

        let answerPool = useAllWordsInQuiz ? dictionaryService.allWords : dictionaryService.activeWords
        let allPossibleAnswers = answerPool.map { getWord(for: $0, langCode: answerLanguage) }

        while options.count < 4 && options.count < allPossibleAnswers.count {
            if let randomAnswer = allPossibleAnswers.randomElement(), let parsed = parseAcceptedAnswers(from: randomAnswer).first, !parsed.isEmpty {
                options.insert(parsed)
            }
        }

        cardOptions = Array(options).shuffled()
    }

    private func handleModeChange(_ newMode: QuizMode) {
        if newMode == .talkShow {
            if !isTalkShowPlaying {
                startTalkShow()
            }
        } else {
            stopTalkShow()
        }
        
        resetForNewWord()
        if newMode == .keyboard {
            isTextFieldFocused = true
        }
    }

    private func startTalkShow() {
        guard !dictionaryService.activeWords.isEmpty else { return }
        isTalkShowPlaying = true
        playNextTalkShowWord(isInitialPlay: true)
        
        if talkShowTimer == nil {
            talkShowTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { _ in
                if self.isTalkShowPlaying {
                    self.playNextTalkShowWord(isInitialPlay: false)
                } else {
                    self.stopTalkShow()
                }
            }
        }
    }

    private func stopTalkShow() {
        isTalkShowPlaying = false
        talkShowTimer?.invalidate()
        talkShowTimer = nil
        synthesizer.stopSpeaking(at: .immediate)
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
    
    private func togglePlayPause() {
        if isTalkShowPlaying {
            isTalkShowPlaying = false
            talkShowTimer?.invalidate()
            talkShowTimer = nil
            synthesizer.stopSpeaking(at: .immediate)
        } else {
            startTalkShow()
        }
    }

    private func playNextTalkShowWord(isInitialPlay: Bool) {
        guard !dictionaryService.activeWords.isEmpty else {
            stopTalkShow()
            return
        }
        
        if !isInitialPlay {
            currentWordIndex = (currentWordIndex + 1) % dictionaryService.activeWords.count
        }

        let question = currentQuestionWord()
        let answer = currentAnswerWord()

        RemoteCommandManager.shared.updateNowPlayingInfo(question: question, answer: answer)
        
        speakWord(question, studiedLanguage)

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if self.isTalkShowPlaying {
                self.speakWord(answer, self.answerLanguage)
            }
        }
    }
    
    private func skipToNextTalkShowWord() {
        guard !dictionaryService.activeWords.isEmpty else { return }
        
        let wasPlaying = isTalkShowPlaying
        if wasPlaying {
            stopTalkShow()
        }

        currentWordIndex = (currentWordIndex + 1) % dictionaryService.activeWords.count
        
        if wasPlaying {
            startTalkShow()
        }
    }

    private func skipToPreviousTalkShowWord() {
        guard !dictionaryService.activeWords.isEmpty else { return }
        
        let wasPlaying = isTalkShowPlaying
        if wasPlaying {
            stopTalkShow()
        }
        
        currentWordIndex = (currentWordIndex - 1 + dictionaryService.activeWords.count) % dictionaryService.activeWords.count
        
        if wasPlaying {
            startTalkShow()
        }
    }

    // MARK: - UI Helpers
    private func backgroundColor() -> Color {
        if isShowingFeedback { return .green.opacity(0.6) }
        if showAnswer { return isCorrect ? .green.opacity(0.6) : .red.opacity(0.6) }
        if colorSchemePreference == "dark" { return Color(red: 0.15, green: 0.15, blue: 0.15) }
        return .clear
    }

    private func getPreferredColorScheme() -> ColorScheme? {
        switch colorSchemePreference {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    private func parseAcceptedAnswers(from raw: String) -> [String] {
        raw.replacingOccurrences(of: "\\(.*?\\)", with: "", options: .regularExpression)
           .split(separator: ",")
           .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
    }

    func speakWord(_ text: String, _ langCode: String) {
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }

        let utterance = AVSpeechUtterance(string: text)
        let voiceLanguageCode = langCode == "el" ? "el-GR" : (langCode == "ru" ? "ru-RU" : "en-US")
        utterance.voice = AVSpeechSynthesisVoice(language: voiceLanguageCode)
        utterance.rate = 0.5
        synthesizer.speak(utterance)
    }
}


#Preview {
    ContentView()
}
