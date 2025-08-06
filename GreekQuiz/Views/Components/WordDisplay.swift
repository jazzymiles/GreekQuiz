import SwiftUI

struct WordDisplay: View {
    let word: Word
    let questionWord: String 
    let studiedLanguage: String
    let showTranscription: Bool
    let speakWord: (String, String) -> Void

    var body: some View {
        VStack {
            HStack(spacing: 10) {
                Text(questionWord) //
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
