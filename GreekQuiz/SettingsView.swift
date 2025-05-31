// SettingsView.swift
import SwiftUI

struct SettingsView: View {
    @Binding var showTranscription: Bool
    @Binding var autoPlaySound: Bool
    @Binding var colorSchemePreference: String // "system", "light", "dark"
    @Environment(\.dismiss) var dismiss // Для закрытия листа

    @Environment(\.colorScheme) var currentSystemColorScheme: ColorScheme // Чтобы отображать текущую системную тему

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Настройки обучения")) {
                    Toggle(isOn: $showTranscription) {
                        Text("Показывать транскрипцию")
                    }
                    Toggle(isOn: $autoPlaySound) {
                        Text("Автоматически озвучивать слова")
                    }
                }

                Section(header: Text("Настройки внешнего вида")) {
                    Picker("Тема приложения", selection: $colorSchemePreference) {
                        Text("Системная").tag("system")
                        Text("Светлая").tag("light")
                        Text("Темная").tag("dark")
                    }
                    .pickerStyle(.segmented) // Или .menu
                }
            }
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") {
                        dismiss() // Закрываем лист настроек
                    }
                }
            }
        }
    }
}
