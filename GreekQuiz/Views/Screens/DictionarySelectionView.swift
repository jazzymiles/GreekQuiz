import SwiftUI
import AVFoundation

struct DictionarySelectionView: View {
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

                FlowLayout(dictionaryService.allDictionaries, spacing: 2) { dictionary in
                    Toggle(dictionary.localizedName(for: interfaceLanguage), isOn: Binding(
                        get: { dictionaryService.selectedDictionaries.contains(dictionary.filePath) },
                        set: { isSelected in
                            if isSelected {
                                dictionaryService.selectedDictionaries.insert(dictionary.filePath)
                            } else {
                                dictionaryService.selectedDictionaries.remove(dictionary.filePath)
                            }
                            dictionaryService.loadSelectedWords(interfaceLanguage: interfaceLanguage)
                        }
                    ))
                    .toggleStyle(.button)
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

                .id(interfaceLanguage)
                
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
