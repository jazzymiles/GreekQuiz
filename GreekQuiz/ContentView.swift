import SwiftUI
import AVFoundation
import WebKit

struct Word: Codable, Equatable, Identifiable {
    let id = UUID()
    let ru: String
    let el: String
    let transcription: String
    let category: String?
    let gender: String?
    var dictionaryName: String?
}

enum QuizMode: String, CaseIterable, Identifiable {
    case keyboard
    case quiz
    case cards // NEW: Added cards mode

    var id: String { self.rawValue }

    var displayName: String {
        switch self {
        case .keyboard: return "Ввод"
        case .quiz: return "Тест"
        case .cards: return "Карточки"
        }
    }
}

struct DictionaryInfo: Codable, Identifiable, Hashable {
    let id = UUID()
    let name: String
    var filePath: String
}

enum DictionarySource: String, CaseIterable, Identifiable, Codable {
    case standard
    case customURL

    var id: String { self.rawValue }

    var displayName: String {
        switch self {
        case .standard: return "Стандартные (из приложения)"
        case .customURL: return "Свой адрес (из интернета)"
        }
    }
}

// NEW: CardView for the new cards mode
struct CardView: View {
    let word: Word
    let quizLanguage: String
    let showTranscription: Bool
    let speakWord: (String, String) -> Void
    @Binding var showTranslation: Bool // Use Binding to control translation visibility from parent

