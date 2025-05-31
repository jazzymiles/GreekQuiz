import SwiftUI

struct Word: Codable, Equatable { // Добавлено Equatable
    let ru: String
    let el: String
    let transcription: String
}

enum QuizMode: String {
    case keyboard
    case cards
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

    @AppStorage("showTranscription") private var showTranscription: Bool = true

    var body: some View {
                ZStack {
                    backgroundColor()
                        .ignoresSafeArea()

                    VStack(spacing: 0) {
                        // Новая панель управления
                        HStack(spacing: 15) { // Увеличьте spacing при необходимости
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

                            Spacer() // Чтобы кнопки словарей и транскрипции были справа

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
                                )
                            }

                            // Кнопка "Транскрипция"
                            Button(action: {
                                showTranscription.toggle() // Переключаем видимость транскрипции
                            }) {
                                Image(showTranscription ? "eye_open" : "eye_closed") // Имена ваших SVG файлов
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 30, height: 30)
                                    .padding(8)
                                    .background(Color.gray.opacity(0.3))
                                    .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.horizontal)
                        .padding(.top, 10)
                        // Удаляем старый FlowLayout
                        // FlowLayout(allDictionaries, spacing: 10) { dictionary in ... }

                        Spacer() // Возвращаем Spacer, чтобы контент был по центру

                        VStack(spacing: 0) {
                            if !activeWords.isEmpty {
                                Text(activeWords[currentWordIndex].el)
                                    .font(.system(size: 40, weight: .bold))
                                    .padding(.bottom, 8)

                                // Транскрипция (убираем старую иконку рядом)
                                HStack(spacing: 5) {
                                    Text(showTranscription ? activeWords[currentWordIndex].transcription : String(repeating: "*", count: activeWords[currentWordIndex].transcription.count))
                                        .font(.system(size: 28))
                                        .foregroundColor(.gray)
                                        .padding(.leading, 10)
                                        .frame(maxWidth: .infinity, alignment: .center) // Центрируем транскрипцию
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
                                    // Grid для кнопок-карточек
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
                                                    .foregroundColor(.white)
                                                    .cornerRadius(10)
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                        }
                                    }
                                    .padding(.horizontal)
                                    .padding(.bottom, 18) // Отступ после карточек
                                }

                                Button("Проверить") {
                                    // Логика проверки будет отличаться в зависимости от режима
                                    if quizMode == .keyboard {
                                        checkAnswer() // Используем существующую логику для клавиатуры
                                    } else { // quizMode == .cards
                                        checkCardAnswer() // Новая логика для карточек
                                    }
                                }
                                // Вот эти строки добавляют стилизацию кнопки "Проверить"
                                .padding() // Добавляет внутренние отступы
                                .frame(maxWidth: .infinity) // Растягивает кнопку на всю ширину
                                .background(Color.blue) // Фоновый цвет
                                .foregroundColor(.white) // Цвет текста
                                .cornerRadius(10) // Скругленные углы
                                .padding(.horizontal) // Горизонтальные отступы от краев экрана
                                .padding(.bottom, 20) // Отступ после кнопки "Проверить"

                                VStack(spacing: 0) {
                                    Text("Правильный перевод: \(activeWords[currentWordIndex].ru)")
                                        .foregroundColor(.white)
                                        .padding(.vertical, 9)
                                        .padding(.horizontal)
                                        .frame(maxWidth: .infinity)

                                    Button("Дальше") {
                                        showAnswer = false
                                        nextWord()
                                        // При переходе к следующему слову, если режим "Карточки",
                                        // нужно сбросить выбранный ответ и сгенерировать новые опции.
                                        if quizMode == .cards {
                                            selectedAnswer = nil
                                            generateCardOptions()
                                        }
                                    }
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                                    .padding(.top, 10)
                                }
                                .frame(height: 100)
                                .opacity(showAnswer ? 1 : 0)
                                .animation(.easeIn, value: showAnswer)

                            } else {
                                Text("Выберите хотя бы один словарь.")
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.bottom, 30)

