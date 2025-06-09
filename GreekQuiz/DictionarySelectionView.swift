import SwiftUI
import AVFoundation

struct DictionarySelectionView: View {
    @Binding var allDictionaries: [DictionaryInfo]
    @Binding var selectedDictionaries: Set<String>
    let loadSelectedWords: () -> Void
    @Binding var allWords: [Word]
    @Binding var activeWords: [Word]
    let speakWord: (String, String) -> Void

    @Environment(\.dismiss) var dismiss
    @State private var showingWordsList = false

    var body: some View {
        NavigationView {
            VStack {
                Text("Выберите словари")
                    .font(.largeTitle)
                    .padding(.bottom, 20)

                FlowLayout(allDictionaries, spacing: 10) { dictionary in
                    Toggle(dictionary.name, isOn: Binding(
                        get: { selectedDictionaries.contains(dictionary.filePath) }, // Changed .filename to .filePath
                        set: { isSelected in
                            if isSelected {
                                selectedDictionaries.insert(dictionary.filePath) // Changed .filename to .filePath
                            } else {
                                selectedDictionaries.remove(dictionary.filePath) // Changed .filename to .filePath
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

                Button("Показать слова") {
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
                    Button("Готово") {
                        dismiss()
                    }
                }
            }
        }
    }
}