    var body: some View {
        VStack {
            Spacer()
            
            Text(quizLanguage == "ru" ? word.el : word.ru) // Display Greek if quizLanguage is Russian, else Russian
                .font(.system(size: 40, weight: .bold))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if quizLanguage == "ru" { // Only show transcription for Greek words
                Text(showTranscription ? word.transcription : String(repeating: "*", count: word.transcription.count))
                    .font(.system(size: 28))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Button(action: {
                // Speak the word that is currently displayed for translation
                let wordToSpeak = quizLanguage == "ru" ? word.el : word.ru
                let languageCode = quizLanguage == "ru" ? "el-GR" : "ru-RU"
                speakWord(wordToSpeak, languageCode)
            }) {
                Image(systemName: "speaker.wave.3.fill")
                    .font(.title)
                    .foregroundColor(.blue)
            }
            .padding(.top, 10)
            
            Spacer()
            
            if showTranslation {
                Text(quizLanguage == "ru" ? word.ru : word.el) // Display Russian if quizLanguage is Russian, else Greek
                    .font(.system(size: 32))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .transition(.opacity) // Smooth transition for showing translation
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.opacity(0.1)) // Subtle background for the card
        .cornerRadius(20)
        .shadow(radius: 5)
        .padding()
        .onTapGesture {
            withAnimation {
                showTranslation.toggle()
            }
        }
    }
}

struct ContentView: View {

    @State private var allDictionaries: [DictionaryInfo] = []
    @State private var selectedDictionaries: Set<String> = []
    @State private var allWords: [Word] = []
    @State private var activeWords: [Word] = []
    @State private var currentWordIndex = 0

    @State private var userInput = ""
    @State private var showAnswer = false
    @State private var isCorrect = false
    @State private var isShowingFeedback = false
    @State private var score = UserDefaults.standard.integer(forKey: "score")
    @FocusState private var isTextFieldFocused: Bool
            
    @AppStorage("currentQuizMode") private var quizMode: QuizMode = .keyboard
            
    @State private var selectedAnswer: String? = nil
            
    @State private var cardOptions: [String] = []

    @State private var showingDictionarySelection = false
    @State private var showingRules = false
    @State private var showingSettings = false

    @AppStorage("showTranscription") private var showTranscription: Bool = true
    @AppStorage("autoPlaySound") private var autoPlaySound: Bool = true
    @AppStorage("colorSchemePreference") private var colorSchemePreference: String = "system"

    @AppStorage("dictionarySourcePreference") private var dictionarySource: DictionarySource = .standard
    @AppStorage("customDictionaryURL") private var customDictionaryURL: String = ""

    @AppStorage("downloadedDictionaryMetadata") private var downloadedDictionaryMetadataData: Data = Data()
    @AppStorage("quizLanguage") private var quizLanguage: String = "ru" // "ru" for Russian, "el" for Greek
    
    // NEW: State for Card mode specific translation visibility
    @State private var showCardTranslation: Bool = false

    private let synthesizer = AVSpeechSynthesizer()

    @Environment(\.colorScheme) var currentSystemColorScheme: ColorScheme

    private var downloadedDictionariesDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DownloadedDictionaries")
    }

    var body: some View {
        ZStack {
            backgroundColor()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // NEW: Mode Picker
                Picker("Режим", selection: $quizMode) {
                    ForEach(QuizMode.allCases) { mode in
                        Text(mode.displayName)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 10)
                .onChange(of: quizMode) { oldMode, newMode in
                    if oldMode != newMode {
                        resetQuizState()
                        if newMode == .quiz {
                            generateCardOptions()
                        } else if newMode == .cards { // NEW: Reset card translation when entering cards mode
                            showCardTranslation = false
                            // Speak the word when entering cards mode
                            if autoPlaySound && !activeWords.isEmpty {
                                let wordToSpeak = quizLanguage == "ru" ? activeWords[currentWordIndex].el : activeWords[currentWordIndex].ru
                                let languageCode = quizLanguage == "ru" ? "el-GR" : "ru-RU"
                                speakWord(wordToSpeak, language: languageCode)
                            }
                        } else if newMode == .keyboard {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                isTextFieldFocused = true
                            }
                        }
                    }
                }

                HStack(spacing: 8) {
                    Spacer()

                    Button(action: {
                        showingRules = true
                    }) {
                        Image("rules")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 30, height: 30)
                            .padding(8)
                            .background(Color.gray.opacity(0.3))
                            .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .sheet(isPresented: $showingRules) {
                        RulesSheetView(htmlFileName: "rules-el")
                    }

                    Button(action: {
                        showingDictionarySelection = true
                    }) {
                        Image("dic")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 30, height: 30)
                            .padding(8)
                            .background(Color.gray.opacity(0.3))
                            .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .sheet(isPresented: $showingDictionarySelection) {
                        DictionarySelectionView(
                            allDictionaries: $allDictionaries,
                            selectedDictionaries: $selectedDictionaries,
                            loadSelectedWords: loadSelectedWords,
                            allWords: $allWords,
                            activeWords: $activeWords,
                            speakWord: speakWord
                        )
                    }

                    Button(action: {
                        showingSettings = true
                    }) {
                        Image("settings")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 30, height: 30)
                            .padding(8)
                            .background(Color.gray.opacity(0.3))
                            .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .sheet(isPresented: $showingSettings) {
                        SettingsView(
                            showTranscription: $showTranscription,
                            autoPlaySound: $autoPlaySound,
                            colorSchemePreference: $colorSchemePreference,
                            dictionarySource: $dictionarySource,
                            customDictionaryURL: $customDictionaryURL,
                            quizLanguage: $quizLanguage,
                            onDownloadDictionaries: {
                                Task {
                                    await downloadAndSaveDictionariesBasedOnSource()
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.top, 10)

                Spacer()

                VStack(spacing: 0) {
                    if !activeWords.isEmpty {
                        if quizMode == .keyboard {
                            HStack(spacing: 10) {
                                Text(quizLanguage == "ru" ? activeWords[currentWordIndex].el : activeWords[currentWordIndex].ru)
                                    .font(.system(size: 40, weight: .bold))
                                
                                Button(action: {
                                    let wordToSpeak = quizLanguage == "ru" ? activeWords[currentWordIndex].el : activeWords[currentWordIndex].ru
                                    let languageCode = quizLanguage == "ru" ? "el-GR" : "ru-RU"
                                    speakWord(wordToSpeak, language: languageCode)
                                }) {
                                    Image(systemName: "speaker.wave.3.fill")
                                        .font(.title)
                                        .foregroundColor(.blue)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.bottom, 8)

                            HStack(spacing: 5) {
                                if quizLanguage == "ru" {
                                    Text(showTranscription ? activeWords[currentWordIndex].transcription : String(repeating: "*", count: activeWords[currentWordIndex].transcription.count))
                                        .font(.system(size: 28))
                                        .foregroundColor(.gray)
                                        .padding(.leading, 10)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                } else {
                                    Text(" ")
                                        .font(.system(size: 28))
                                        .foregroundColor(.gray)
                                        .padding(.leading, 10)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                }
                            }
                            .padding(.bottom, 16)
                            
                            TextField(quizLanguage == "ru" ? "Ваш перевод" : "Your translation", text: $userInput)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding(.horizontal)
                                .focused($isTextFieldFocused)
                                .padding(.bottom, 18)

                            Button(action: {
                                if showAnswer {
                                    nextWord()
                                } else {
                                    checkAnswer()
                                }
                            }) {
                                Text(showAnswer ? "Дальше" : "Проверить")
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.horizontal)
                            .padding(.bottom, 20)

                            Text(showAnswer ? "Правильный перевод: \(quizLanguage == "ru" ? activeWords[currentWordIndex].ru : activeWords[currentWordIndex].el)" : " ")
                                .foregroundColor(showAnswer ? (getPreferredColorScheme() == .light ? .black : .white) : .clear)
                                .padding(.vertical, 9)
                                .padding(.horizontal)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .frame(height: 55)
                            
                        } else if quizMode == .quiz {
                            HStack(spacing: 10) {
                                Text(quizLanguage == "ru" ? activeWords[currentWordIndex].el : activeWords[currentWordIndex].ru)
                                    .font(.system(size: 40, weight: .bold))
                                
                                Button(action: {
                                    let wordToSpeak = quizLanguage == "ru" ? activeWords[currentWordIndex].el : activeWords[currentWordIndex].ru
                                    let languageCode = quizLanguage == "ru" ? "el-GR" : "ru-RU"
                                    speakWord(wordToSpeak, language: languageCode)
                                }) {
                                    Image(systemName: "speaker.wave.3.fill")
                                        .font(.title)
                                        .foregroundColor(.blue)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.bottom, 8)

                            HStack(spacing: 5) {
                                if quizLanguage == "ru" {
                                    Text(showTranscription ? activeWords[currentWordIndex].transcription : String(repeating: "*", count: activeWords[currentWordIndex].transcription.count))
                                        .font(.system(size: 28))
                                        .foregroundColor(.gray)
                                        .padding(.leading, 10)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                } else {
                                    Text(" ")
                                        .font(.system(size: 28))
                                        .foregroundColor(.gray)
                                        .padding(.leading, 10)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                }
                            }
                            .padding(.bottom, 16)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 10) {
                                ForEach(cardOptions, id: \.self) { option in
                                    Button(action: {
                                        selectedAnswer = option
                                        if quizLanguage == "el" {
                                            speakWord(option, language: "el-GR")
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

                            Button(action: {
                                if showAnswer {
                                    nextWord()
                                    selectedAnswer = nil
                                    generateCardOptions()
                                } else {
                                    checkCardAnswer()
                                }
                            }) {
                                Text(showAnswer ? "Дальше" : "Проверить")
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.horizontal)
                            .padding(.bottom, 20)

                            Text(showAnswer ? "Правильный перевод: \(quizLanguage == "ru" ? activeWords[currentWordIndex].ru : activeWords[currentWordIndex].el)" : " ")
                                .foregroundColor(showAnswer ? (getPreferredColorScheme() == .light ? .black : .white) : .clear)
                                .padding(.vertical, 9)
                                .padding(.horizontal)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .frame(height: 55)

                        } else if quizMode == .cards { // NEW: Cards mode UI
                            CardView(
                                word: activeWords[currentWordIndex],
                                quizLanguage: quizLanguage,
                                showTranscription: showTranscription,
                                speakWord: speakWord,
                                showTranslation: $showCardTranslation // Pass binding
                            )
                            .gesture(
                                DragGesture()
                                    .onEnded { gesture in
                                        if gesture.translation.width < -50 {
                                            // Swipe left
                                            nextWord()
                                        } else if gesture.translation.width > 50 {
                                            // Swipe right
                                            previousWord()
                                        }
                                    }
                            )
                            Spacer() // Push card to center
                            
                            HStack {
                                Button(action: {
                                    previousWord()
                                }) {
                                    Image(systemName: "arrow.left.circle.fill")
                                        .font(.largeTitle)
                                        .foregroundColor(.blue)
                                }
                                Spacer()
                                Button(action: {
                                    nextWord()
                                }) {
                                    Image(systemName: "arrow.right.circle.fill")
                                        .font(.largeTitle)
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(.horizontal, 40)
                            .padding(.bottom, 20)
                        }
                    } else {
                        Text("Выберите хотя бы один словарь.")
                            .foregroundColor(.gray)
                    }
                }
                .padding(.bottom, 30)

                Spacer()
            }
        }
        .preferredColorScheme(getPreferredColorScheme())
        .onAppear {
            loadDictionariesMetadataAndWords()
            if quizMode == .quiz {
                generateCardOptions()
            } else if quizMode == .cards { // NEW: Initialize for cards mode
                showCardTranslation = false // Ensure translation is hidden initially
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                if autoPlaySound && !activeWords.isEmpty {
                    let wordToSpeak = quizLanguage == "ru" ? activeWords[currentWordIndex].el : activeWords[currentWordIndex].ru
                    let languageCode = quizLanguage == "ru" ? "el-GR" : "ru-RU"
                    speakWord(wordToSpeak, language: languageCode)
                }
                if quizMode == .keyboard {
                    isTextFieldFocused = true
                }
            }
        }
        .onChange(of: userInput) { _ in
            if quizMode == .keyboard && !isTextFieldFocused {
                isTextFieldFocused = true
            }
        }
        .onChange(of: activeWords) { oldWords, newWords in
            if oldWords.count != newWords.count {
                if quizMode == .quiz {
                    generateCardOptions()
                } else if quizMode == .cards { // NEW: Reset card translation if active words change
                    showCardTranslation = false
                }
            }
        }
    }

    func checkAnswer() {
        let input = userInput.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let corrects: [String]
        if quizLanguage == "ru" {
            corrects = parseAcceptedAnswers(from: activeWords[currentWordIndex].ru)
        } else {
            corrects = parseAcceptedAnswers(from: activeWords[currentWordIndex].el)
        }

        withAnimation(nil) {
            if corrects.contains(input) {
                isCorrect = true
                showAnswer = true
                score += 1
                UserDefaults.standard.set(score, forKey: "score")
                isShowingFeedback = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    isShowingFeedback = false
                }
            } else {
                isCorrect = false
                showAnswer = true
            }
        }
    }

    func resetQuizState() {
        userInput = ""
        showAnswer = false
        isCorrect = false
        isShowingFeedback = false
        selectedAnswer = nil
        showCardTranslation = false // NEW: Reset for cards mode
        isTextFieldFocused = true
        if !activeWords.isEmpty {
            currentWordIndex = Int.random(in: 0..<activeWords.count)
        }
    }

    func generateCardOptions() {
        guard !activeWords.isEmpty else {
            cardOptions = []
            return
        }

        var options: [String] = []
        let currentCorrectAnswer: String
        let allPossibleAnswers: [String]

        if quizLanguage == "ru" {
            currentCorrectAnswer = activeWords[currentWordIndex].ru
            allPossibleAnswers = allWords.map { $0.ru }
        } else {
            currentCorrectAnswer = activeWords[currentWordIndex].el
            allPossibleAnswers = allWords.map { $0.el }
        }

        options.append(parseAcceptedAnswers(from: currentCorrectAnswer).first ?? currentCorrectAnswer)

        var shuffledAllWordsForOptions = allPossibleAnswers.shuffled()
        var incorrectCount = 0
        while options.count < 6 && incorrectCount < allPossibleAnswers.count * 2 {
            if let randomOption = shuffledAllWordsForOptions.popLast() {
                let possibleIncorrectAnswer = parseAcceptedAnswers(from: randomOption).first ?? randomOption
                if possibleIncorrectAnswer.lowercased() != currentCorrectAnswer.lowercased() && !options.contains(possibleIncorrectAnswer) {
                    options.append(possibleIncorrectAnswer)
                }
            } else {
                break
            }
            incorrectCount += 1
        }
        
        cardOptions = options.shuffled()
        
        while cardOptions.count < 6 {
            cardOptions.append("-----")
        }
    }
    
    func checkCardAnswer() {
        withAnimation(nil) {
            if selectedAnswer == nil {
                isCorrect = false
                showAnswer = true
                print("Ошибка: Ответ не выбран. Показ правильного ответа.")
                return
            }

            let correctAnswers: [String]
            if quizLanguage == "ru" {
                correctAnswers = parseAcceptedAnswers(from: activeWords[currentWordIndex].ru)
            } else {
                correctAnswers = parseAcceptedAnswers(from: activeWords[currentWordIndex].el)
            }
            
            if correctAnswers.contains(selectedAnswer!.lowercased()) {
                isCorrect = true
                showAnswer = true
                score += 1
                UserDefaults.standard.set(score, forKey: "score")
                isShowingFeedback = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    isShowingFeedback = false
                }
            } else {
                isCorrect = false
                showAnswer = true
            }
        }
    }

    func nextWord() {
        withAnimation(nil) {
            userInput = ""
            showAnswer = false
            isCorrect = false
            isTextFieldFocused = true
            selectedAnswer = nil
            showCardTranslation = false // NEW: Hide translation for next card

            if !activeWords.isEmpty {
                currentWordIndex = (currentWordIndex + 1) % activeWords.count
                if quizMode == .quiz {
                    generateCardOptions()
                }
                if autoPlaySound {
                    let wordToSpeak = quizLanguage == "ru" ? activeWords[currentWordIndex].el : activeWords[currentWordIndex].ru
                    let languageCode = quizLanguage == "ru" ? "el-GR" : "ru-RU"
                    speakWord(wordToSpeak, language: languageCode)
                }
            }
        }
    }

    // NEW: Function to go to the previous word in cards mode
    func previousWord() {
        withAnimation(nil) {
            userInput = ""
            showAnswer = false
            isCorrect = false
            isTextFieldFocused = true
            selectedAnswer = nil
            showCardTranslation = false // NEW: Hide translation for previous card

            if !activeWords.isEmpty {
                currentWordIndex = (currentWordIndex - 1 + activeWords.count) % activeWords.count
                if quizMode == .quiz {
                    generateCardOptions()
                }
                if autoPlaySound {
                    let wordToSpeak = quizLanguage == "ru" ? activeWords[currentWordIndex].el : activeWords[currentWordIndex].ru
                    let languageCode = quizLanguage == "ru" ? "el-GR" : "ru-RU"
                    speakWord(wordToSpeak, language: languageCode)
                }
            }
        }
    }
    
    func downloadAndSaveDictionariesBasedOnSource() async {
        allDictionaries = []
        selectedDictionaries = []
        allWords = []
        activeWords = []
        currentWordIndex = 0

        await clearDownloadedDictionaries()

        let dictionariesListSourceURLString: String
        
        var determinedBaseURLForFiles: String = ""

        let dictionariesListFileName = "dictionaries.txt"

        if dictionarySource == .standard {
            determinedBaseURLForFiles = "https://www.dropbox.com/scl/fi/z9avztiil4v150g0h58i8/"
            dictionariesListSourceURLString = "\(determinedBaseURLForFiles)\(dictionariesListFileName)?rlkey=k5mrqfwgdgwz2wt8q1wu3ernj&st=peuf016l&raw=1"
            print("Начинаем скачивание стандартных словарей с URL: \(dictionariesListSourceURLString)")
        } else if dictionarySource == .customURL {
            guard !customDictionaryURL.isEmpty else {
                print("Некорректный источник словарей или пустой URL для скачивания.")
                return
            }
            dictionariesListSourceURLString = customDictionaryURL.hasSuffix("raw=1") ? customDictionaryURL : "\(customDictionaryURL)&raw=1"
            
            if let url = URL(string: customDictionaryURL),
               let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let host = components.host,
               let scheme = components.scheme {
                
                let path = components.path.replacingOccurrences(of: dictionariesListFileName, with: "")
                determinedBaseURLForFiles = "\(scheme)://\(host)\(path)"
            } else {
                print("Не удалось определить базовый URL для дополнительных файлов из пользовательского URL. Используем пустую строку.")
                determinedBaseURLForFiles = ""
            }
            print("Начинаем скачивание пользовательских словарей с URL: \(dictionariesListSourceURLString)")
        } else {
            print("Неизвестный источник словарей.")
            return
        }

        guard let remoteDictionariesURL = URL(string: dictionariesListSourceURLString) else {
            print("Некорректный URL для списка словарей: \(dictionariesListSourceURLString)")
            return
        }

        var downloadedMetadata: [DictionaryInfo] = []
        var mainData: Data?
        
        do {
            let (data, response) = try await URLSession.shared.data(from: remoteDictionariesURL)
            mainData = data
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                print("Ошибка HTTP при загрузке списка словарей: Статус \(httpResponse.statusCode)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Ответ сервера (HTML/Ошибка):\n\(responseString.prefix(500))...")
                }
                throw URLError(.badServerResponse)
            }

            guard let responseString = String(data: data, encoding: .utf8), responseString.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("[") else {
                print("Полученные данные не похожи на JSON-массив для списка словарей. Возможно, это HTML-страница ошибки или перенаправления.")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Содержимое (не JSON):\n\(responseString.prefix(500))...")
                }
                throw URLError(.cannotDecodeContentData)
            }

            let remoteDictsInfo = try JSONDecoder().decode([DictionaryInfo].self, from: data)

            try FileManager.default.createDirectory(at: downloadedDictionariesDirectory, withIntermediateDirectories: true, attributes: nil)

            for var dictInfo in remoteDictsInfo {
                let wordListSourceURLString = dictInfo.filePath

                let finalWordListURLString = wordListSourceURLString.contains("dropbox.com") && !wordListSourceURLString.hasSuffix("raw=1") ? "\(wordListSourceURLString)&raw=1" : wordListSourceURLString

                print("URL для загрузки словаря '\(dictInfo.name)': \(finalWordListURLString)")

                guard let remoteWordListURL = URL(string: finalWordListURLString) else {
                    print("Некорректный URL для словаря: \(dictInfo.name) - \(finalWordListURLString)")
                    continue
                }

                var wordListData: Data?
                do {
                    let (dataFromWordList, wordListResponse) = try await URLSession.shared.data(from: remoteWordListURL)
                    wordListData = dataFromWordList
                    
                    if let httpResponse = wordListResponse as? HTTPURLResponse, httpResponse.statusCode != 200 {
                        print("Ошибка HTTP при загрузке словаря '\(dictInfo.name)': Статус \(httpResponse.statusCode)")
                        if let responseString = String(data: dataFromWordList, encoding: .utf8) {
                            print("Ответ сервера (HTML/Ошибка):\n\(responseString.prefix(500))...")
                        }
                        throw URLError(.badServerResponse)
                    }

                    guard let wordListContentString = String(data: dataFromWordList, encoding: .utf8), wordListContentString.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("[") else {
                        print("Полученные данные для словаря '\(dictInfo.name)' не похожи на JSON-массив. Возможно, это HTML-страница ошибки или перенаправления.")
                        if let responseString = String(data: dataFromWordList, encoding: .utf8) {
                            print("Содержимое (не JSON) для '\(dictInfo.name)':\n\(responseString.prefix(500))...")
                        }
                        throw URLError(.cannotDecodeContentData)
                    }

                    let localFileName = UUID().uuidString + ".txt"
                    let localFileURL = downloadedDictionariesDirectory.appendingPathComponent(localFileName)
                    
                    try dataFromWordList.write(to: localFileURL)
                    print("Словарь '\(dictInfo.name)' успешно скачан и сохранен как: \(localFileURL.lastPathComponent)")

                    if let fileContent = String(data: dataFromWordList, encoding: .utf8) {
                        print("Содержимое скачанного файла '\(dictInfo.name)':\n\(fileContent.prefix(500))...")
                    } else {
                        print("Не удалось декодировать содержимое скачанного файла '\(dictInfo.name)' как UTF-8 строку.")
                    }

                    dictInfo.filePath = localFileURL.lastPathComponent
                    downloadedMetadata.append(dictInfo)

                } catch {
                    print("Ошибка скачивания или сохранения словаря '\(dictInfo.name)': \(error.localizedDescription)")
                    if let decodingError = error as? DecodingError {
                        switch decodingError {
                        case .dataCorrupted(let context):
                            print("Data corrupted at key path: \(context.codingPath.map { $0.stringValue }.joined(separator: ".")) - \(context.debugDescription)")
                        case .keyNotFound(let key, let context):
                            print("Key '\(key.stringValue)' not found at key path: \(context.codingPath.map { $0.stringValue }.joined(separator: ".")) - \(context.debugDescription)")
                        case .typeMismatch(let type, let context):
                            print("Type mismatch for \(type) at key path: \(context.codingPath.map { $0.stringValue }.joined(separator: ".")) - \(context.debugDescription)")
                            if let dataString = String(data: wordListData ?? Data(), encoding: .utf8) {
                                print("Некорректные данные для типа: \(dataString.prefix(200))...")
                            }
                        case .valueNotFound(let type, let context):
                            print("Value not found for \(type) at key path: \(context.codingPath.map { $0.stringValue }.joined(separator: ".")) - \(context.debugDescription)")
                        @unknown default:
                            print("Unknown decoding error.")
                        }
                    }
                }
            }

            let encodedMetadata = try JSONEncoder().encode(downloadedMetadata)
            await MainActor.run {
                self.downloadedDictionaryMetadataData = encodedMetadata
                self.allDictionaries = downloadedMetadata
                self.selectedDictionaries = []
                print("Метаданные скачанных словарей сохранены.")
                self.loadSelectedWords()
            }

        } catch {
            print("Ошибка загрузки списка словарей или парсинга: \(error.localizedDescription)")
            if let urlError = error as? URLError {
                print("URL Error Code: \(urlError.code.rawValue)")
                if urlError.code == .badServerResponse, let data = mainData, let responseString = String(data: data, encoding: .utf8) {
                    print("Содержимое ответа при ошибке сервера:\n\(responseString.prefix(500))...")
                }
            }
            await MainActor.run {
                self.allDictionaries = []
                self.downloadedDictionaryMetadataData = Data()
            }
        }
    }

    func loadDictionariesMetadataAndWords() {
        allDictionaries = []
        selectedDictionaries = []
        allWords = []
        activeWords = []
        currentWordIndex = 0

        Task {
            guard !downloadedDictionaryMetadataData.isEmpty else {
                print("Нет сохраненных метаданных для словарей. Ожидание скачивания.")
                return
            }
            
            do {
                let decodedMetadata = try JSONDecoder().decode([DictionaryInfo].self, from: downloadedDictionaryMetadataData)
                await MainActor.run {
                    self.allDictionaries = decodedMetadata
                    print("Загружены метаданные сохраненных словарей.")
                    self.loadSelectedWords()
                }
            } catch {
                print("Ошибка декодирования сохраненных метаданных словарей: \(error.localizedDescription)")
                if let corruptedString = String(data: downloadedDictionaryMetadataData, encoding: .utf8) {
                    print("Поврежденные метаданные:\n\(corruptedString.prefix(500))...")
                }
            }
        }
    }

    func clearDownloadedDictionaries() async {
        let fileManager = FileManager.default
        do {
            if fileManager.fileExists(atPath: downloadedDictionariesDirectory.path) {
                try fileManager.removeItem(at: downloadedDictionariesDirectory)
                print("Папка с скачанными словарями очищена: \(downloadedDictionariesDirectory.lastPathComponent)")
            }
        } catch {
            print("Ошибка при очистке папки скачанных словарей: \(error.localizedDescription)")
        }
        await MainActor.run {
            self.downloadedDictionaryMetadataData = Data()
            self.allDictionaries = []
            self.selectedDictionaries = []
        }
    }

    func loadSelectedWords() {
        Task {
            guard FileManager.default.fileExists(atPath: downloadedDictionariesDirectory.path) else {
                print("Директория скачанных словарей не существует: \(downloadedDictionariesDirectory.path)")
                await MainActor.run {
                    self.allWords = []
                    self.activeWords = []
                }
                return
            }

            var tempAllWords: [Word] = []
            var tempActiveWords: [Word] = []

            for dictInfo in allDictionaries {
                let filePath = downloadedDictionariesDirectory.appendingPathComponent(dictInfo.filePath)
                
                print("Попытка загрузить локальный файл словаря: \(filePath.path)")
                if !FileManager.default.fileExists(atPath: filePath.path) {
                    print("Ошибка: Локальный файл словаря не найден по пути: \(filePath.path)")
                    continue
                }

                var localFileData: Data?
                do {
                    let data = try Data(contentsOf: filePath)
                    localFileData = data
                    print("Размер данных локального файла: \(data.count) байт")

                    if let fileContent = String(data: data, encoding: .utf8) {
                        print("Содержимое локального файла '\(dictInfo.name)':\n\(fileContent.prefix(500))...")
                    } else {
                        print("Не удалось декодировать содержимое локального файла '\(dictInfo.name)' как UTF-8 строку.")
                    }

                    var decodedWords = try JSONDecoder().decode([Word].self, from: data)
                                    
                                    for i in 0..<decodedWords.count {
                                        decodedWords[i].dictionaryName = dictInfo.name
                                    }

                                    tempAllWords.append(contentsOf: decodedWords)

                                    if selectedDictionaries.contains(dictInfo.filePath) {
                                        tempActiveWords.append(contentsOf: decodedWords)
                                        print("Словарь загружен для активного использования: \(dictInfo.name) из \(filePath.lastPathComponent)")
                                    } else {
                                        print("Словарь загружен (но не активен): \(dictInfo.name) из \(filePath.lastPathComponent)")
                                    }

                } catch {
                    print("Ошибка загрузки или парсинга локального словаря \(dictInfo.name) по пути \(filePath.lastPathComponent): \(error.localizedDescription)")
                    if let decodingError = error as? DecodingError {
                        switch decodingError {
                        case .dataCorrupted(let context):
                            print("Data corrupted at key path: \(context.codingPath.map { $0.stringValue }.joined(separator: ".")) - \(context.debugDescription)")
                        case .keyNotFound(let key, let context):
                            print("Key '\(key.stringValue)' not found at key path: \(context.codingPath.map { $0.stringValue }.joined(separator: ".")) - \(context.debugDescription)")
                        case .typeMismatch(let type, let context):
                            print("Type mismatch for \(type) at key path: \(context.codingPath.map { $0.stringValue }.joined(separator: ".")) - \(context.debugDescription)")
                            if let dataString = String(data: localFileData ?? Data(), encoding: .utf8) {
                                print("Некорректные данные для типа: \(dataString.prefix(200))...")
                            }
                        case .valueNotFound(let type, let context):
                            print("Value not found for \(type) at key path: \(context.codingPath.map { $0.stringValue }.joined(separator: ".")) - \(context.debugDescription)")
                        @unknown default:
                            print("Unknown decoding error.")
                        }
                    }
                }
            }
            
            await MainActor.run {
                self.allWords = tempAllWords
                self.activeWords = tempActiveWords.shuffled()
                if !self.activeWords.isEmpty {
                    self.currentWordIndex = 0
                }
                print("Загружено \(self.allWords.count) всех слов.")
                print("Загружено \(self.activeWords.count) активных слов для квиза.")
                if self.allWords.isEmpty && self.selectedDictionaries.isEmpty {
                    print("Подсказка: Слова не загружены, возможно, ни один словарь не выбран в окне выбора словарей.")
                }
            }
        }
    }

    func backgroundColor() -> Color {
        if isShowingFeedback {
            return Color.green.opacity(0.6)
        }
        if showAnswer {
            return isCorrect ? Color.green.opacity(0.6) : Color.red.opacity(0.6)
        }
        
        if colorSchemePreference == "dark" {
            return Color(red: 0.15, green: 0.15, blue: 0.15)
        } else if colorSchemePreference == "light" {
            return Color(.systemBackground)
        } else {
            return Color(.systemBackground)
        }
    }

    func getThemeIconName() -> String {
        switch colorSchemePreference {
        case "system":
            return currentSystemColorScheme == .dark ? "dark" : "bright"
        case "light":
            return "bright"
        case "dark":
            return "dark"
        default:
            return "bright"
        }
    }
    
    func getPreferredColorScheme() -> ColorScheme? {
        switch colorSchemePreference {
        case "light":
            return .light
        case "dark":
            return .dark
        case "system":
            return nil
        default:
            return nil
        }
    }
    
    func parseAcceptedAnswers(from raw: String) -> [String] {
        let withoutParentheses = raw.replacingOccurrences(of: "\\(.*?\\)", with: "", options: .regularExpression)
        let parts = withoutParentheses
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        return parts
    }
    
    func speakWord(_ text: String, language: String) {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: text)
        
        if let voice = AVSpeechSynthesisVoice(language: language) {
            utterance.voice = voice
            print("Используется голос для языка: \(language) - \(voice.identifier)")
        } else {
            print("Голос для языка '\(language)' не найден. Попытка найти альтернативный греческий голос.")
            let availableGreekVoices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("el") }
            if let firstGreekVoice = availableGreekVoices.first {
                utterance.voice = firstGreekVoice
                print("Используется доступный греческий голос: \(firstGreekVoice.identifier)")
            } else {
                utterance.voice = AVSpeechSynthesisVoice(language: Locale.current.identifier)
                print("Греческий голос не найден. Используется системный голос по умолчанию: \(Locale.current.identifier)")
            }
        }
        
        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.0

        synthesizer.speak(utterance)
    }
}
#Preview {
    ContentView()
}
