//
//  KeyboardQuizView.swift
//  GreekQuiz
//
//  Created by miles on 05/08/2025.
//


import SwiftUI

struct KeyboardQuizView: View {
    // MARK: - Properties
    
    // Данные, которые View получает от родителя
    let word: Word
    let answerWord: String
    let studiedLanguage: String
    let showTranscription: Bool
    let speakWord: (String, String) -> Void
    
    // Привязки к состоянию родителя
    @Binding var userInput: String
    @Binding var showAnswer: Bool
    @FocusState.Binding var isTextFieldFocused: Bool

    // Функции для выполнения действий
    let onCheckAnswer: () -> Void
    let onNextWord: () -> Void
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 5) {
                WordDisplay(
                    word: word,
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
            .padding(.top, 40)
            
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
            .padding(.bottom, 80)
            
            Spacer()
        }
        .padding(.horizontal)
    }
    
    // MARK: - Private Helpers
    
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
    
    // Эта переменная нужна для `exampleSentencesView`
    private var answerLanguage: String {
        return studiedLanguage == "ru" ? "el" : "ru"
    }
}
