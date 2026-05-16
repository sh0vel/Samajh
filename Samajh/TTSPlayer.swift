import AVFoundation

@MainActor
final class TTSPlayer: NSObject {
    static let shared = TTSPlayer()

    private let synthesizer = AVSpeechSynthesizer()

    private override init() {
        super.init()
        synthesizer.delegate = self
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: .duckOthers)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    func speak(_ text: String, language: String = "hi-IN") {
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        utterance.rate = 0.42
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}

extension TTSPlayer: AVSpeechSynthesizerDelegate {}
