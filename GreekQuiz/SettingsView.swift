// SettingsView.swift
import SwiftUI

// enum DictionarySource теперь объявлен в ContentView.swift и доступен глобально

struct SettingsView: View {
    @Binding var showTranscription: Bool
    @Binding var autoPlaySound: Bool
    @Binding var colorSchemePreference: String
    @Binding var dictionarySource: DictionarySource
    @Binding var customDictionaryURL: String
    @Binding var quizLanguage: String // NEW: Binding for quiz language
    @Environment(\.dismiss) var dismiss

    // Callback для уведомления ContentView о необходимости загрузки словарей
    var onDownloadDictionaries: () -> Void

    @Environment(\.colorScheme) var currentSystemColorScheme: ColorScheme

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

                // NEW: Section for Quiz Language
                Section(header: Text("Язык квиза")) {
                    Picker("Отвечать на языке", selection: $quizLanguage) {
                        Text("Русский").tag("ru")
                        Text("Греческий").tag("el")
                    }
                    .pickerStyle(.segmented)
                }

                Section(header: Text("Настройки внешнего вида")) {
                    Picker("Тема приложения", selection: $colorSchemePreference) {
                        Text("Системная").tag("system")
                        Text("Светлая").tag("light")
                        Text("Темная").tag("dark")
                    }
                    .pickerStyle(.segmented)
                }

                // Раздел: Словари
                Section(header: Text("Словари")) {
                    Picker("Источник словарей", selection: $dictionarySource) {
                        ForEach(DictionarySource.allCases) { source in
                            Text(source.displayName).tag(source)
                        }
                    }
                    .pickerStyle(.segmented)

                    if dictionarySource == .customURL {
                        TextField("Введите адрес файла dictionaries.txt", text: $customDictionaryURL)
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }

                    Button("Скачать и сохранить словари") {
                        // Этот callback будет запускать соответствующую функцию загрузки в ContentView
                        onDownloadDictionaries()
                        // dismiss() // Можно раскомментировать, если хотите, чтобы лист закрывался сразу
                    }
                    .disabled(dictionarySource == .customURL && customDictionaryURL.isEmpty)
                    .tint(.blue)
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
