//
//  CardView.swift
//  GreekQuiz
//
//  Created by miles on 05/08/2025.
//


import SwiftUI

struct CardView: View {
    let word: Word
    let studiedLanguage: String
    let answerLanguage: String
    let showTranscription: Bool
    let speakWord: (String, String) -> Void
    @Binding var showTranslation: Bool

    private func getWord(for langCode: String) -> String {
        switch langCode {
        case "ru": return word.ru
        case "el": return word.el
        case "en": return word.en ?? "N/A"
        default: return ""
        }
    }
    
    private func getExample(for langCode: String) -> String? {
        switch langCode {
        case "ru": return word.ru_example
        case "el": return word.el_example
        case "en": return word.en_example
        default: return nil
        }
    }

    var body: some View {
        let questionWord = getWord(for: studiedLanguage)
        let answerWord = getWord(for: answerLanguage)
        let studiedExample = getExample(for: studiedLanguage)
        let answerExample = getExample(for: answerLanguage)
        
        VStack {
            Spacer()

            Text(questionWord)
                .font(.system(size: 40, weight: .bold))
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            if studiedLanguage == "el" {
                Text(showTranscription ? word.transcription : String(repeating: "*", count: word.transcription.count))
                    .font(.system(size: 28))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button(action: {
                speakWord(questionWord, studiedLanguage)
            }) {
                Image(systemName: "speaker.wave.3.fill")
                    .font(.title)
                    .foregroundColor(.blue)
            }
            .padding(.top, 10)

            Spacer()

            if showTranslation {
                VStack(spacing: 15) {
                    Text(answerWord)
                        .font(.system(size: 32))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    if studiedExample != nil || answerExample != nil {
                        VStack(alignment: .center, spacing: 5) {
                            if let example = studiedExample {
                                Text(example)
                                    .font(.footnote)
                                    .italic()
                            }
                            if let example = answerExample {
                                Text(example)
                                    .font(.footnote)
                                    .italic()
                                    .foregroundColor(.secondary)
                            }
                        }
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    }
                }
                .transition(.opacity)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.opacity(0.1))
        .cornerRadius(20)
        .padding()
        .onTapGesture {
            withAnimation {
                showTranslation.toggle()
            }
        }
    }
}
