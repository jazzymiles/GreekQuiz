import SwiftUI
import AVFoundation

struct DictionarySelectionView: View {
    @Binding var allDictionaries: [DictionaryInfo]
    @Binding var selectedDictionaries: Set<String>
    let loadSelectedWords: () -> Void
    @Binding var allWords: [Word]
    @Binding var activeWords: [Word]
    let speakWord: (String, String) -> Void
    
    // ✨ ИЗМЕНЕНИЕ №5: Добавляем свойство для языка ✨
    let interfaceLanguage: String

    @Environment(\.dismiss) var dismiss
    @State private var showingWordsList = false

    var body: some View {
        NavigationView {
            VStack {
                Text("title_select_dictionaries")
                    .font(.largeTitle)
                    .padding(.bottom, 20)

                FlowLayout(allDictionaries, spacing: 10) { dictionary in
                    // ✨ ИЗМЕНЕНИЕ №6: Используем новый метод для получения имени ✨
                    Toggle(dictionary.localizedName(for: interfaceLanguage), isOn: Binding(
                        get: { selectedDictionaries.contains(dictionary.filePath) },
                        set: { isSelected in
                            if isSelected {
                                selectedDictionaries.insert(dictionary.filePath)
                            } else {
                                selectedDictionaries.remove(dictionary.filePath)
                            }
                            loadSelectedWords()
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
                    WordsListView(words: activeWords.isEmpty ? allWords : activeWords, speakWord: speakWord)
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
