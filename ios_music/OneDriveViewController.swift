import UIKit
import SafariServices
import AVFoundation

/// OneDriveの音楽ファイルとフォルダを階層的に表示し、音楽を再生するビューコントローラーです。
final class OneDriveViewController: UITableViewController {
    
    // --- プロパティ ---
    /// 現在の階層にあるファイルとフォルダのリスト。
    private var items: [DriveItem] = []
    /// 現在表示しているフォルダのID。
    private var currentFolderId: String? = nil
    
    // --- 音楽再生関連 ---
    private var player: AVPlayer?
    
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
        label.textAlignment = .center
        label.numberOfLines = 1
        label.textColor = .systemGray
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var playPauseButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "play.fill"), for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(togglePlayback), for: .touchUpInside)
        return button
    }()
    
    // --- 初期化メソッド ---
    init(folderId: String? = nil, folderName: String? = "OneDrive") {
        super.init(style: .insetGrouped)
        self.currentFolderId = folderId
        self.title = folderName
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    // --- ライフサイクルメソッド ---
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemGroupedBackground
        
        // ナビゲーションバーの設定
        let signOutButton = UIBarButtonItem(title: "Sign Out", style: .plain, target: self, action: #selector(signOut))
        navigationItem.rightBarButtonItem = signOutButton
        
        // TableViewの設定
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.rowHeight = 54
        
        // 音楽再生パネルのUI設定
        view.addSubview(playbackContainer)
        playbackContainer.addSubview(playbackStatusLabel)
        playbackContainer.addSubview(playPauseButton)
        
        NSLayoutConstraint.activate([
            playbackContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            playbackContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            playbackContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            playbackContainer.heightAnchor.constraint(equalToConstant: 60),
            
            playbackStatusLabel.leadingAnchor.constraint(equalTo: playbackContainer.leadingAnchor, constant: 20),
            playbackStatusLabel.centerYAnchor.constraint(equalTo: playbackContainer.centerYAnchor),
            playbackStatusLabel.trailingAnchor.constraint(equalTo: playPauseButton.leadingAnchor, constant: -10),
            
            playPauseButton.trailingAnchor.constraint(equalTo: playbackContainer.trailingAnchor, constant: -20),
            playPauseButton.centerYAnchor.constraint(equalTo: playbackContainer.centerYAnchor),
            playPauseButton.widthAnchor.constraint(equalToConstant: 40),
            playPauseButton.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        // Pull to Refresh
        refreshControl = UIRefreshControl()
        refreshControl?.addTarget(self, action: #selector(reload), for: .valueChanged)
        
        reload()
    }
    
    // --- データ取得ロジック ---
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
    
    /// 指定されたフォルダ内のアイテム（フォルダとファイル）を取得します。
    private func fetchItems(token: String, folderId: String?) {
        GraphClient.shared.listChildren(token: token, folderId: folderId) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.endRefreshing()
                
                switch result {
                case .success(let items):
                    // フォルダは常にリストの上部に表示されるようにソートします
                    self.items = items.sorted(by: { a, b in
                        if a.folder != nil && b.file != nil { return true }
                        if a.file != nil && b.folder != nil { return false }
                        return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
                    })
                    self.tableView.reloadData()
                case .failure(let error):
                    self.showError(error.localizedDescription)
                }
            }
        }
    }
    
    /// 与えられたアイテムが音楽ファイルかどうかを判定します。
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
    
    // MARK: - TableView
    
    override func numberOfSections(in tableView: UITableView) -> Int { 1 }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { items.count }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = items[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        
        var config = cell.defaultContentConfiguration()
        config.text = item.name
        
        if item.folder != nil {
            // フォルダの場合
            config.image = UIImage(systemName: "folder.fill")
            cell.accessoryType = .disclosureIndicator
        } else if isMusicFile(item: item) {
            // 音楽ファイルの場合
            config.image = UIImage(systemName: "music.note")
            cell.accessoryType = .none
        } else {
            // その他のファイルの場合
            config.image = UIImage(systemName: "doc.fill")
            cell.accessoryType = .none
        }
        
        cell.contentConfiguration = config
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = items[indexPath.row]
        
        if item.folder != nil {
            // フォルダをタップした場合、新しいビューコントローラーをプッシュして階層を移動します
            let nextVC = OneDriveViewController(folderId: item.id, folderName: item.name)
            navigationController?.pushViewController(nextVC, animated: true)
        } else if isMusicFile(item: item) {
            // 音楽ファイルをタップした場合、再生を開始します
            playMusic(item: item)
        }
    }
    
    // MARK: - 音楽再生
    
    /// 選択された音楽ファイルの再生を開始します。
    private func playMusic(item: DriveItem) {
        playbackStatusLabel.text = "\(item.name) を読み込み中..."
        playPauseButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
        
        AuthManager.shared.withAccessToken(from: self) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let token):
                GraphClient.shared.getDownloadUrl(for: item.id, token: token) { result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success(let urlString):
                            guard let url = URL(string: urlString) else {
                                self.showError("無効なダウンロードURLです。")
                                self.playbackStatusLabel.text = "再生エラー"
                                return
                            }
                            
                            let playerItem = AVPlayerItem(url: url)
                            self.player = AVPlayer(playerItem: playerItem)
                            
                            // 再生準備ができたことを監視
                            NotificationCenter.default.addObserver(self, selector: #selector(self.playerDidFinishPlaying), name: .AVPlayerItemDidPlayToEndTime, object: playerItem)
                            
                            self.player?.play()
                            self.playbackStatusLabel.text = "\(item.name) 再生中..."
                            
                        case .failure(let error):
                            self.showError(error.localizedDescription)
                            self.playbackStatusLabel.text = "再生エラー"
                        }
                    }
                }
            case .failure(let error):
                self.showError(error.localizedDescription)
                self.playbackStatusLabel.text = "再生エラー"
            }
        }
    }
    
    @objc private func togglePlayback() {
        guard let player = player else { return }
        if player.rate == 0 {
            player.play()
            playPauseButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
        } else {
            player.pause()
            playPauseButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
        }
    }
    
    @objc private func playerDidFinishPlaying() {
        playPauseButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
        playbackStatusLabel.text = "再生が完了しました。"
    }
    
    // MARK: - Sign out
    
    @objc private func signOut() {
        player?.pause() // サインアウト時に再生を停止
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