import SwiftUI
import AVFoundation

struct WordsListView: View {
    let words: [Word] // Это массив всех слов
    let speakWord: (String, String) -> Void

    @Environment(\.dismiss) var dismiss
    @State private var searchQuery: String = ""

    // NEW: Grouped words by dictionary name
    var groupedFilteredWords: [String: [Word]] {
        let filtered = filteredWords // Use already filtered words
        return Dictionary(grouping: filtered, by: { $0.dictionaryName ?? "Без словаря" })
    }

    // NEW: Sorted dictionary names for consistent order
    var sortedDictionaryNames: [String] {
        groupedFilteredWords.keys.sorted()
    }

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
                                ForEach(sortedDictionaryNames, id: \.self) { dictionaryName in
                                    Section(header: Text(dictionaryName).font(.title2).bold()) { // Header for dictionary name
                                        if let wordsInDictionary = groupedFilteredWords[dictionaryName] {
                                            ForEach(wordsInDictionary, id: \.id) { word in // Use .id now
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
                                                .padding(.vertical, 2)
                                            }
                                        }
                                    }
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
