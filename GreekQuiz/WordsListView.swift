import SwiftUI
import AVFoundation

struct WordsListView: View {
    let words: [Word] // Это массив всех слов, которые могут быть показаны (allWords или activeWords из ContentView)
    let speakWord: (String, String) -> Void

    @Environment(\.dismiss) var dismiss
    @State private var searchQuery: String = "" // Состояние для текста поиска

    var filteredWords: [Word] {
        if searchQuery.isEmpty {
            return words // Если поиск пуст, показываем все слова
        } else {
            return words.filter { word in
                // Поиск по греческому слову, русскому переводу или транскрипции
                word.el.localizedCaseInsensitiveContains(searchQuery) ||
                word.ru.localizedCaseInsensitiveContains(searchQuery) ||
                word.transcription.localizedCaseInsensitiveContains(searchQuery)
            }
        }
    }

    var body: some View {
        NavigationView {
            VStack {
                HStack {
                    TextField("Поиск...", text: $searchQuery)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .padding(.horizontal, 8) // Отступы для поля поиска
                    
                    if !searchQuery.isEmpty {
                        Button(action: {
                            searchQuery = "" // Очистить поле поиска
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                                .padding(.trailing, 8)
                        }
                    }
                }
                .padding(.top, 8)

                List {
                    ForEach(filteredWords, id: \.el) { word in
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
