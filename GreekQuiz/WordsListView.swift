import SwiftUI
import AVFoundation

struct WordsListView: View {
    let words: [Word] // Это массив всех слов
    let speakWord: (String, String) -> Void

    @Environment(\.dismiss) var dismiss
    @State private var searchQuery: String = ""

    var groupedFilteredWords: [String: [Word]] {
        let filtered = filteredWords
        return Dictionary(grouping: filtered, by: { $0.dictionaryName ?? "Без словаря" })
    }
    
    var sortedDictionaryNames: [String] {
        groupedFilteredWords.keys.sorted()
    }

    var filteredWords: [Word] {
        if searchQuery.isEmpty {
            return words
        } else {
            return words.filter { word in
                // Поиск по греческому, русскому, английскому слову или транскрипции
                word.el.localizedCaseInsensitiveContains(searchQuery) ||
                word.ru.localizedCaseInsensitiveContains(searchQuery) ||
                (word.en ?? "").localizedCaseInsensitiveContains(searchQuery) ||
                word.transcription.localizedCaseInsensitiveContains(searchQuery)
            }
        }
    }

    var body: some View {
        NavigationView {
            VStack {
                HStack {
                    TextField("palce_holder_search", text: $searchQuery)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .padding(.horizontal, 8)
                    
                    if !searchQuery.isEmpty {
                        Button(action: {
                            searchQuery = ""
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
                        Section(header: Text(dictionaryName).font(.title2).bold()) {
                            if let wordsInDictionary = groupedFilteredWords[dictionaryName] {
                                ForEach(wordsInDictionary, id: \.id) { word in
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(word.el)
                                                .font(.headline)
                                            Text(word.ru)
                                                .font(.subheadline)
                                                .foregroundColor(.gray)
                                            // ✨ ИЗМЕНЕНИЕ: Вместо транскрипции выводим английский перевод.
                                            // Используем `?? ""` на случай, если перевод отсутствует.
                                            Text(word.en ?? "")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        Button(action: {
                                            speakWord(word.el, "el")
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
            .navigationTitle("words_list_title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("button_close") {
                        dismiss()
                    }
                }
            }
        }
    }
}
