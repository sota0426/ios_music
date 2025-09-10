import AVFoundation

/// 音楽の再生とバックグラウンド再生を管理するクラスです。
final class MusicPlayer {
    
    static let shared = MusicPlayer()
    
    private var player: AVPlayer?
    
    var onPlaybackStatusChange: ((String) -> Void)?
    var onPlaybackFinish: (() -> Void)?
    
    private init() {
        // バックグラウンド再生を有効にするためのオーディオセッション設定
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("AVAudioSession configuration error: \(error.localizedDescription)")
        }
    }
    
    /// 指定されたURLの音楽を再生します。
    func play(from url: URL, trackName: String) {
        stop()
        
        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(playerDidFinishPlaying),
                                               name: .AVPlayerItemDidPlayToEndTime,
                                               object: playerItem)
        
        player?.play()
        onPlaybackStatusChange?("\(trackName) 再生中...")
        
        // バックグラウンド再生中のコントロールセンターに表示する情報の設定
        // ここにメディア情報の更新ロジックを追加できます
    }
    
    /// 再生状態を切り替えます。
    func togglePlayback() {
        guard let player = player else { return }
        if player.rate == 0 {
            player.play()
            onPlaybackStatusChange?("再生中...") // 再生中のメッセージを更新
        } else {
            player.pause()
            onPlaybackStatusChange?("一時停止中") // 一時停止中のメッセージを更新
        }
    }
    
    /// 再生を停止します。
    func stop() {
        player?.pause()
        player = nil
        onPlaybackStatusChange?("停止中")
    }
    
    /// 現在再生中かどうかを返します。
    var isPlaying: Bool {
        return player?.rate != 0 && player?.error == nil
    }
    
    @objc private func playerDidFinishPlaying() {
        onPlaybackFinish?()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}