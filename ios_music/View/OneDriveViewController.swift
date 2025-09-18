import UIKit
import SafariServices
import AVFoundation
import MediaPlayer

/// OneDriveの音楽ファイルとフォルダを階層的に表示し、音楽を再生するビューコントローラーです。
final class OneDriveViewController: UITableViewController, HiddenFoldersViewControllerDelegate {
    
    // --- プロパティ ---
    private var items: [DriveItem] = []
    private var currentFolderId: String? = nil
    
    private let musicPlayer = MusicPlayer()
    
    private let hiddenFolderIdsKey = "hiddenFolderIds"
    private var hiddenFolderIds: Set<String>{
        get{
            let ids = UserDefaults.standard.array(forKey: hiddenFolderIdsKey) as? [String] ?? []
            return Set(ids)
        }
        set{
            UserDefaults.standard.set(Array(newValue),forKey: hiddenFolderIdsKey)
        }
    }
    
    // --- UIコンポーネント ---
    private lazy var playbackContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .clear // Blurを使うので透明
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
        
        // ナビゲーションバー（右上に「…」）
        let moreButton = UIBarButtonItem(
            image: UIImage(systemName: "ellipsis.circle"),
            style: .plain,
            target: self,
            action: #selector(showMoreActions)
        )
        navigationItem.rightBarButtonItem = moreButton
        
        // TableView 設定
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.rowHeight = 54
        
        // 再生パネル：先に追加してブラーを敷く
        view.addSubview(playbackContainer)
        let blurEffect = UIBlurEffect(style: .systemMaterial)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.frame = playbackContainer.bounds
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        playbackContainer.insertSubview(blurView, at: 0)
        
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

            previousButton.leadingAnchor.constraint(equalTo: playbackContainer.leadingAnchor, constant: 20),
            previousButton.centerYAnchor.constraint(equalTo: playbackContainer.centerYAnchor),
            previousButton.widthAnchor.constraint(equalToConstant: 30),
            previousButton.heightAnchor.constraint(equalToConstant: 30),
            
            playPauseButton.leadingAnchor.constraint(equalTo: previousButton.trailingAnchor, constant: 10),
            playPauseButton.centerYAnchor.constraint(equalTo: playbackContainer.centerYAnchor),
            playPauseButton.widthAnchor.constraint(equalToConstant: 30),
            playPauseButton.heightAnchor.constraint(equalToConstant: 30),
            
            stopButton.leadingAnchor.constraint(equalTo: playPauseButton.trailingAnchor, constant: 10),
            stopButton.centerYAnchor.constraint(equalTo: playbackContainer.centerYAnchor),
            stopButton.widthAnchor.constraint(equalToConstant: 30),
            stopButton.heightAnchor.constraint(equalToConstant: 30),
            
            nextButton.leadingAnchor.constraint(equalTo: stopButton.trailingAnchor, constant: 10),
            nextButton.centerYAnchor.constraint(equalTo: playbackContainer.centerYAnchor),
            nextButton.widthAnchor.constraint(equalToConstant: 30),
            nextButton.heightAnchor.constraint(equalToConstant: 30),
            
