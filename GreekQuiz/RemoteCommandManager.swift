import MediaPlayer

extension Notification.Name {
    static let talkShowTogglePlayPause = Notification.Name("talkShowTogglePlayPause")
    static let talkShowSkipToNext = Notification.Name("talkShowSkipToNext")
    static let talkShowSkipToPrevious = Notification.Name("talkShowSkipToPrevious")
}

class RemoteCommandManager {
    static let shared = RemoteCommandManager()

    func setupRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { event in
            NotificationCenter.default.post(name: .talkShowTogglePlayPause, object: nil)
            return .success
        }

        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { event in
            NotificationCenter.default.post(name: .talkShowSkipToNext, object: nil)
            return .success
        }

        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { event in
            NotificationCenter.default.post(name: .talkShowSkipToPrevious, object: nil)
            return .success
        }
    }

    func updateNowPlayingInfo(question: String, answer: String) {
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = question
        nowPlayingInfo[MPMediaItemPropertyArtist] = answer
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = 1.0

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
}
