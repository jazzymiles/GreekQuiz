//
//  TalkShowView.swift
//  GreekQuiz
//
//  Created by miles on 05/08/2025.
//


import SwiftUI

struct TalkShowView: View {
    // MARK: - Properties
    
    // Данные, которые View получает от родителя
    let questionWord: String
    let answerWord: String
    
    // Привязка к состоянию, чтобы кнопка Play/Pause обновлялась
    @Binding var isPlaying: Bool
    
    // Функции (замыкания), которые будут вызываться при нажатии на кнопки
    let onTogglePlayPause: () -> Void
    let onSkipToPrevious: () -> Void
    let onSkipToNext: () -> Void

    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Text(questionWord)
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Text(answerWord)
                .font(.title2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()

            HStack(spacing: 40) {
                Button(action: onSkipToPrevious) {
                    Image(systemName: "backward.fill")
                }
                
                Button(action: onTogglePlayPause) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .frame(width: 44, height: 44)
                }
                
                Button(action: onSkipToNext) {
                    Image(systemName: "forward.fill")
                }
            }
            .font(.system(size: 44))
            .foregroundColor(.blue)
            .padding(.bottom, 40)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct TalkShowView_Previews: PreviewProvider {
    static var previews: some View {
        // Пример для предпросмотра с тестовыми данными
        TalkShowView(
            questionWord: "μπροστά",
            answerWord: "впереди",
            isPlaying: .constant(true), // .constant позволяет использовать значение без реального @State
            onTogglePlayPause: { print("Toggle Play/Pause tapped") },
            onSkipToPrevious: { print("Previous tapped") },
            onSkipToNext: { print("Next tapped") }
        )
    }
}
#endif
