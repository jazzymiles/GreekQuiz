import SwiftUI

struct MultipleChoiceQuizView: View {
    
    let word: Word
    let questionWord: String // ✨ ДОБАВЛЕНО
    let options: [String]
    let studiedLanguage: String
    let answerLanguage: String
    let showTranscription: Bool
    let speakWord: (String, String) -> Void
    
    @Binding var selectedAnswer: String?
    @Binding var showAnswer: Bool
    
    let onSelectAnswer: (String) -> Void
    let onCheckAnswer: () -> Void
    let onNextWord: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 15) {
                WordDisplay(
                    word: word,
                    questionWord: questionWord, // ✨ ДОБАВЛЕНО
                    studiedLanguage: studiedLanguage,
                    showTranscription: showTranscription,
                    speakWord: speakWord
                )
                
                FeedbackText(
                    key: "correct_answer_text",
                    word: getWord(for: answerLanguage),
                    isVisible: showAnswer
                )
                
                exampleSentencesView(for: word, isVisible: showAnswer)
            }
            .padding(.top, 40)
            
            VStack {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 10) {
                    ForEach(options, id: \.self) { option in
                        Button(action: {
                            onSelectAnswer(option)
                        }) {
                            Text(option)
                                .font(.headline)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(selectedAnswer == option ? Color.orange.opacity(0.8) : Color.gray.opacity(0.3))
                                .foregroundColor(.primary)
                                .cornerRadius(10)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal)

                ActionButton(title: showAnswer ? "button_next" : "button_check") {
                    if showAnswer {
                        onNextWord()
                    } else {
                        onCheckAnswer()
                    }
                }
            }
            .padding(.top, 20)
            .padding(.bottom, 20)
            
            Spacer()
        }
        .padding(.horizontal)
    }
    
    // MARK: - Private Helpers
    
    private func getWord(for langCode: String) -> String {
        switch langCode {
        case "ru": return word.ru
        case "el": return word.el
        case "en": return word.en ?? "N/A"
        default: return ""
        }
    }

    private func exampleSentencesView(for word: Word, isVisible: Bool) -> some View {
        func getExample(for langCode: String) -> String? {
            switch langCode {
            case "ru": return word.ru_example
            case "el": return word.el_example
            case "en": return word.en_example
            default: return nil
            }
        }

        let studiedExample = getExample(for: studiedLanguage)
        let answerExample = getExample(for: answerLanguage)
        let hasContent = studiedExample != nil || answerExample != nil
        
        return VStack(alignment: .center, spacing: 5) {
            Text(studiedExample ?? " ")
                .font(.callout)
                .italic()
                .multilineTextAlignment(.center)
            
            Text(answerExample ?? " ")
                .font(.callout)
                .italic()
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(minHeight: 40)
        .padding(.vertical, 10)
        .padding(.horizontal)
        .opacity(isVisible && hasContent ? 1.0 : 0.0)
        .animation(.easeInOut(duration: 0), value: isVisible && hasContent)
    }
}