                        Spacer()
                    }
                }
                .onAppear {
                    loadDictionaries()
                    loadSelectedWords() // Убедимся, что слова загружены при старте
                    if quizMode == .cards { // Если режим - карточки, генерируем опции
                        generateCardOptions()
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        // Фокусировка только если режим клавиатуры
                        if quizMode == .keyboard {
                            isTextFieldFocused = true
                        }
                    }
                }
                .onChange(of: userInput) { _ in
                    // Фокусировка только если режим клавиатуры
                    if quizMode == .keyboard && !isTextFieldFocused {
                        isTextFieldFocused = true
                    }
                }
                // Добавляем onChange для quizMode для сброса состояния
                .onChange(of: quizMode) { oldMode, newMode in
                    if oldMode != newMode {
                        resetQuizState()
                        if newMode == .cards {
                            generateCardOptions()
                        } else if newMode == .keyboard {
                            // Фокусировка на TextField, если перешли в режим клавиатуры
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

            if corrects.contains(input) {
                isCorrect = true
                score += 1
                UserDefaults.standard.set(score, forKey: "score")
                userInput = ""
                isShowingFeedback = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    isShowingFeedback = false
                    nextWord()
                }
            } else {
                isCorrect = false
                showAnswer = true
            }
        }

        func resetQuizState() {
            userInput = ""
            showAnswer = false
            isCorrect = false
            isShowingFeedback = false
            selectedAnswer = nil // Сброс выбранного ответа для карточек
            isTextFieldFocused = true // Фокусировка на TextField, если режим клавиатуры
            if !activeWords.isEmpty {
                currentWordIndex = Int.random(in: 0..<activeWords.count)
            }
        }

        // Новая функция для генерации вариантов ответов для режима карточек
        func generateCardOptions() {
            guard !activeWords.isEmpty else {
                cardOptions = []
                return
            }

            var options: [String] = []
            let currentCorrectAnswer = activeWords[currentWordIndex].ru

            // Добавляем правильный ответ
            options.append(parseAcceptedAnswers(from: currentCorrectAnswer).first ?? currentCorrectAnswer)

            // Генерируем 5 случайных неправильных ответов
            var shuffledAllWords = allWords.shuffled()
            var incorrectCount = 0
            while options.count < 6 && incorrectCount < allWords.count * 2 { // Ограничиваем попытки, чтобы избежать бесконечного цикла
                if let randomWord = shuffledAllWords.popLast() { // Берем слово и удаляем его из временного массива
                    let possibleIncorrectAnswer = parseAcceptedAnswers(from: randomWord.ru).first ?? randomWord.ru
                    if possibleIncorrectAnswer.lowercased() != currentCorrectAnswer.lowercased() && !options.contains(possibleIncorrectAnswer) {
                        options.append(possibleIncorrectAnswer)
                    }
                } else {
                    // Если shuffledAllWords закончился, и мы еще не набрали 6 опций,
                    // можно начать повторно использовать слова, если это приемлемо
                    // Для простоты, пока просто выйдем или добавим что-то еще.
                    break // Выходим, если слов для уникальных неправильных ответов не хватает
                }
                incorrectCount += 1
            }
            
            // Перемешиваем варианты
            cardOptions = options.shuffled()
            
            // Убедимся, что у нас всегда 6 вариантов, если это возможно
            while cardOptions.count < 6 {
                // Если не хватило уникальных неправильных ответов,
                // можно продублировать существующие или добавить заглушки.
                // В данном случае, если мало слов в словаре, просто добавим пустые строки.
                cardOptions.append("-----")
            }
        }
        
        // Новая функция для проверки ответа в режиме карточек
        func checkCardAnswer() {
            guard let selectedAnswer = selectedAnswer else {
                // Пользователь не выбрал ответ
                isShowingFeedback = true
                isCorrect = false
                showAnswer = true // Показываем правильный ответ, если пользователь ничего не выбрал
                return
            }

            let correctAnswers = parseAcceptedAnswers(from: activeWords[currentWordIndex].ru)
            
            if correctAnswers.contains(selectedAnswer.lowercased()) {
                isCorrect = true
                score += 1
                UserDefaults.standard.set(score, forKey: "score")
                isShowingFeedback = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    isShowingFeedback = false
                    nextWord() // Переходим к следующему слову
                    self.selectedAnswer = nil // Сброс выбранного ответа
                    generateCardOptions() // Генерируем новые опции
                }
            } else {
                isCorrect = false
                showAnswer = true // Показываем правильный ответ
            }
        }

        // Модифицируем nextWord, чтобы он сбрасывал selectedAnswer и генерировал cardOptions
        func nextWord() {
            userInput = ""
            showAnswer = false
            isCorrect = false
            isTextFieldFocused = true
            selectedAnswer = nil // Сброс выбранного ответа
            if !activeWords.isEmpty {
                currentWordIndex = Int.random(in: 0..<activeWords.count)
                if quizMode == .cards {
                    generateCardOptions() // Генерируем новые опции для карточек
                }
            }
        }

        func loadDictionaries() {
            guard let url = Bundle.main.url(forResource: "dictionaries", withExtension: "json"),
                  let data = try? Data(contentsOf: url),
                  let decoded = try? JSONDecoder().decode([DictionaryInfo].self, from: data) else {
                print("Не удалось загрузить dictionaries.json")
                return
            }

            allDictionaries = decoded
        }

        func loadSelectedWords() {
            var combinedWords: [Word] = []

            for filename in selectedDictionaries {
                if let url = Bundle.main.url(forResource: filename.replacingOccurrences(of: ".json", with: ""), withExtension: "json"),
                    let data = try? Data(contentsOf: url),
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
            if isShowingFeedback {
                return Color.green.opacity(0.6)
            }
            if showAnswer {
                return isCorrect ? Color.green.opacity(0.6) : Color.red.opacity(0.6)
            }
            return Color(.systemBackground)
        }

        func parseAcceptedAnswers(from raw: String) -> [String] {
            let withoutParentheses = raw.replacingOccurrences(of: "\\(.*?\\)", with: "", options: .regularExpression)
            let parts = withoutParentheses
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            return parts
        }
    }
    #Preview {
        ContentView()
    }
