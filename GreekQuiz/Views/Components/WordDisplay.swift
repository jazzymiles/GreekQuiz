//
//  WordDisplay.swift
//  GreekQuiz
//
//  Created by miles on 05/08/2025.
//


import SwiftUI

struct WordDisplay: View {
    let word: Word
    let studiedLanguage: String
    let showTranscription: Bool
    let speakWord: (String, String) -> Void
    
    private func getWord(for langCode: String) -> String {
        switch langCode {
        case "ru": return word.ru
        case "el": return word.el
        case "en": return word.en ?? "N/A"
        default: return ""
        }
    }

    var body: some View {
        let questionWord = getWord(for: studiedLanguage)
        
        VStack {
            HStack(spacing: 10) {
                Text(questionWord)
                    .font(.system(size: 40, weight: .bold))

                Button(action: {
                    speakWord(questionWord, studiedLanguage)
                }) {
                    Image(systemName: "speaker.wave.3.fill")
                        .font(.title).foregroundColor(.blue)

                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.bottom, 2)

            if studiedLanguage == "el" {
                Text(showTranscription ? word.transcription : String(repeating: "*", count: word.transcription.count))
                    .font(.system(size: 18)).foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                 Text(" ").font(.system(size: 16))
            }
        }
        .padding(.bottom, 10)
    }
}