            playbackStatusLabel.leadingAnchor.constraint(equalTo: nextButton.trailingAnchor, constant: 20),
            playbackStatusLabel.trailingAnchor.constraint(equalTo: playbackContainer.trailingAnchor, constant: -20),
            playbackStatusLabel.centerYAnchor.constraint(equalTo: playbackContainer.centerYAnchor)
        ])


        //ラベルをタップする
        playbackStatusLabel.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target:self,action: #selector(showPlayerScreen))
        playbackStatusLabel.addGestureRecognizer(tap)


        // 再生パネル分の余白（重なり防止）
        tableView.contentInset.bottom = 60
        
        // Pull to Refresh
        refreshControl = UIRefreshControl()
        refreshControl?.addTarget(self, action: #selector(reload), for: .valueChanged)
        
        reload()
    }

    @objc private func showPlayerScreen(){
        let vc = PlayerViewController(musicPlayer:musicPlayer)
        present(vc,animated:true)
    }
    
    // --- ナビゲーション右上アクション ---
    @objc private func showMoreActions() {
        let ac = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

        ac.addAction(UIAlertAction(title: "YouTube ダウンロード", style: .default) { _ in
            let vc = DownloadViewController()
            self.present(vc, animated: true)
        })

        ac.addAction(UIAlertAction(title: "Offline 保存", style: .default) { _ in
            self.downloadFolderForOffline()
        })

        ac.addAction(UIAlertAction(title: "非表示フォルダ一覧", style: .default) { _ in
            let vc = HiddenFoldersViewController(allItems: self.allFetchedItems)
            vc.delegate = self
            self.navigationController?.pushViewController(vc, animated: true)
        })

        ac.addAction(UIAlertAction(title: "Offline データをすべて削除", style: .destructive) { _ in
            self.deleteAllOfflineFiles()
        })
        ac.addAction(UIAlertAction(title: "サインアウト", style: .destructive) { _ in
            self.signOut()
        })

        ac.addAction(UIAlertAction(title: "キャンセル", style: .cancel))

        present(ac, animated: true)
    }

    
    private func deleteAllOfflineFiles() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let offlineRoot = docs.appendingPathComponent("OneDriveOffline")

        do {
            if FileManager.default.fileExists(atPath: offlineRoot.path) {
                try FileManager.default.removeItem(at: offlineRoot)
                print("🗑️ すべてのオフラインファイルを削除しました")
            }
            // UI更新（一覧リロード）
            self.tableView.reloadData()

            // 完了通知
            let alert = UIAlertController(title: "完了", message: "オフライン保存した音楽ファイルを削除しました。", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)

        } catch {
            print("❌ 一括削除に失敗: \(error)")
            self.showError("オフラインファイルの削除に失敗しました")
        }
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
        let nowPlayingInfo: [String: Any] = [
            MPMediaItemPropertyTitle: item.name
        ]
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
    private var allFetchedItems: [DriveItem] = [] // 追加
    
    private func fetchItems(token: String, folderId: String?, completion: (() -> Void)? = nil) {
        GraphClient.shared.listChildren(token: token, folderId: folderId) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch result {
                case .success(let items):
                    self.allFetchedItems = items // 👈 ここで全件保存
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
            // フォルダが非表示設定されていたらスキップ
            if let _ = item.folder, hiddenFolderIds.contains(item.id) {
                continue
            }
            
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
    
    private func endRefreshing() {
        if self.refreshControl?.isRefreshing == true {
            self.refreshControl?.endRefreshing()
        }
    }
    
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
        
        // 既存ビュー削除（重複防止）
        cell.contentView.subviews.forEach { $0.removeFromSuperview() }
        cell.accessoryView = nil
        cell.accessoryType = .none
        
        // アイコン
        let icon = UIImageView()
        if item.folder != nil {
            icon.image = UIImage(systemName: "folder.fill")
            icon.tintColor = .systemBlue
        } else {
            icon.image = UIImage(systemName: "music.note")
            icon.tintColor = .systemPink
        }
        icon.translatesAutoresizingMaskIntoConstraints = false
        
        // ファイル名ラベル
        let nameLabel = UILabel()
        nameLabel.text = item.name
        nameLabel.font = UIFont.systemFont(ofSize: 16)
        nameLabel.lineBreakMode = .byTruncatingMiddle
        nameLabel.textAlignment = .left
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        
        cell.contentView.addSubview(icon)
        cell.contentView.addSubview(nameLabel)
        

        NSLayoutConstraint.activate([
               // アイコンは左端に固定
               icon.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 15),
               icon.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
               icon.widthAnchor.constraint(equalToConstant: 24),
               icon.heightAnchor.constraint(equalToConstant: 24),

               // ラベルはアイコンの右に並べる
               nameLabel.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 12),
               nameLabel.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
               nameLabel.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -15)
           ])

        
        // 右側：フォルダは「＞」、ファイルはオフライン状態アイコン
        if item.folder != nil {
            cell.accessoryType = .disclosureIndicator
        } else if item.file != nil {
            if isOfflineAvailable(for: item) {
                let offlineIcon = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
                offlineIcon.tintColor = .systemGreen
                cell.accessoryView = offlineIcon
            } else {
                let offlineIcon = UIImageView(image: UIImage(systemName: "arrow.down.circle"))
                offlineIcon.tintColor = .systemBlue
                cell.accessoryView = offlineIcon
            }
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = items[indexPath.row]
        
        if item.folder != nil {
            let nextVC = OneDriveViewController(folderId: item.id, folderName: item.name)
            navigationController?.pushViewController(nextVC, animated: true)
        } else {
            // オフライン再生のみ許可
            guard isOfflineAvailable(for: item) else {
                showError("この曲はオフライン保存されていないため、再生できません。")
                return
            }
            let musicItems = items.filter { isMusicFile(item: $0) && isOfflineAvailable(for: $0) }
            if let index = musicItems.firstIndex(where: { $0.id == item.id }) {
                self.musicPlayer.playMusic(with: musicItems, at: index)
            }
        }
    }
    
    override func tableView(_ tableView: UITableView,
                            trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let item = items[indexPath.row]
        
        // フォルダの場合 → 表示/非表示を切り替え
        if item.folder != nil {
            let isHidden = hiddenFolderIds.contains(item.id)
            let actionTitle = isHidden ? "表示" : "非表示"
            
            let toggleAction = UIContextualAction(style: .normal, title: actionTitle) { [weak self] (_, _, completion) in
                guard let self = self else { return }
                if isHidden {
                    self.hiddenFolderIds.remove(item.id)
                } else {
                    self.hiddenFolderIds.insert(item.id)
                }
                self.reload()
                completion(true)
            }
            toggleAction.backgroundColor = isHidden ? .systemGreen : .systemGray
            return UISwipeActionsConfiguration(actions: [toggleAction])
        }
        
        // ファイルの場合は既存の削除処理
        if item.file != nil {
            if isOfflineAvailable(for: item) {
                let deleteAction = UIContextualAction(style: .destructive, title: "削除") { [weak self] (_, _, completion) in
                    self?.deleteOfflineFile(for: item)
                    tableView.reloadRows(at: [indexPath], with: .automatic)
                    completion(true)
                }
                return UISwipeActionsConfiguration(actions: [deleteAction])
            }
        }
        return nil
    }
    
    // --- オフライン状態チェック＆削除 ---
    private func isOfflineAvailable(for item: DriveItem) -> Bool {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let offlineRoot = docs.appendingPathComponent("OneDriveOffline")
        if let enumerator = FileManager.default.enumerator(at: offlineRoot, includingPropertiesForKeys: nil) {
            for case let fileURL as URL in enumerator {
                if fileURL.lastPathComponent == item.name {
                    return true
                }
            }
        }
        return false
    }
    
    private func deleteOfflineFile(for item: DriveItem) {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let offlineRoot = docs.appendingPathComponent("OneDriveOffline")
        let filePath = offlineRoot.appendingPathComponent(item.name)
        try? FileManager.default.removeItem(at: filePath)
    }
    
    // --- 再生ボタン ---
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
    
    // --- オフライン保存 ---
    @objc private func downloadFolderForOffline() {
        guard let folderId = currentFolderId else { return }
        AuthManager.shared.withAccessToken(from: self) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let token):
                self.downloadFolderRecursively(folderId: folderId, folderName: self.title ?? "Offline", token: token)
            case .failure(let error):
                self.showError(error.localizedDescription)
            }
        }
    }
    
    private func downloadFolderRecursively(folderId: String, folderName: String, token: String) {
        GraphClient.shared.listChildren(token: token, folderId: folderId) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let items):
                for item in items {
                    if let _ = item.folder {
                        self.downloadFolderRecursively(folderId: item.id, folderName: item.name, token: token)
                    } else if self.isMusicFile(item: item) {
                        // ダウンロード開始時にラベルを更新
                        let truncatedName = String(item.name.prefix(5))
                        DispatchQueue.main.async {
                            self.playbackStatusLabel.text = "『\(truncatedName)』を保存中..."
                        }
                        self.downloadFile(item: item, folderName: folderName, token: token)
                    }
                }
            case .failure(let error):
                self.showError(error.localizedDescription)
            }
        }
    }

    private func downloadFile(item: DriveItem, folderName: String, token: String) {
        guard let url = URL(string: "https://graph.microsoft.com/v1.0/me/drive/items/\(item.id)/content") else { return }
        
        var request = URLRequest(url: url)
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let task = URLSession.shared.downloadTask(with: request) { localURL, response, error in
            guard let localURL = localURL, error == nil else { return }
            do {
                let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                let targetDir = docs.appendingPathComponent("OneDriveOffline").appendingPathComponent(folderName)
                try FileManager.default.createDirectory(at: targetDir, withIntermediateDirectories: true)
                
                let targetFile = targetDir.appendingPathComponent(item.name)
                
                // 既存はスキップ
                if FileManager.default.fileExists(atPath: targetFile.path) {
                    print("⏩ Skip (already downloaded): \(targetFile.lastPathComponent)")
                    return
                }
                
                try FileManager.default.moveItem(at: localURL, to: targetFile)
                print("✅ Saved offline: \(targetFile.lastPathComponent)")
                
                // ダウンロード成功後、ラベルを更新
                DispatchQueue.main.async {
                    self.playbackStatusLabel.text = "保存が完了しました。"
                }
            } catch {
                print("❌ Save failed: \(error)")
            }
        }
        task.resume()
    }
}

