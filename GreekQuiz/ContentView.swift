import SwiftUI
import AVFoundation
import WebKit

struct Word: Codable, Equatable {
    let ru: String
    let el: String
    let transcription: String
    // ОЧЕНЬ ВАЖНО: Добавьте эти поля, если они есть в вашем JSON!
    // JSONDecoder выдаст ошибку, если в файле есть поля, которых нет в struct Word.
    let category: String? // Сделаем опциональным, если не всегда есть
    let gender: String?   // Сделаем опциональным, если не всегда есть
}

enum QuizMode: String, CaseIterable, Identifiable {
    case keyboard
    case cards

    var id: String { self.rawValue }
}

struct DictionaryInfo: Codable, Identifiable, Hashable {
    let id = UUID()
    let name: String
    var filename: String
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
                HStack(spacing: 8) {
                    Button(action: {
                        quizMode = .cards
                        resetQuizState()
                        generateCardOptions()
                    }) {
                        Image("cards")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 30, height: 30)
                            .padding(8)
                            .background(quizMode == .cards ? Color.blue.opacity(0.7) : Color.gray.opacity(0.3))
                            .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: {
                        quizMode = .keyboard
                        resetQuizState()
                    }) {
                        Image("keyboard")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 30, height: 30)
                            .padding(8)
                            .background(quizMode == .keyboard ? Color.blue.opacity(0.7) : Color.gray.opacity(0.3))
                            .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())

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
                            loadSelectedWords: loadSelectedWords
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
                        HStack(spacing: 10) {
                            Text(activeWords[currentWordIndex].el)
                                .font(.system(size: 40, weight: .bold))
                                
                            Button(action: {
                                speakWord(activeWords[currentWordIndex].el, language: "el-GR")
                            }) {
                                Image(systemName: "speaker.wave.3.fill")
                                    .font(.title)
                                    .foregroundColor(.blue)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.bottom, 8)

                        HStack(spacing: 5) {
                            Text(showTranscription ? activeWords[currentWordIndex].transcription : String(repeating: "*", count: activeWords[currentWordIndex].transcription.count))
                                .font(.system(size: 28))
                                .foregroundColor(.gray)
                                .padding(.leading, 10)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .padding(.bottom, 16)
                        
                        if quizMode == .keyboard {
                            TextField("Ваш перевод", text: $userInput)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding(.horizontal)
                                .focused($isTextFieldFocused)
                                .padding(.bottom, 18)
                        } else {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 10) {
                                ForEach(cardOptions, id: \.self) { option in
                                    Button(action: {
                                        selectedAnswer = option
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
                        }

                        Button(action: {
                            if showAnswer {
                                nextWord()
                                if quizMode == .cards {
                                    selectedAnswer = nil
                                    generateCardOptions()
                                }
                            } else {
                                if quizMode == .keyboard {
                                    checkAnswer()
                                } else {
                                    checkCardAnswer()
                                }
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

                        Text(showAnswer ? "Правильный перевод: \(activeWords[currentWordIndex].ru)" : " ")
                            .foregroundColor(showAnswer ? (getPreferredColorScheme() == .light ? .black : .white) : .clear)
                            .padding(.vertical, 9)
                            .padding(.horizontal)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .frame(height: 55)
                        
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
            if quizMode == .cards {
                generateCardOptions()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                if quizMode == .keyboard {
                    isTextFieldFocused = true
                }
                if autoPlaySound && !activeWords.isEmpty {
                    speakWord(activeWords[currentWordIndex].el, language: "el-GR")
                }
            }
        }
        .onChange(of: userInput) { _ in
            if quizMode == .keyboard && !isTextFieldFocused {
                isTextFieldFocused = true
            }
        }
        .onChange(of: quizMode) { oldMode, newMode in
            if oldMode != newMode {
                resetQuizState()
                if newMode == .cards {
                    generateCardOptions()
                } else if newMode == .keyboard {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                         isTextFieldFocused = true
                    }
                }
            }
        }
        .onChange(of: activeWords) { oldWords, newWords in
            if oldWords.count != newWords.count && quizMode == .cards {
                generateCardOptions()
            }
        }
    }

    func checkAnswer() {
        let input = userInput.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let corrects = parseAcceptedAnswers(from: activeWords[currentWordIndex].ru)

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
        let currentCorrectAnswer = activeWords[currentWordIndex].ru

        options.append(parseAcceptedAnswers(from: currentCorrectAnswer).first ?? currentCorrectAnswer)

        var shuffledAllWords = allWords.shuffled()
        var incorrectCount = 0
        while options.count < 6 && incorrectCount < allWords.count * 2 {
            if let randomWord = shuffledAllWords.popLast() {
                let possibleIncorrectAnswer = parseAcceptedAnswers(from: randomWord.ru).first ?? randomWord.ru
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

            let correctAnswers = parseAcceptedAnswers(from: activeWords[currentWordIndex].ru)
            
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
            if !activeWords.isEmpty {
                currentWordIndex = Int.random(in: 0..<activeWords.count)
                if quizMode == .cards {
                    generateCardOptions()
                }
                if autoPlaySound {
                    speakWord(activeWords[currentWordIndex].el, language: "el-GR")
                }
            }
        }
    }
    
    // ИЗМЕНЕНО: Новая функция для загрузки словарей в зависимости от источника
    func downloadAndSaveDictionariesBasedOnSource() async {
        allDictionaries = []
        selectedDictionaries = [] // Сбрасываем выбранные словари при новой загрузке
        allWords = []
        activeWords = []
        currentWordIndex = 0

        // Очищаем предыдущие скачанные словари перед новой загрузкой
        await clearDownloadedDictionaries()

        let sourceURL: String
        if dictionarySource == .standard {
            // ИЗМЕНЕНО: ИСПОЛЬЗУЕМ ВАШ НОВЫЙ URL НА REDINGER.CC ДЛЯ dictionaries.txt
            sourceURL = "https://redinger.cc/GreekQuiz/dictionaries.txt" // <--- ИЗМЕНИТЬ ЗДЕСЬ!
            print("Начинаем скачивание стандартных словарей с URL: \(sourceURL)")
        } else if dictionarySource == .customURL {
            guard !customDictionaryURL.isEmpty else {
                print("Некорректный источник словарей или пустой URL для скачивания.")
                return
            }
            sourceURL = customDictionaryURL
            print("Начинаем скачивание пользовательских словарей с URL: \(sourceURL)")
        } else {
            print("Неизвестный источник словарей.")
            return
        }

        guard let remoteDictionariesURL = URL(string: sourceURL) else {
            print("Некорректный URL для списка словарей: \(sourceURL)")
            return
        }

        var downloadedMetadata: [DictionaryInfo] = []

        do {
            let (data, response) = try await URLSession.shared.data(from: remoteDictionariesURL) // Получаем ответ для проверки HTTP Status
            
            // **ДОБАВЛЕНО: Проверка HTTP статуса и типа содержимого**
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                print("Ошибка HTTP при загрузке списка словарей: Статус \(httpResponse.statusCode)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Ответ сервера (HTML/Ошибка):\n\(responseString.prefix(500))...")
                }
                throw URLError(.badServerResponse) // Выбрасываем ошибку для дальнейшей обработки
            }

            // **ДОБАВЛЕНО: Дополнительная проверка, что данные выглядят как JSON**
            guard let responseString = String(data: data, encoding: .utf8), responseString.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("[") else {
                print("Полученные данные не похожи на JSON-массив для списка словарей. Возможно, это HTML-страница ошибки или перенаправления.")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Содержимое (не JSON):\n\(responseString.prefix(500))...")
                }
                throw URLError(.cannotDecodeContentData) // Выбрасываем ошибку
            }

            let remoteDictsInfo = try JSONDecoder().decode([DictionaryInfo].self, from: data)

            try FileManager.default.createDirectory(at: downloadedDictionariesDirectory, withIntermediateDirectories: true, attributes: nil)

            for var dictInfo in remoteDictsInfo {
                guard let remoteWordListURL = URL(string: dictInfo.filename) else {
                    print("Некорректный URL для словаря: \(dictInfo.name) - \(dictInfo.filename)")
                    continue
                }

                do {
                    let (wordListData, wordListResponse) = try await URLSession.shared.data(from: remoteWordListURL) // Получаем ответ
                    
                    // **ДОБАВЛЕНО: Проверка HTTP статуса и типа содержимого для каждого словаря**
                    if let httpResponse = wordListResponse as? HTTPURLResponse, httpResponse.statusCode != 200 {
                        print("Ошибка HTTP при загрузке словаря '\(dictInfo.name)': Статус \(httpResponse.statusCode)")
                        if let responseString = String(data: wordListData, encoding: .utf8) {
                            print("Ответ сервера (HTML/Ошибка):\n\(responseString.prefix(500))...")
                        }
                        throw URLError(.badServerResponse)
                    }

                    // **ДОБАВЛЕНО: Дополнительная проверка, что данные выглядят как JSON для каждого словаря**
                    guard let wordListContentString = String(data: wordListData, encoding: .utf8), wordListContentString.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("[") else {
                        print("Полученные данные для словаря '\(dictInfo.name)' не похожи на JSON-массив. Возможно, это HTML-страница ошибки или перенаправления.")
                        if let responseString = String(data: wordListData, encoding: .utf8) {
                            print("Содержимое (не JSON) для '\(dictInfo.name)':\n\(responseString.prefix(500))...")
                        }
                        throw URLError(.cannotDecodeContentData)
                    }

                    // **ВНИМАНИЕ: Проверьте вашу структуру Word на соответствие файлу numbers.txt**
                    // Ваш файл numbers.txt содержит поля "category" и "gender",
                    // которых нет в текущей struct Word. Это ВЫЗОВЕТ ОШИБКУ ДЕКОДИРОВАНИЯ.
                    // Я временно добавлю их в struct Word выше как опциональные.

                    let localFileName = UUID().uuidString + ".txt"
                    let localFileURL = downloadedDictionariesDirectory.appendingPathComponent(localFileName)
                    
                    try wordListData.write(to: localFileURL)
                    print("Словарь '\(dictInfo.name)' успешно скачан и сохранен как: \(localFileURL.lastPathComponent)")

                    if let fileContent = String(data: wordListData, encoding: .utf8) {
                        print("Содержимое скачанного файла '\(dictInfo.name)':\n\(fileContent.prefix(500))...")
                    } else {
                        print("Не удалось декодировать содержимое скачанного файла '\(dictInfo.name)' как UTF-8 строку.")
                    }

                    dictInfo.filename = localFileURL.lastPathComponent
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
            await MainActor.run {
                self.allDictionaries = []
                self.downloadedDictionaryMetadataData = Data()
            }
        }
    }

    // НОВАЯ ФУНКЦИЯ: Загрузка метаданных словарей (используется при запуске)
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

    // НОВАЯ ФУНКЦИЯ: Очистка скачанных словарей
    private func clearDownloadedDictionaries() async {
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

    // НОВАЯ ФУНКЦИЯ: Загрузка выбранных слов (теперь учитывает локальные пути)
    func loadSelectedWords() {
        var combinedWords: [Word] = []

        Task {
            guard FileManager.default.fileExists(atPath: downloadedDictionariesDirectory.path) else {
                print("Директория скачанных словарей не существует: \(downloadedDictionariesDirectory.path)")
                await MainActor.run {
                    self.allWords = []
                    self.activeWords = []
                }
                return
            }

            for dictInfo in allDictionaries {
                if selectedDictionaries.contains(dictInfo.filename) {
                    let filePath = downloadedDictionariesDirectory.appendingPathComponent(dictInfo.filename)
                    
                    print("Попытка загрузить локальный файл словаря: \(filePath.path)")
                    if !FileManager.default.fileExists(atPath: filePath.path) {
                        print("Ошибка: Локальный файл словаря не найден по пути: \(filePath.path)")
                        continue
                    }

                    do {
                        let data = try Data(contentsOf: filePath)
                        print("Размер данных локального файла: \(data.count) байт")

                        if let fileContent = String(data: data, encoding: .utf8) {
                            print("Содержимое локального файла '\(dictInfo.name)':\n\(fileContent.prefix(500))...")
                        } else {
                            print("Не удалось декодировать содержимое локального файла '\(dictInfo.name)' как UTF-8 строку.")
                        }

                        let decoded = try JSONDecoder().decode([Word].self, from: data)
                        combinedWords.append(contentsOf: decoded)
                        print("Словарь загружен: \(dictInfo.name) из \(filePath.lastPathComponent)")
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
                            case .valueNotFound(let type, let context):
                                print("Value not found for \(type) at key path: \(context.codingPath.map { $0.stringValue }.joined(separator: ".")) - \(context.debugDescription)")
                            @unknown default:
                                print("Unknown decoding error.")
                            }
                        }
                    }
                }
            }
            
            await MainActor.run {
                self.allWords = combinedWords
                self.activeWords = self.allWords.shuffled()
                if !self.activeWords.isEmpty {
                    self.currentWordIndex = 0
                }
                print("Загружено \(self.allWords.count) активных слов.")
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
