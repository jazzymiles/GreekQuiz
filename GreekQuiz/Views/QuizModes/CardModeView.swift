//
//  CardModeView.swift
//  GreekQuiz
//
//  Created by miles on 05/08/2025.
//


import SwiftUI

struct CardModeView: View {
    // MARK: - Properties
    
    let word: Word
    let studiedLanguage: String
    let answerLanguage: String
    let showTranscription: Bool
    let speakWord: (String, String) -> Void
    
    @Binding var showCardTranslation: Bool
    
    let onNextWord: () -> Void
    let onPreviousWord: () -> Void

    // MARK: - Body
    
    var body: some View {
        VStack {
            CardView(
                word: word,
                studiedLanguage: studiedLanguage,
                answerLanguage: answerLanguage,
                showTranscription: showTranscription,
                speakWord: speakWord,
                showTranslation: $showCardTranslation
            )
            .gesture(
                DragGesture().onEnded { gesture in
                    if gesture.translation.width < -50 {
                        onNextWord()
                    } else if gesture.translation.width > 50 {
                        onPreviousWord()
                    }
                }
            )
            
            Spacer()

            HStack {
                NavButton(systemName: "arrow.left.circle.fill", action: onPreviousWord)
                Spacer()
                NavButton(systemName: "arrow.right.circle.fill", action: onNextWord)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 20)
        }
    }
}
