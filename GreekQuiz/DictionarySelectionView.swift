import SwiftUI
import AVFoundation

struct DictionarySelectionView: View {
    // ✨ ИЗМЕНЕНИЕ №1: Используем @ObservedObject для всего сервиса
    @ObservedObject var dictionaryService: DictionaryService
    
    let speakWord: (String, String) -> Void
    let interfaceLanguage: String

    @Environment(\.dismiss) var dismiss
    @State private var showingWordsList = false

    var body: some View {
        NavigationView {
            VStack {
                Text("title_select_dictionaries")
                    .font(.largeTitle)
                    .padding(.bottom, 20)

                // ✨ ИЗМЕНЕНИЕ №2: Используем `dictionaryService.allDictionaries`
                FlowLayout(dictionaryService.allDictionaries, spacing: 10) { dictionary in
                    // ✨ ИЗМЕНЕНИЕ №3: Привязка теперь к `dictionaryService.selectedDictionaries`
                    Toggle(dictionary.localizedName(for: interfaceLanguage), isOn: Binding(
                        get: { dictionaryService.selectedDictionaries.contains(dictionary.filePath) },
                        set: { isSelected in
                            if isSelected {
                                dictionaryService.selectedDictionaries.insert(dictionary.filePath)
                            } else {
                                dictionaryService.selectedDictionaries.remove(dictionary.filePath)
                            }
                            // ✨ ИЗМЕНЕНИЕ №4: Явно вызываем загрузку слов с нужным языком
                            dictionaryService.loadSelectedWords(interfaceLanguage: interfaceLanguage)
                        }
                    ))
                    .toggleStyle(.button)
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                
                Spacer()

                Button("button_show_words") {
                    showingWordsList = true
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.bottom, 20)
                .sheet(isPresented: $showingWordsList) {
                    // ✨ ИЗМЕНЕНИЕ №5: Передаем слова из `dictionaryService`
                    WordsListView(words: dictionaryService.activeWords.isEmpty ? dictionaryService.allWords : dictionaryService.activeWords, speakWord: speakWord)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("button_done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
