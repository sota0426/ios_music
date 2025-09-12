import Foundation
import AVFoundation

protocol MusicPlayerDelegate: AnyObject {
    func musicPlayerDidStartLoading(item: DriveItem)
    func musicPlayerDidStartPlaying(item: DriveItem)
    func musicPlayerDidTogglePlayback(isPlaying: Bool)
    func musicPlayerDidFinishPlaying()
    func musicPlayerDidStopPlayback()
    func musicPlayerDidReceiveError(message: String)
    func musicPlayerDidRequestAuth(completion: @escaping (Result<String, Error>) -> Void)
}

final class MusicPlayer: NSObject {
    
    // --- プロパティ ---
    private var player: AVPlayer?
    private var items: [DriveItem] = []
    private var currentIndex: Int = 0
    
    weak var delegate: MusicPlayerDelegate?
    
    private var isPlaying: Bool {
        player?.timeControlStatus == .playing
    }
    
    // --- 音楽再生開始 ---
    func playMusic(with items: [DriveItem], at index: Int, token: String) {
        guard items.indices.contains(index) else { return }
        
        self.items = items
        self.currentIndex = index
        
        let item = items[index]
        delegate?.musicPlayerDidStartLoading(item: item)
        
        // OneDrive のダウンロードURLを取得
        guard let url = URL(string: "https://graph.microsoft.com/v1.0/me/drive/items/\(item.id)/content") else {
            delegate?.musicPlayerDidReceiveError(message: "音楽ファイルのURLが無効です")
            return
        }
        
        // 認証付きリクエストのために AVURLAsset を使う
        let headers = ["Authorization": "Bearer \(token)"]
        let asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
        let playerItem = AVPlayerItem(asset: asset)
        
        // 古い通知を削除
        if let currentItem = player?.currentItem {
            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: currentItem)
        }
        
        // 新しいプレイヤー作成
        player = AVPlayer(playerItem: playerItem)
        
        // 再生完了通知
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handlePlaybackFinished),
                                               name: .AVPlayerItemDidPlayToEndTime,
                                               object: playerItem)
        
        player?.play()
        delegate?.musicPlayerDidStartPlaying(item: item)
    }
    
    // --- 再生制御 ---
    func togglePlayback() {
        guard let player = player else { return }
        
        if isPlaying {
            player.pause()
            delegate?.musicPlayerDidTogglePlayback(isPlaying: false)
        } else {
            player.play()
            delegate?.musicPlayerDidTogglePlayback(isPlaying: true)
        }
    }
    
    func pausePlayback() {
        player?.pause()
        delegate?.musicPlayerDidTogglePlayback(isPlaying: false)
    }
    
    func resumePlayback() {
        player?.play()
        delegate?.musicPlayerDidTogglePlayback(isPlaying: true)
    }
    
    func stopPlayback() {
        player?.pause()
        player = nil
        delegate?.musicPlayerDidStopPlayback()
    }
    
    // --- 前後トラック ---
    func playNext() {
        guard currentIndex + 1 < items.count else { return }
        currentIndex += 1
        requestAuthAndPlay()
    }
    
    func playPrevious() {
        guard currentIndex - 1 >= 0 else { return }
        currentIndex -= 1
        requestAuthAndPlay()
    }
    
    // --- 認証リクエストを挟んで再生 ---
    private func requestAuthAndPlay() {
        delegate?.musicPlayerDidRequestAuth { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let token):
                self.playMusic(with: self.items, at: self.currentIndex, token: token)
            case .failure(let error):
                self.delegate?.musicPlayerDidReceiveError(message: error.localizedDescription)
            }
        }
    }
    
    // --- 再生終了 ---
    @objc private func handlePlaybackFinished() {
        delegate?.musicPlayerDidFinishPlaying()
        playNext() // 自動で次の曲へ進めたい場合
    }
}
