import SwiftUI
import AVFoundation
import WebKit

struct CardView: View {
    let questionWord: String
    let answerWord: String
    let studiedLanguage: String
    let transcription: String?
    let showTranscription: Bool
    let speakWord: (String, String) -> Void
    @Binding var showTranslation: Bool

    var body: some View {
        VStack {
            Spacer()
            
            Text(questionWord)
                .font(.system(size: 40, weight: .bold))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if let trans = transcription, studiedLanguage == "el" {
                Text(showTranscription ? trans : String(repeating: "*", count: trans.count))
                    .font(.system(size: 28))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Button(action: {
                speakWord(questionWord, studiedLanguage)
            }) {
                Image(systemName: "speaker.wave.3.fill")
                    .font(.title)
                    .foregroundColor(.blue)
            }
            .padding(.top, 10)
            
            Spacer()
            
            if showTranslation {
                Text(answerWord)
                    .font(.system(size: 32))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .transition(.opacity)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.opacity(0.1))
        .cornerRadius(20)
        .padding()
        .onTapGesture {
            withAnimation {
                showTranslation.toggle()
            }
        }
    }
}

struct ContentView: View {
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

                Spacer()

                quizContainer
                    .padding(.bottom, 30)
                
                Spacer()
            }
            
            statusOverlay
        }
        .preferredColorScheme(getPreferredColorScheme())
        .onAppear {
            // ✨ ИСПРАВЛЕНИЕ: Логика для первого и последующих запусков
            let hasLaunchedBefore = UserDefaults.standard.bool(forKey: "hasLaunchedBefore")

            if !hasLaunchedBefore {
                // ПЕРВЫЙ ЗАПУСК
                print("Первый запуск: автоматическое скачивание словарей.")
                Task {
                    // Запускаем скачивание стандартных словарей
                    await dictionaryService.downloadAndSaveDictionaries(
                        source: .standard,
                        customURL: "",
                        interfaceLanguage: interfaceLanguage
                    )
                    // Устанавливаем флаг, чтобы больше не выполнять это действие
                    UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
                }
            } else {
                // ПОСЛЕДУЮЩИЕ ЗАПУСКИ
                // Загружаем слова с диска, если они еще не загружены
                if dictionaryService.activeWords.isEmpty {
                     dictionaryService.loadSelectedWords(interfaceLanguage: interfaceLanguage)
                }
            }
            
            // Этот код выполняется при каждом запуске для исправления UI
            let currentMode = quizMode
            DispatchQueue.main.async {
                quizMode = currentMode
            }
            
            if quizMode == .quiz {
                generateCardOptions()
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
            Spacer()
            HeaderButton(imageName: "rules", action: { showingRules = true })
                .sheet(isPresented: $showingRules) { RulesSheetView(htmlFileName: rulesHtmlFileName) }
            
            HeaderButton(imageName: "dic", action: { showingDictionarySelection = true })
                .sheet(isPresented: $showingDictionarySelection) {
                    DictionarySelectionView(
                        dictionaryService: dictionaryService,
                        speakWord: speakWord,
                        interfaceLanguage: interfaceLanguage
                    )
                }

            HeaderButton(imageName: "settings", action: { showingSettings = true })
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
                keyboardQuizView(for: currentWord)
            case .quiz:
                multipleChoiceQuizView(for: currentWord)
            case .cards:
                cardModeView(for: currentWord)
            }
        } else {
            // Если идет загрузка, можно показать другой текст
            if dictionaryService.isDownloading {
                Text("loading_dictionaries_message") // Локализованная строка "Загрузка словарей..."
                    .foregroundColor(.gray)
            } else {
                Text("select_at_least_one_dictionary").foregroundColor(.gray)
            }
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
    
    // MARK: - Quiz Views and Logic (без изменений)

    private func keyboardQuizView(for word: Word) -> some View {
        let feedbackString = NSLocalizedString("correct_translation", comment: "") + " " + currentAnswerWord()
        
        return VStack {
            WordDisplay(
                questionWord: currentQuestionWord(),
                transcription: word.transcription,
                studiedLanguage: studiedLanguage,
                showTranscription: showTranscription,
                speakWord: speakWord
            )
            
            TextField("your_translation_placeholder", text: $userInput)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
                .focused($isTextFieldFocused)
                .padding(.bottom, 18)

            ActionButton(title: showAnswer ? "button_next" : "button_check") {
                if showAnswer { nextWord() } else { checkAnswer() }
            }
            
            FeedbackText(text: feedbackString, isVisible: showAnswer)
        }
    }

    private func multipleChoiceQuizView(for word: Word) -> some View {
        let feedbackString = NSLocalizedString("correct_translation", comment: "") + " " + currentAnswerWord()
        
        return VStack {
            WordDisplay(
                questionWord: currentQuestionWord(),
                transcription: word.transcription,
                studiedLanguage: studiedLanguage,
                showTranscription: showTranscription,
                speakWord: speakWord
            )
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 10) {
                ForEach(cardOptions, id: \.self) { option in
                    Button(action: {
                        selectedAnswer = option
                        if playAnswerSound {
                            speakWord(option, answerLanguage)
                        }
                    }) {
                        Text(option)
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(selectedAnswer == option ? Color.orange.opacity(0.8) : Color.gray.opacity(0.3))
                            .foregroundColor(getPreferredColorScheme() == .light ? .black : .white)
                            .cornerRadius(10)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 18)

            ActionButton(title: showAnswer ? "button_next" : "button_check") {
                if showAnswer { nextWord() } else { checkCardAnswer() }
            }
            
            FeedbackText(text: feedbackString, isVisible: showAnswer)
        }
    }

    private func cardModeView(for word: Word) -> some View {
        VStack {
            CardView(
                questionWord: currentQuestionWord(),
                answerWord: currentAnswerWord(),
                studiedLanguage: studiedLanguage,
                transcription: word.transcription,
                showTranscription: showTranscription,
                speakWord: speakWord,
                showTranslation: $showCardTranslation
            )
            .gesture(
                DragGesture().onEnded { gesture in
                    if gesture.translation.width < -50 { nextWord() }
                    else if gesture.translation.width > 50 { previousWord() }
                }
            )
            Spacer()
            
            HStack {
                NavButton(systemName: "arrow.left.circle.fill", action: previousWord)
                Spacer()
                NavButton(systemName: "arrow.right.circle.fill", action: nextWord)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 20)
        }
    }
    
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
        
        if autoPlaySound && !dictionaryService.activeWords.isEmpty {
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
        resetForNewWord()
        if newMode == .keyboard {
            isTextFieldFocused = true
        }
    }
    
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

// MARK: - Reusable Components
struct HeaderButton: View {
    let imageName: String
    let action: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var iconTintColor: Color {
        colorScheme == .dark ? .white : .black
    }

    var body: some View {
        Button(action: action) {
            Image(imageName)
                .resizable().scaledToFit().frame(width: 24, height: 24)
                .padding(6).foregroundColor(iconTintColor)
                .background(Color.gray.opacity(0.2)).cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ActionButton: View {
    let title: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .padding().frame(maxWidth: .infinity)
                .background(Color.blue).foregroundColor(.white)
                .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal)
        .padding(.bottom, 20)
    }
}

struct FeedbackText: View {
    let text: String
    let isVisible: Bool
    
    @Environment(\.colorScheme) private var colorScheme
    private var textColor: Color { colorScheme == .dark ? .white : .black }

    var body: some View {
        Text(isVisible ? text : " ")
            .foregroundColor(isVisible ? textColor : .clear)
            .padding(.vertical, 9).padding(.horizontal)
            .frame(maxWidth: .infinity, alignment: .center)
            .frame(height: 55)
    }
}

struct WordDisplay: View {
    let questionWord: String
    let transcription: String?
    let studiedLanguage: String
    let showTranscription: Bool
    let speakWord: (String, String) -> Void

    var body: some View {
        VStack {
            HStack(spacing: 10) {
                Text(questionWord)
                    .font(.system(size: 40, weight: .bold))
                
                Button(action: {
                    speakWord(questionWord, studiedLanguage)
                }) {
                    Image(systemName: "speaker.wave.3.fill")
                        .font(.title).foregroundColor(.blue)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.bottom, 8)

            if let trans = transcription, studiedLanguage == "el" {
                Text(showTranscription ? trans : String(repeating: "*", count: trans.count))
                    .font(.system(size: 28)).foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                 Text(" ").font(.system(size: 28))
            }
        }
        .padding(.bottom, 16)
    }
}

struct NavButton: View {
    let systemName: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.largeTitle).foregroundColor(.blue)
                .background(Color.white.opacity(0.1)).cornerRadius(8)
        }
    }
}

#Preview {
    ContentView()
}
