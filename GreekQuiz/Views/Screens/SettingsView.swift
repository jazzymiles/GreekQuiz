import SwiftUI

struct SettingsView: View {
    @Binding var showTranscription: Bool
    @Binding var autoPlaySound: Bool
    @Binding var playAnswerSound: Bool
    @Binding var useAllWordsInQuiz: Bool
    @Binding var showArticle: Bool

    @Binding var colorSchemePreference: String
    @Binding var dictionarySource: DictionarySource
    @Binding var customDictionaryURL: String
    
    @Binding var studiedLanguage: String
    @Binding var answerLanguage: String

    @Environment(\.dismiss) var dismiss
    
    @Binding var interfaceLanguage: String

    var onDownloadDictionaries: () -> Void

    @Environment(\.colorScheme) var currentSystemColorScheme: ColorScheme

    // ✨ ИЗМЕНЕНИЕ №1: Добавляем вспомогательную функцию для определения темы
    private func getPreferredColorScheme() -> ColorScheme? {
        switch colorSchemePreference {
        case "light": return .light
        case "dark": return .dark
        default: return nil // для "system"
        }
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("title_settings_navigation")) {
                    Toggle(isOn: $showTranscription) {
                        Text("show_transcription_toggle")
                    }
                    Toggle(isOn: $autoPlaySound) {
                        Text("autoplay_sound_toggle")
                    }
                    Toggle(isOn: $playAnswerSound) {
                        Text("answers_sounds_toggle")
                    }
                    Toggle(isOn: $showArticle) {
                        Text("show_article_toggle")
                    }
                    Toggle(isOn: $useAllWordsInQuiz) {
                        Text("use_all_words_toggle")
                    }
                }

                Section(header: Text("language_settings_section")) {
                    Text("studied_language_picker")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Picker("studied_language_picker", selection: $studiedLanguage) {
                        Text("greek_language").tag("el")
                        Text("russian_language").tag("ru")
                        Text("english_language").tag("en")
                    }
                    .pickerStyle(.segmented)

                    Text("answer_language_picker")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.top)

                    Picker("answer_language_picker", selection: $answerLanguage) {
                        Text("russian_language").tag("ru")
                        Text("greek_language").tag("el")
                        Text("english_language").tag("en")
                    }
                    .pickerStyle(.segmented)
                    
                    Text("interface_language_picker") // Используем ключ для подписи
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.top)
                    
                    Picker("interface_language_section", selection: $interfaceLanguage) {
                        Text("language_option_russian").tag("ru")
                        Text("language_option_english").tag("en")
                        Text("language_option_greek").tag("el")
                    }
                    .pickerStyle(.segmented)
                }

                Section(header: Text("appearance_settings_section")) {
                    Picker("theme_app", selection: $colorSchemePreference) {
                        Text("theme_system").tag("system")
                        Text("theme_light").tag("light")
                        Text("theme_dark").tag("dark")
                    }
                    .pickerStyle(.segmented)
                }

                Section(header: Text("dictionaries_section")) {
                    Picker("dictionary_source", selection: $dictionarySource) {
                        ForEach(DictionarySource.allCases) { source in
                            Text(source.displayName).tag(source)
                        }
                    }
                    .pickerStyle(.segmented)

                    if dictionarySource == .customURL {
                        TextField("enter_dictionaries_file_address", text: $customDictionaryURL)
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }

                    Button("download_and_save_dictionaries") {
                        onDownloadDictionaries()
                    }
                    .disabled(dictionarySource == .customURL && customDictionaryURL.isEmpty)
                    .tint(.blue)
                }
            }
            .navigationTitle("title_settings_navigation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("button_done") {
                        dismiss()
                    }
                }
            }
        }
        // ✨ ИЗМЕНЕНИЕ №2: Применяем настройку темы к самому окну настроек
        .preferredColorScheme(getPreferredColorScheme())
    }
}