// MARK: - MusicPlayerDelegate
extension OneDriveViewController: MusicPlayerDelegate {
    func musicPlayerDidStartLoading(item: DriveItem) {
        DispatchQueue.main.async {
            self.playbackStatusLabel.text = "\(item.name) を読み込み中..."
        }
    }
    
    func musicPlayerDidStartPlaying(item: DriveItem) {
        DispatchQueue.main.async {
            self.playbackStatusLabel.text = "\(item.name) 再生中..."
            self.playPauseButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
            self.updateNowPlayingInfo(for: item)
        }
    }
    
    func musicPlayerDidTogglePlayback(isPlaying: Bool) {
        DispatchQueue.main.async {
            let imageName = isPlaying ? "pause.fill" : "play.fill"
            self.playPauseButton.setImage(UIImage(systemName: imageName), for: .normal)
        }
    }
    
    func musicPlayerDidFinishPlaying() {
        // 連続再生などをMusicPlayer側でハンドルしている想定
    }
    
    func musicPlayerDidStopPlayback() {
        DispatchQueue.main.async {
            self.playbackStatusLabel.text = "再生が停止しました。"
            self.playPauseButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
        }
    }
    
    func musicPlayerDidReceiveError(message: String) {
        DispatchQueue.main.async {
            self.showError(message)
        }
    }
    
    func musicPlayerDidRequestAuth(completion: @escaping (Result<String, Error>) -> Void) {
        AuthManager.shared.withAccessToken(from: self, completion)
    }
    func hiddenFoldersDidChange() {
        // 👇 即時更新
        self.reload()
    }
    
}
