import SwiftUI

struct SettingsView: View {
    @Binding var showTranscription: Bool
    @Binding var autoPlaySound: Bool
    @Binding var colorSchemePreference: String
    @Binding var dictionarySource: DictionarySource
    @Binding var customDictionaryURL: String
    
    @Binding var studiedLanguage: String
    @Binding var answerLanguage: String

    @Environment(\.dismiss) var dismiss
    
    @Binding var interfaceLanguage: String

    var onDownloadDictionaries: () -> Void

    @Environment(\.colorScheme) var currentSystemColorScheme: ColorScheme

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
                }

                Section(header: Text("language_settings_section")) {
                    // ✨ ИЗМЕНЕНИЕ: Добавлена надпись "Язык обучения"
                    Text("studied_language_picker")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Picker("studied_language_picker", selection: $studiedLanguage) {
                        Text("greek_language").tag("el")
                        Text("russian_language").tag("ru")
                        Text("english_language").tag("en")
                    }
                    .pickerStyle(.segmented)

                    // ✨ ИЗМЕНЕНИЕ: Добавлена надпись "Язык ответа"
                    Text("answer_language_picker")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.top) // Добавляем отступ сверху для визуального разделения

                    Picker("answer_language_picker", selection: $answerLanguage) {
                        Text("russian_language").tag("ru")
                        Text("greek_language").tag("el")
                        Text("english_language").tag("en")
                    }
                    .pickerStyle(.segmented)
                }

                Section(header: Text("interface_language_section")) {
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
    }
}
