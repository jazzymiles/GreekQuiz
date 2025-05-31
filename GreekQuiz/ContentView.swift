import SwiftUI
import AVFoundation
import WebKit // Импортируем WebKit для WKWebView

struct Word: Codable, Equatable {
    let ru: String
    let el: String
    let transcription: String
}

enum QuizMode: String, CaseIterable, Identifiable { // Делаем QuizMode идентифицируемым
    case keyboard
    case cards

    var id: String { self.rawValue } // Предоставляем id для ForEach
}

struct DictionaryInfo: Codable, Identifiable, Hashable {
    let id = UUID()
    let name: String
    let filename: String
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
            
    @AppStorage("currentQuizMode") private var quizMode: QuizMode = .keyboard // По умолчанию клавиатура
            
    @State private var selectedAnswer: String? = nil
            
    @State private var cardOptions: [String] = []

    @State private var showingDictionarySelection = false
    @State private var showingRules = false // Состояние для отображения правил
    @State private var showingSettings = false // НОВОЕ: Состояние для отображения настроек

    @AppStorage("showTranscription") private var showTranscription: Bool = true
    @AppStorage("autoPlaySound") private var autoPlaySound: Bool = true // По умолчанию звук включен
    // НОВОЕ СВОЙСТВО: Для управления цветовой схемой
    @AppStorage("colorSchemePreference") private var colorSchemePreference: String = "system" // "system", "light", "dark"
    
    private let synthesizer = AVSpeechSynthesizer()

    // Чтобы получить текущую системную тему для выбора иконки
    @Environment(\.colorScheme) var currentSystemColorScheme: ColorScheme

