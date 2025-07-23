import SwiftUI
import AVFoundation

@main
struct GreekQuizApp: App {
    @AppStorage("interfaceLanguage") var interfaceLanguage: String = "en"

    init() {
        let currentLanguageSetting = UserDefaults.standard.string(forKey: "interfaceLanguage")
        if currentLanguageSetting == "system" || currentLanguageSetting == nil {
            // ✨ ИЗМЕНЕНИЕ: Исправлена ошибка. Используем `languageCode`, а не `languageCode.identifier`.
            // Также используем `Locale.preferredLanguages.first` для большей надежности.
            let systemLanguage = Locale.preferredLanguages.first?.components(separatedBy: "-").first
            if systemLanguage == "ru" {
                interfaceLanguage = "ru"
            } else if systemLanguage == "el" {
                interfaceLanguage = "el"
            } else {
                interfaceLanguage = "en" // По умолчанию английский
            }
        }
        
        // Настройка аудиосессии
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
            print("AVAudioSession настроена на .playback")
        } catch {
            print("Не удалось настроить AVAudioSession: \(error.localizedDescription)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.locale, Locale(identifier: interfaceLanguage))
        }
    }
}
