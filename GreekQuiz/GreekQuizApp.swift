import SwiftUI
import AVFoundation

@main
struct GreekQuizApp: App {
    init() {
        do {
            // Убедимся, что опция .duckOthers не включена, если это не требуется
            // Если .duckOthers включено, то другие аудиоисточники (например, музыка) будут приглушаться
            // Но мы хотим просто воспроизвести звук, не влияя на другие.
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
        }
    }
}
