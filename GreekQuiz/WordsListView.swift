//
//  WordsListView.swift
//  GreekQuiz
//
//  Created by miles on 08/06/2025.
//


import SwiftUI
import AVFoundation // Необходимо для воспроизведения звука

struct WordsListView: View {
    let words: [Word]
    let speakWord: (String, String) -> Void // Функция для воспроизведения звука

    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            List {
                ForEach(words, id: \.el) { word in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(word.el)
                                .font(.headline)
                            Text(word.ru)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            Text(word.transcription)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button(action: {
                            speakWord(word.el, "el-GR")
                        }) {
                            Image(systemName: "speaker.wave.3.fill")
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Слова")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Закрыть") {
                        dismiss()
                    }
                }
            }
        }
    }
}
