import UIKit
import SafariServices
import AVFoundation
import MediaPlayer

/// OneDriveの音楽ファイルとフォルダを階層的に表示し、音楽を再生するビューコントローラーです。
final class OneDriveViewController: UITableViewController {
    
    // --- プロパティ ---
    private var items: [DriveItem] = []
    private var currentFolderId: String? = nil
    
    private let musicPlayer = MusicPlayer()
    
    // --- UIコンポーネント ---
    private lazy var playbackContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.1
        view.layer.shadowRadius = 5
        view.layer.shadowOffset = .zero
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let playbackStatusLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .left
        label.numberOfLines = 1
        label.textColor = .systemGray
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var previousButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "backward.fill"), for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(handlePreviousButtonTap), for: .touchUpInside)
        return button
    }()
    
    private lazy var playPauseButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "play.fill"), for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(handlePlayPauseButtonTap), for: .touchUpInside)
        return button
    }()
    
    private lazy var stopButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "stop.fill"), for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(handleStopButtonTap), for: .touchUpInside)
        return button
    }()
    
    private lazy var nextButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "forward.fill"), for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(handleNextButtonTap), for: .touchUpInside)
        return button
    }()
    
    // --- 初期化 ---
    init(folderId: String? = nil, folderName: String? = "OneDrive") {
        super.init(style: .insetGrouped)
        self.currentFolderId = folderId
        self.title = folderName
        self.musicPlayer.delegate = self
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    // --- ライフサイクル ---
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemGroupedBackground
        
        // AVAudioSession 設定（バックグラウンド再生を有効化）
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.allowBluetooth, .allowAirPlay])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("AVAudioSession configuration error: \(error)")
        }
        
        // Remote Command セットアップ
        setupRemoteTransportControls()
        
        // ナビゲーションバー
        let signOutButton = UIBarButtonItem(title: "Sign Out", style: .plain, target: self, action: #selector(signOut))
        navigationItem.rightBarButtonItem = signOutButton
        
        // TableView 設定
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.rowHeight = 54
        
        // 音楽再生パネル
        view.addSubview(playbackContainer)
        playbackContainer.addSubview(previousButton)
        playbackContainer.addSubview(playPauseButton)
        playbackContainer.addSubview(stopButton)
        playbackContainer.addSubview(nextButton)
        playbackContainer.addSubview(playbackStatusLabel)
        
        NSLayoutConstraint.activate([
            playbackContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            playbackContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            playbackContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            playbackContainer.heightAnchor.constraint(equalToConstant: 60),
            
            previousButton.trailingAnchor.constraint(equalTo: playPauseButton.leadingAnchor, constant: -10),
            previousButton.centerYAnchor.constraint(equalTo: playbackContainer.centerYAnchor),
            previousButton.widthAnchor.constraint(equalToConstant: 30),
            previousButton.heightAnchor.constraint(equalToConstant: 30),
            
            playPauseButton.trailingAnchor.constraint(equalTo: stopButton.leadingAnchor, constant: -10),
            playPauseButton.centerYAnchor.constraint(equalTo: playbackContainer.centerYAnchor),
            playPauseButton.widthAnchor.constraint(equalToConstant: 30),
            playPauseButton.heightAnchor.constraint(equalToConstant: 30),
            
            stopButton.trailingAnchor.constraint(equalTo: nextButton.leadingAnchor, constant: -10),
            stopButton.centerYAnchor.constraint(equalTo: playbackContainer.centerYAnchor),
            stopButton.widthAnchor.constraint(equalToConstant: 30),
            stopButton.heightAnchor.constraint(equalToConstant: 30),
            
            nextButton.trailingAnchor.constraint(equalTo: playbackContainer.trailingAnchor, constant: -20),
            nextButton.centerYAnchor.constraint(equalTo: playbackContainer.centerYAnchor),
            nextButton.widthAnchor.constraint(equalToConstant: 30),
            nextButton.heightAnchor.constraint(equalToConstant: 30),
            
            playbackStatusLabel.leadingAnchor.constraint(equalTo: playbackContainer.leadingAnchor, constant: 20),
            playbackStatusLabel.centerYAnchor.constraint(equalTo: playbackContainer.centerYAnchor),
            playbackStatusLabel.trailingAnchor.constraint(equalTo: previousButton.leadingAnchor, constant: -10)
        ])
        
        // Pull to Refresh
        refreshControl = UIRefreshControl()
        refreshControl?.addTarget(self, action: #selector(reload), for: .valueChanged)
        
        reload()
    }
    
    // --- Remote Command Center 設定 ---
    private func setupRemoteTransportControls() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.musicPlayer.resumePlayback()
            return .success
        }
        
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.musicPlayer.pausePlayback()
            return .success
        }
        
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.musicPlayer.playNext()
            return .success
        }
        
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.musicPlayer.playPrevious()
            return .success
        }
    }
    
    // --- Now Playing 情報更新 ---
    private func updateNowPlayingInfo(for item: DriveItem) {
        var nowPlayingInfo: [String: Any] = [
            MPMediaItemPropertyTitle: item.name
        ]
        
        // アーティストやアルバムが取れるなら追加
        // nowPlayingInfo[MPMediaItemPropertyArtist] = "アーティスト名"
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    // --- データ取得 ---
    @objc private func reload() {
        AuthManager.shared.withAccessToken(from: self) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let token):
                    self.fetchItems(token: token, folderId: self.currentFolderId)
                case .failure(let error):
                    self.endRefreshing()
                    self.showError(error.localizedDescription)
                }
            }
        }
    }
    
    private func fetchItems(token: String, folderId: String?, completion: (() -> Void)? = nil) {
        GraphClient.shared.listChildren(token: token, folderId: folderId) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                switch result {
                case .success(let items):
                    self.filterAndSortItems(items: items, token: token) {
                        self.endRefreshing()
                        self.tableView.reloadData()
                        completion?()
                    }
                case .failure(let error):
                    self.endRefreshing()
                    self.showError(error.localizedDescription)
                    completion?()
                }
            }
        }
    }
    
    private func filterAndSortItems(items: [DriveItem], token: String, completion: @escaping () -> Void) {
        var newItems: [DriveItem] = []
        
        for item in items {
            if item.folder != nil {
                newItems.append(item)
            } else if isMusicFile(item: item) {
                newItems.append(item)
            }
        }
        
        self.items = newItems.sorted(by: { a, b in
            if a.folder != nil && b.file != nil { return true }
            if a.file != nil && b.folder != nil { return false }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        })
        
        completion()
    }
    
    private func isMusicFile(item: DriveItem) -> Bool {
        guard let mimeType = item.file?.mimeType else { return false }
        return mimeType.hasPrefix("audio/")
    }
    
    private func endRefreshing() { if self.refreshControl?.isRefreshing == true { self.refreshControl?.endRefreshing() } }
    
    private func showError(_ message: String) {
        let ac = UIAlertController(title: "エラー", message: message, preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "OK", style: .default))
        present(ac, animated: true)
    }
    
    // --- TableView ---
    override func numberOfSections(in tableView: UITableView) -> Int { 1 }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { items.count }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = items[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        
        var config = cell.defaultContentConfiguration()
        config.text = item.name
        
        if item.folder != nil {
            config.image = UIImage(systemName: "folder.fill")
            cell.accessoryType = .disclosureIndicator
        } else {
            config.image = UIImage(systemName: "music.note")
            cell.accessoryType = .none
        }
        
        cell.contentConfiguration = config
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = items[indexPath.row]
        
        if item.folder != nil {
            let nextVC = OneDriveViewController(folderId: item.id, folderName: item.name)
            navigationController?.pushViewController(nextVC, animated: true)
        } else {
            let musicItems = items.filter { isMusicFile(item: $0) }
            if let index = musicItems.firstIndex(where: { $0.id == item.id }) {
                AuthManager.shared.withAccessToken(from: self) { [weak self] result in
                    if case .success(let token) = result {
                        self?.musicPlayer.playMusic(with: musicItems, at: index, token: token)
                    } else if case .failure(let error) = result {
                        self?.showError(error.localizedDescription)
                    }
                }
            }
        }
    }
    
    // --- 音楽再生ボタン ---
    @objc private func handlePreviousButtonTap() { musicPlayer.playPrevious() }
    @objc private func handlePlayPauseButtonTap() { musicPlayer.togglePlayback() }
    @objc private func handleStopButtonTap() { musicPlayer.stopPlayback() }
    @objc private func handleNextButtonTap() { musicPlayer.playNext() }
    
    // --- Sign out ---
    @objc private func signOut() {
        musicPlayer.stopPlayback()
        AuthManager.shared.signOut(from: self) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    let login = LoginViewController()
                    let nav = UINavigationController(rootViewController: login)
                    
                    if let window = self.view.window {
                        window.rootViewController = nav
                        UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve, animations: nil)
                    } else {
                        self.present(nav, animated: true)
                    }
                case .failure(let error):
                    self.showError(error.localizedDescription)
                }
            }
        }
    }
}

// MARK: - MusicPlayerDelegate
extension OneDriveViewController: MusicPlayerDelegate {
    func musicPlayerDidStartLoading(item: DriveItem) {
        playbackStatusLabel.text = "\(item.name) を読み込み中..."
    }
    
    func musicPlayerDidStartPlaying(item: DriveItem) {
        playbackStatusLabel.text = "\(item.name) 再生中..."
        playPauseButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
        updateNowPlayingInfo(for: item)
    }
    
    func musicPlayerDidTogglePlayback(isPlaying: Bool) {
        let imageName = isPlaying ? "pause.fill" : "play.fill"
        playPauseButton.setImage(UIImage(systemName: imageName), for: .normal)
    }
    
    func musicPlayerDidFinishPlaying() {}
    
    func musicPlayerDidStopPlayback() {
        playbackStatusLabel.text = "再生が停止しました。"
        playPauseButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
    }
    
    func musicPlayerDidReceiveError(message: String) {
        showError(message)
    }
    
    func musicPlayerDidRequestAuth(completion: @escaping (Result<String, Error>) -> Void) {
        AuthManager.shared.withAccessToken(from: self, completion)
    }
}
