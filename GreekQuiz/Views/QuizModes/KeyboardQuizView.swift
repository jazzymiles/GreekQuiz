import SwiftUI

struct KeyboardQuizView: View {
    // MARK: - Properties
    
    let word: Word
    let questionWord: String
    let answerWord: String
    let studiedLanguage: String
    let showTranscription: Bool
    let speakWord: (String, String) -> Void
    
    @Binding var userInput: String
    @Binding var showAnswer: Bool
    @FocusState.Binding var isTextFieldFocused: Bool

    let onCheckAnswer: () -> Void
    let onNextWord: () -> Void
    
    
    var body: some View {
        // ✨ ИЗМЕНЕНИЕ: Вся структура VStack была исправлена
        VStack(spacing: 0) {
            // --- Верхний блок ---
            VStack(spacing: 5) {
                WordDisplay(
                    word: word,
                    questionWord: questionWord,
                    studiedLanguage: studiedLanguage,
                    showTranscription: showTranscription,
                    speakWord: speakWord
                )
                
                FeedbackText(
                    key: "correct_answer_text",
                    word: answerWord,
                    isVisible: showAnswer
                )
                
                exampleSentencesView(for: word, isVisible: showAnswer)
            }
            .padding(.top, 40) // Отступ сверху до слова
            
            Spacer(minLength: 20) // Гибкая распорка МЕЖДУ блоками

            // --- Нижний блок ---
            VStack (spacing: 5){
                TextField("your_translation_placeholder", text: $userInput)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                    .focused($isTextFieldFocused)

                ActionButton(title: showAnswer ? "button_next" : "button_check") {
                    if showAnswer {
                        onNextWord()
                    } else {
                        onCheckAnswer()
                    }
                }
                .padding(.top, 20)
            }
            .padding(.bottom, 340) // Отступ снизу от кнопок
        }
        .padding(.horizontal)
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
    
    private var answerLanguage: String {
        return studiedLanguage == "ru" ? "el" : "ru"
    }
}
