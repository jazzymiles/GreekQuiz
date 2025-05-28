import SwiftUI

struct Word: Codable {
    let ru: String
    let el: String
    let transcription: String
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

    var body: some View {
        ZStack {
            backgroundColor()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    HStack {
                        Text("Баллы: \(score)")
                            .font(.headline)
                        Spacer()
                        Text("Слово \(currentWordIndex + 1)/\(activeWords.count)")
                            .font(.subheadline)
                    }
                    .padding(.horizontal)
                    .padding(.top, 0)
                    let _ = print("------------")
                    
                    FlowLayout(allDictionaries, spacing: 10) { dictionary in
                        Toggle(dictionary.name, isOn: Binding(
                            get: { selectedDictionaries.contains(dictionary.filename) },
                            set: { isSelected in
                                if isSelected {
                                    selectedDictionaries.insert(dictionary.filename)
                                } else {
                                    selectedDictionaries.remove(dictionary.filename)
                                }
                                loadSelectedWords()
                            }
                        ))
                        .toggleStyle(.button)
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, 10)
                    let _ = print("------------")

                }

                Spacer()

                VStack(spacing: 0) { // Используем 0, чтобы контролировать отступы явно
                    if !activeWords.isEmpty {
                        Text(activeWords[currentWordIndex].el)
                            .font(.system(size: 40, weight: .bold))
                            .padding(.bottom, 8) // Добавляем небольшой отступ снизу

                        Text(activeWords[currentWordIndex].transcription)
                            .font(.system(size: 28))
                            .foregroundColor(.gray)
                            .padding(.bottom, 16) // Отступ до TextField

                        TextField("Ваш перевод", text: $userInput)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding(.horizontal)
                            .focused($isTextFieldFocused)
                            .padding(.bottom, 18) // Отступ после TextField

                        Button("Проверить") {
                            checkAnswer()
                        }
                        .padding(.bottom, 20) // Отступ после кнопки "Проверить"

                        // Этот VStack будет содержать элементы, которые появляются/исчезают
                        // Мы зададим ему фиксированную высоту, чтобы основной макет не прыгал
                        VStack(spacing: 0) {
                            Text("Правильный перевод: \(activeWords[currentWordIndex].ru)")
                                .foregroundColor(.white)
                                .padding(.vertical, 9) // Вертикальный отступ текста
                                .padding(.horizontal)
                                .frame(maxWidth: .infinity) // Чтобы текст занимал всю ширину для стабильности

                            Button("Дальше") {
                                showAnswer = false
                                nextWord()
                            }
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .padding(.top, 10) // Отступ сверху для кнопки "Дальше"
                        }
                        // Задаем фиксированную высоту для этого блока, чтобы он не прыгал
                        // Это значение нужно будет подобрать опытным путем, чтобы оно было достаточным
                        // для отображения текста и кнопки "Дальше" со всеми отступами.
                        // Пример: (высота текста + padding) + (высота кнопки + padding)
                        .frame(height: 100) // Adjust this value based on actual content height
                        .opacity(showAnswer ? 1 : 0) // Делаем невидимым, но сохраняем место
                        .animation(.easeIn, value: showAnswer) // Добавляем анимацию для плавности

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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                isTextFieldFocused = true
            }
        }
        .onChange(of: userInput) { _ in
            if !isTextFieldFocused {
                isTextFieldFocused = true
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

    func nextWord() {
        userInput = ""
        showAnswer = false
        isCorrect = false
        if !activeWords.isEmpty {
            currentWordIndex = Int.random(in: 0..<activeWords.count)
        }
        isTextFieldFocused = true
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
