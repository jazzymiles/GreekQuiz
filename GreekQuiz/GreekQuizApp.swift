import SwiftUI
import AVFoundation

@main
struct GreekQuizApp: App {
    @AppStorage("interfaceLanguage") var interfaceLanguage: String = "en"

    init() {
        let currentLanguageSetting = UserDefaults.standard.string(forKey: "interfaceLanguage")
        if currentLanguageSetting == "system" || currentLanguageSetting == nil {
            let systemLanguage = Locale.preferredLanguages.first?.components(separatedBy: "-").first
            if systemLanguage == "ru" {
                interfaceLanguage = "ru"
            } else if systemLanguage == "el" {
                interfaceLanguage = "el"
            } else {
                interfaceLanguage = "en"
            }
        }
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
            print("AVAudioSession настроена на .playback")
        } catch {
            print("Не удалось настроить AVAudioSession: \(error.localizedDescription)")
        }
        
        RemoteCommandManager.shared.setupRemoteCommands()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.locale, Locale(identifier: interfaceLanguage))
        }
    }
}
