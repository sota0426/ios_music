import Foundation
import AVFoundation

protocol MusicPlayerDelegate: AnyObject {
    func musicPlayerDidStartLoading(item: DriveItem)
    func musicPlayerDidStartPlaying(item: DriveItem)
    func musicPlayerDidTogglePlayback(isPlaying: Bool)
    func musicPlayerDidFinishPlaying()
    func musicPlayerDidStopPlayback()
    func musicPlayerDidReceiveError(message: String)
}

final class MusicPlayer: NSObject {
    
    // --- プロパティ ---
    private var player: AVPlayer?
    private var items: [DriveItem] = []
    var currentIndex: Int = 0
    
    weak var delegate: MusicPlayerDelegate?
    
    private var isPlaying: Bool {
        player?.timeControlStatus == .playing
    }
    
    // --- オフライン専用再生 ---
    func playMusic(with items: [DriveItem], at index: Int) {
        guard items.indices.contains(index) else { return }
        self.items = items
        self.currentIndex = index
        let item = items[index]
        
        // オフラインファイルチェック
        guard let offlineURL = findOfflineFile(for: item) else {
            delegate?.musicPlayerDidReceiveError(message: "オフライン保存されていないため再生できません。")
            return
        }
        
        delegate?.musicPlayerDidStartLoading(item: item)
        
        let playerItem = AVPlayerItem(url: offlineURL)
        if player == nil {
            player = AVPlayer(playerItem: playerItem)
        } else {
            player?.replaceCurrentItem(with: playerItem)
        }
        
        // 再生終了通知を登録
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePlaybackFinished),
            name: .AVPlayerItemDidPlayToEndTime,
            object: playerItem
        )
        
        player?.play()
        delegate?.musicPlayerDidStartPlaying(item: item)
    }
    
    // --- オフラインファイル探索 ---
    private func findOfflineFile(for item: DriveItem) -> URL? {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let offlineRoot = docs.appendingPathComponent("OneDriveOffline")
        
        // 再帰的に対象ファイルを探す
        if let enumerator = FileManager.default.enumerator(at: offlineRoot, includingPropertiesForKeys: nil) {
            for case let fileURL as URL in enumerator {
                if fileURL.lastPathComponent == item.name {
                    return fileURL
                }
            }
        }
        return nil
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
        playMusic(with: items, at: currentIndex)
    }
    
    func playPrevious() {
        guard currentIndex - 1 >= 0 else { return }
        currentIndex -= 1
        playMusic(with: items, at: currentIndex)
    }
    
    // --- 再生終了 ---
    @objc private func handlePlaybackFinished() {
        delegate?.musicPlayerDidFinishPlaying()
        playNext() // 自動で次の曲へ進めたい場合
    }
    
    // --- 解放処理 ---
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func upcomingItems(count : Int)->[DriveItem]{
        let startIndex = currentIndex + 1
        let endIndex = min(startIndex + count , items.count)
        guard startIndex < endIndex else { return[]}
        return Array(items[startIndex..<endIndex])
    }

    var allItems:[DriveItem]{
        return items
    }

    /// 現在再生中のアイテム
    var currentItem: DriveItem? {
        guard items.indices.contains(currentIndex) else { return nil }
        return items[currentIndex]
    }
    
    /// 次の曲があるかどうか
    var hasNext: Bool {
        return currentIndex + 1 < items.count
    }
    
    /// 前の曲があるかどうか
    var hasPrevious: Bool {
        return currentIndex > 0
    }
    
    // MARK: - 追加メソッド
    
    /// 指定した時間にシーク
    func seek(to time: CMTime, completion: @escaping (Bool) -> Void) {
        player?.seek(to: time, completionHandler: completion)
    }
    
    /// 現在の再生時間を取得
    func getCurrentTime() -> CMTime {
        return player?.currentTime() ?? .zero
    }
    
    /// 曲の総再生時間を取得
    func getDuration() -> CMTime {
        return player?.currentItem?.duration ?? .zero
    }
    
    /// 再生状態を取得
    var isCurrentlyPlaying: Bool {
        return isPlaying
    }
    
    func addPeriodicTimeObserver(interval: CMTime,
                                 handler: @escaping (CMTime) -> Void) -> Any? {
        return player?.addPeriodicTimeObserver(forInterval: interval,
                                               queue: .main,
                                               using: handler)
    }

    func removePeriodicTimeObserver(_ observer: Any) {
        if let player = player {
            player.removeTimeObserver(observer)
        }
    }
    
}