    var body: some View {
        ZStack {
            backgroundColor()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Новая панель управления
                HStack(spacing: 8) { // Уменьшено расстояние между кнопками
                    // Кнопка "Карточки"
                    Button(action: {
                        quizMode = .cards
                        resetQuizState() // Сброс состояния при смене режима
                        generateCardOptions() // Генерируем опции для карточек
                    }) {
                        Image("cards") // Имя вашего SVG файла в Assets.xcassets
                            .resizable()
                            .scaledToFit()
                            .frame(width: 30, height: 30)
                            .padding(8)
                            .background(quizMode == .cards ? Color.blue.opacity(0.7) : Color.gray.opacity(0.3))
                            .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle()) // Убираем стандартные стили кнопки

                    // Кнопка "Клавиатура"
                    Button(action: {
                        quizMode = .keyboard
                        resetQuizState() // Сброс состояния при смене режима
                    }) {
                        Image("keyboard") // Имя вашего SVG файла в Assets.xcassets
                            .resizable()
                            .scaledToFit()
                            .frame(width: 30, height: 30)
                            .padding(8)
                            .background(quizMode == .keyboard ? Color.blue.opacity(0.7) : Color.gray.opacity(0.3))
                            .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Spacer() // Чтобы кнопки словарей, темы, звука и транскрипции были справа

                    // Кнопка "Правила"
                    Button(action: {
                        showingRules = true // Показываем новый лист с правилами
                    }) {
                        Image("rules") // Имя вашего SVG файла в Assets.xcassets
                            .resizable()
                            .scaledToFit()
                            .frame(width: 30, height: 30)
                            .padding(8)
                            .background(Color.gray.opacity(0.3))
                            .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .sheet(isPresented: $showingRules) {
                        RulesSheetView(htmlFileName: "rules-el") // Используем новую обертку представления
                    }


                    // Кнопка "Словари"
                    Button(action: {
                        showingDictionarySelection = true // Показываем новый лист выбора словарей
                    }) {
                        Image("dic") // Имя вашего SVG файла в Assets.xcassets
                            .resizable()
                            .scaledToFit()
                            .frame(width: 30, height: 30)
                            .padding(8)
                            .background(Color.gray.opacity(0.3))
                            .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .sheet(isPresented: $showingDictionarySelection) {
                        // Новый View для выбора словарей
                        DictionarySelectionView(
                            allDictionaries: $allDictionaries,
                            selectedDictionaries: $selectedDictionaries,
                            loadSelectedWords: loadSelectedWords
                            // parseAcceptedAnswers: parseAcceptedAnswers // Пока не передаем, чтобы не сломать компиляцию, если DictionarySelectionView не готов
                        )
                    }

                    // НОВАЯ КНОПКА: Переключение темы (светлая/темная) - Убрана отсюда и перенесена в настройки
                    // КНОПКА: Включение/выключение автоматического произношения - Убрана отсюда и перенесена в настройки
                    // Кнопка "Транскрипция" - Убрана отсюда и перенесена в настройки

                    // НОВАЯ КНОПКА: Настройки (вместо транскрипции)
                    Button(action: {
                        showingSettings = true // Показываем экран настроек
                    }) {
                        Image("settings") // Имя вашего SVG файла в Assets.xcassets
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
                            colorSchemePreference: $colorSchemePreference
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.top, 10)

                Spacer() // Возвращаем Spacer, чтобы контент был по центру

                VStack(spacing: 0) { // Используем 0, чтобы контролировать отступы явно
                    if !activeWords.isEmpty {
                        HStack(spacing: 10) { // Отступ между словом и иконкой
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
                        .frame(maxWidth: .infinity, alignment: .center) // Центрируем весь HStack
                        .padding(.bottom, 8)

                        HStack(spacing: 5) {
                            Text(showTranscription ? activeWords[currentWordIndex].transcription : String(repeating: "*", count: activeWords[currentWordIndex].transcription.count))
                                .font(.system(size: 28))
                                .foregroundColor(.gray)
                                .padding(.leading, 10)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .padding(.bottom, 16)
                        
                        // Условное отображение режима: Keyboard или Cards
                        if quizMode == .keyboard {
                            TextField("Ваш перевод", text: $userInput)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding(.horizontal)
                                .focused($isTextFieldFocused)
                                .padding(.bottom, 18)
                        } else { // quizMode == .cards
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 10) {
                                ForEach(cardOptions, id: \.self) { option in
                                    Button(action: {
                                        selectedAnswer = option // Выбираем ответ
                                    }) {
                                        Text(option)
                                            .font(.headline)
                                            .padding()
                                            .frame(maxWidth: .infinity)
                                            .background(selectedAnswer == option ? Color.orange.opacity(0.8) : Color.gray.opacity(0.3)) // Выделяем выбранный ответ
                                            .foregroundColor(getPreferredColorScheme() == .light ? .black : .white)
                                            .cornerRadius(10)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 18)
                        }

                        // Объединенная кнопка "Проверить" / "Дальше"
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

                        // Блок с правильным переводом (используем Spacer() для фиксированного пространства)
                        Text(showAnswer ? "Правильный перевод: \(activeWords[currentWordIndex].ru)" : " ")
                            .foregroundColor(showAnswer ? (getPreferredColorScheme() == .light ? .black : .white) : .clear)
                            .padding(.vertical, 9)
                            .padding(.horizontal)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .frame(height: 55) // Фиксируем высоту
                        
                    } else {
                        Text("Выберите хотя бы один словарь.")
                            .foregroundColor(.gray)
                    }
                }
                .padding(.bottom, 30) // Оставляем этот padding для общей компоновки

                Spacer()
            }
        }
        // ПРИМЕНЯЕМ ВЫБРАННУЮ ЦВЕТОВУЮ СХЕМУ
        .preferredColorScheme(getPreferredColorScheme())
        .onAppear {
            loadDictionaries()
            loadSelectedWords()
            if quizMode == .cards {
                generateCardOptions()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                if quizMode == .keyboard {
                    isTextFieldFocused = true
                }
                // Автоматическое произношение при первом появлении слова
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
        let corrects = parseAcceptedAnswers(from: activeWords[currentWordIndex].ru) // parseAcceptedAnswers доступна здесь

        withAnimation(nil) { // ОБЕРТЫВАЕМ ИЗМЕНЕНИЯ showAnswer В withAnimation(nil)
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
        showAnswer = false // Важно сбросить showAnswer, чтобы кнопка стала "Проверить"
        isCorrect = false
        isShowingFeedback = false
        selectedAnswer = nil // Сброс выбранного ответа для карточек
        isTextFieldFocused = true // Фокусировка на TextField, если режим клавиатуры
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

        options.append(parseAcceptedAnswers(from: currentCorrectAnswer).first ?? currentCorrectAnswer) // parseAcceptedAnswers доступна здесь

        var shuffledAllWords = allWords.shuffled()
        var incorrectCount = 0
        while options.count < 6 && incorrectCount < allWords.count * 2 {
            if let randomWord = shuffledAllWords.popLast() {
                let possibleIncorrectAnswer = parseAcceptedAnswers(from: randomWord.ru).first ?? randomWord.ru // parseAcceptedAnswers доступна здесь
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
        withAnimation(nil) { // ОБЕРТЫВАЕМ ИЗМЕНЕНИЯ showAnswer В withAnimation(nil)
            if selectedAnswer == nil {
                isCorrect = false
                showAnswer = true
                print("Ошибка: Ответ не выбран. Показ правильного ответа.")
                return
            }

            let correctAnswers = parseAcceptedAnswers(from: activeWords[currentWordIndex].ru) // parseAcceptedAnswers доступна здесь
            
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
        withAnimation(nil) { // ОБЕРТЫВАЕМ ИЗМЕНЕНИЯ showAnswer В withAnimation(nil)
            userInput = ""
            showAnswer = false // Сбрасываем showAnswer, чтобы кнопка снова стала "Проверить"
            isCorrect = false
            isTextFieldFocused = true
            selectedAnswer = nil
            if !activeWords.isEmpty {
                currentWordIndex = Int.random(in: 0..<activeWords.count)
                if quizMode == .cards {
                    generateCardOptions()
                }
                // Автоматическое произношение при переходе к следующему слову
                if autoPlaySound {
                    speakWord(activeWords[currentWordIndex].el, language: "el-GR")
                }
            }
        }
    }

    func loadDictionaries() {
        guard let url = Bundle.main.url(forResource: "dictionaries", withExtension: "txt"), // ИЗМЕНЕНО: .json на .txt
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([DictionaryInfo].self, from: data) else {
            print("Не удалось загрузить dictionaries.txt")
            return
        }

        allDictionaries = decoded
    }

    func loadSelectedWords() {
        var combinedWords: [Word] = []

        for filename in selectedDictionaries {
            // ИЗМЕНЕНО: .json на .txt
            if let url = Bundle.main.url(forResource: filename.replacingOccurrences(of: ".txt", with: ""), withExtension: "txt"),
                let data = try? Data(Data(contentsOf: url)),
                let decoded = try? JSONDecoder().decode([Word].self, from: data) {
                combinedWords.append(contentsOf: decoded)
            }
        }

        allWords = combinedWords
        activeWords = allWords.shuffled()

        if !activeWords.isEmpty {
            currentWordIndex = 0
        }
    }

    func backgroundColor() -> Color {
        // Убрал environment(\.colorScheme) отсюда, так как currentSystemColorScheme уже свойство View
        
        if isShowingFeedback {
            return Color.green.opacity(0.6)
        }
        if showAnswer {
            return isCorrect ? Color.green.opacity(0.6) : Color.red.opacity(0.6)
        }
        
        // Если предпочтение "dark", возвращаем темно-серый, иначе системный фон
        if colorSchemePreference == "dark" { // Проверяем именно выбранное предпочтение
            return Color(red: 0.15, green: 0.15, blue: 0.15) // Темно-серый цвет
        } else if colorSchemePreference == "light" {
            return Color(.systemBackground) // Для принудительно светлой темы
        } else { // "system" или по умолчанию
            return Color(.systemBackground) // Используем системный фон
        }
    }

    // Вспомогательная функция для выбора иконки темы
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
    
    // Вспомогательная функция для получения ColorScheme для preferredColorScheme
    func getPreferredColorScheme() -> ColorScheme? {
        switch colorSchemePreference {
        case "light":
            return .light
        case "dark":
            return .dark
        case "system":
            return nil // nil означает использование системных настроек
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
