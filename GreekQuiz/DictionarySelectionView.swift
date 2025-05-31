import SwiftUI

struct DictionarySelectionView: View {
    @Binding var allDictionaries: [DictionaryInfo]
    @Binding var selectedDictionaries: Set<String>
    let loadSelectedWords: () -> Void // Функция обратного вызова для загрузки слов

    @Environment(\.dismiss) var dismiss // Для закрытия листа

    var body: some View {
        NavigationView {
            VStack {
                Text("Выберите словари")
                    .font(.largeTitle)
                    .padding(.bottom, 20)

                // Использование FlowLayout для выбора словарей
                FlowLayout(allDictionaries, spacing: 10) { dictionary in
                    Toggle(dictionary.name, isOn: Binding(
                        get: { selectedDictionaries.contains(dictionary.filename) },
                        set: { isSelected in
                            if isSelected {
                                selectedDictionaries.insert(dictionary.filename)
                            } else {
                                selectedDictionaries.remove(dictionary.filename)
                            }
                            loadSelectedWords() // Вызываем функцию из ContentView
                        }
                    ))
                    .toggleStyle(.button)
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                
                Spacer()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Готово") {
                        dismiss() // Закрываем лист
                    }
                }
            }
        }
    }
}
