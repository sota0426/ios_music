import UIKit
import MediaPlayer
import AVFoundation

final class PlayerViewController: UIViewController {
    
    // MARK: - Properties
    private var musicPlayer = MusicPlayer()
    
    private var timeObserverToken: Any?
    
    // MARK: - UI Components
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 20, weight: .bold)
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let artistLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 16, weight: .regular)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let playbackSlider: UISlider = {
        let slider = UISlider()
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.minimumTrackTintColor = .systemPink
        slider.maximumTrackTintColor = .systemGray4
        slider.thumbTintColor = .systemPink
        return slider
    }()
    
    private let currentTimeLabel: UILabel = {
        let label = UILabel()
        label.font = .monospacedDigitSystemFont(ofSize: 14, weight: .regular)
        label.text = "0:00"
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let remainingTimeLabel: UILabel = {
        let label = UILabel()
        label.font = .monospacedDigitSystemFont(ofSize: 14, weight: .regular)
        label.text = "-0:00"
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let upcomingTracksStackView:UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    private lazy var previousButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "backward.fill"), for: .normal)
        button.tintColor = .label
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(handlePreviousButtonTap), for: .touchUpInside)
        return button
    }()
    
    private lazy var playPauseButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "play.fill"), for: .normal)
        button.tintColor = .systemPink
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setPreferredSymbolConfiguration(UIImage.SymbolConfiguration(pointSize: 40), forImageIn: .normal)
        button.addTarget(self, action: #selector(handlePlayPauseButtonTap), for: .touchUpInside)
        return button
    }()
    
    private lazy var nextButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "forward.fill"), for: .normal)
        button.tintColor = .label
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(handleNextButtonTap), for: .touchUpInside)
        return button
    }()
    
    private lazy var stopButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "stop.fill"), for: .normal)
        button.tintColor = .label
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(handleStopButtonTap), for: .touchUpInside)
        return button
    }()
    
    private lazy var dismissButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold)
        let image = UIImage(systemName: "xmark.circle.fill", withConfiguration: config)
        button.setImage(image, for: .normal)
        button.tintColor = .tertiaryLabel
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(dismissPlayer), for: .touchUpInside)
        return button
    }()

    
    // MARK: - Initialization
    init(musicPlayer: MusicPlayer) {
        self.musicPlayer = musicPlayer
        super.init(nibName: nil, bundle: nil)
        musicPlayer.delegate = self
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemBackground
        setupUI()
        updateUI(with: musicPlayer.currentItem)
        // setupTimeObserver()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // 画面が閉じられるときにオブザーバーを削除
        // removeTimeObserver()
    }


    
    // MARK: - UI Setup
    private func setupUI() {
        view.addSubview(dismissButton)
        view.addSubview(titleLabel)
        view.addSubview(artistLabel)
        view.addSubview(playbackSlider)
        view.addSubview(currentTimeLabel)
        view.addSubview(remainingTimeLabel)
        view.addSubview(upcomingTracksStackView)
        
        let playbackStackView = UIStackView(arrangedSubviews: [previousButton, playPauseButton, nextButton, stopButton])
        playbackStackView.axis = .horizontal
        playbackStackView.distribution = .equalCentering
        playbackStackView.alignment = .center
        playbackStackView.spacing = 30
        playbackStackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(playbackStackView)
        
        NSLayoutConstraint.activate([
            dismissButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            dismissButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 100),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            artistLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            artistLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            artistLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            playbackSlider.topAnchor.constraint(equalTo: artistLabel.bottomAnchor, constant: 80),
            playbackSlider.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            playbackSlider.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            currentTimeLabel.topAnchor.constraint(equalTo: playbackSlider.bottomAnchor, constant: 5),
            currentTimeLabel.leadingAnchor.constraint(equalTo: playbackSlider.leadingAnchor),
            
            remainingTimeLabel.topAnchor.constraint(equalTo: playbackSlider.bottomAnchor, constant: 5),
            remainingTimeLabel.trailingAnchor.constraint(equalTo: playbackSlider.trailingAnchor),
            
            playbackStackView.topAnchor.constraint(equalTo: playbackSlider.bottomAnchor, constant: 50),
            playbackStackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            upcomingTracksStackView.topAnchor.constraint(equalTo: playbackStackView.bottomAnchor,constant:40),
            upcomingTracksStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant:20),
            upcomingTracksStackView.trailingAnchor.constraint(equalTo:view.trailingAnchor,constant:-20)


        ])
        
        // スライダーのアクション設定
        playbackSlider.addTarget(self, action: #selector(handleSliderChange), for: .valueChanged)
        playbackSlider.addTarget(self, action: #selector(handleSliderDidEndSlide), for: .touchUpInside)
    }
    
    // MARK: - Actions


    @objc private func handlePreviousButtonTap() { musicPlayer.playPrevious() }
    @objc private func handlePlayPauseButtonTap() { musicPlayer.togglePlayback() }
    @objc private func handleStopButtonTap() { musicPlayer.stopPlayback() }
    @objc private func handleNextButtonTap() { musicPlayer.playNext() }

    @objc private func handleUpcomingTrackTap(_ sender:UIButton){
        let indexToPlay = sender.tag
        musicPlayer.playMusic(with:musicPlayer.allItems , at:indexToPlay)
    }

    
    @objc private func dismissPlayer() {
        dismiss(animated: true)
    }
    
    @objc private func handleSliderChange() {
        // ユーザーがスライダーをドラッグ中に再生時間を更新
        // let newTime = playbackSlider.value
        // currentTimeLabel.text = formatTime(TimeInterval(newTime))
        
        // if let duration = musicPlayer.player?.currentItem?.duration.seconds, duration.isFinite {
        //     remainingTimeLabel.text = formatTime(duration - Double(newTime))
        // }
    }
    
    @objc private func handleSliderDidEndSlide() {
        // スライダーのドラッグが終了したら、AVPlayerの再生位置を移動
        // musicPlayer.seekTo(time: TimeInterval(playbackSlider.value))
    }
    


    // MARK: - Player State Updates
    private func updateUI(with item: DriveItem?) {
        guard let item = item else {
            titleLabel.text = "曲が選択されていません"
            playbackSlider.value = 0
            playbackSlider.maximumValue = 0
            currentTimeLabel.text = "0:00"
            remainingTimeLabel.text = "-0:00"
            clearUpcomingTracks()
            return
        }
        
        // タイトルとアーティスト名を表示
        titleLabel.text = item.name
        
        // 再生/一時停止ボタンのアイコンを切り替え
        let playImageName = musicPlayer.isCurrentlyPlaying ? "pause.fill" : "play.fill"
        playPauseButton.setImage(UIImage(systemName: playImageName), for: .normal)
        

        // スライダーの最大値と現在地を設定
        let duration = musicPlayer.getDuration().seconds
        if duration.isFinite && duration > 0 {
            playbackSlider.maximumValue = Float(duration)
        } else {
            playbackSlider.maximumValue = 0
        }
        
        let currentTime = musicPlayer.getCurrentTime().seconds
        playbackSlider.value = Float(currentTime)
        
        // 時間ラベルを更新
        currentTimeLabel.text = formatTime(currentTime)
        if duration.isFinite {
            remainingTimeLabel.text = formatTime(duration - currentTime)
        } else {
            remainingTimeLabel.text = "-0:00"
        }

        updateUpcomingTracksUI()
    }


    private func updateUpcomingTracksUI(){
        clearUpcomingTracks()

        let nextItems = musicPlayer.upcomingItems(count:5) //何曲表示するか

        for(index , nextItem ) in nextItems.enumerated(){
            let button = UIButton(type: .system)
            button.contentHorizontalAlignment = .left
            button.setTitle("\(index + 1 ).\(nextItem.name)",for:.normal)
            button.setTitleColor(.label, for:.normal)
            button.titleLabel?.font = .systemFont(ofSize:16 , weight: .regular)
            button.titleLabel?.lineBreakMode = .byTruncatingTail
            button.tag = musicPlayer.currentIndex + 1 + index
            button.addTarget(self, action: #selector(handleUpcomingTrackTap(_:)),for:.touchUpInside)

            upcomingTracksStackView.addArrangedSubview(button)
        }
    }

    private func clearUpcomingTracks(){
        upcomingTracksStackView.arrangedSubviews.forEach{$0.removeFromSuperview()}
    }
    
    private func setupTimeObserver() {
        // let time = CMTime(seconds: 1, preferredTimescale: 1000)
        // timeObserverToken = musicPlayer.player?.addPeriodicTimeObserver(forInterval: time, queue: .main) { [weak self] time in
        //     guard let self = self, let currentItem = self.musicPlayer.player?.currentItem else { return }
            
        //     let currentTime = time.seconds
        //     let duration = currentItem.duration.seconds
            
        //     // スライダーが操作されていない時のみ値を更新
        //     if !self.playbackSlider.isTracking {
        //         self.playbackSlider.value = Float(currentTime)
        //     }
            
        //     if duration.isFinite {
        //         let remainingTime = duration - currentTime
        //         self.currentTimeLabel.text = self.formatTime(currentTime)
        //         self.remainingTimeLabel.text = self.formatTime(remainingTime)
        //     }
        // }
    }
    
    private func removeTimeObserver() {
        // if let token = timeObserverToken {
        //     musicPlayer.player?.removeTimeObserver(token)
        //     timeObserverToken = nil
        // }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        guard !time.isNaN, time.isFinite else { return "0:00" }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - MusicPlayerDelegate
extension PlayerViewController: MusicPlayerDelegate {
    func musicPlayerDidStartLoading(item: DriveItem) {
        // UIロード中ステータス
        DispatchQueue.main.async {
            self.titleLabel.text = "\(item.name) を読み込み中..."
            self.playPauseButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
        }
    }
    
    func musicPlayerDidStartPlaying(item: DriveItem) {
        // 再生開始時にUIを更新
        DispatchQueue.main.async {
            self.updateUI(with: item)
        }
    }
    
    func musicPlayerDidTogglePlayback(isPlaying: Bool) {
        // 再生/一時停止ボタンのアイコンを切り替える
        DispatchQueue.main.async {
            let imageName = isPlaying ? "pause.fill" : "play.fill"
            self.playPauseButton.setImage(UIImage(systemName: imageName), for: .normal)
        }
    }
    
    func musicPlayerDidStopPlayback() {
        // 再生停止時にUIをリセット
        DispatchQueue.main.async {
            self.playbackSlider.value = 0
            self.currentTimeLabel.text = "0:00"
            self.remainingTimeLabel.text = "-0:00"
            self.playPauseButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
        }
    }
    
    func musicPlayerDidFinishPlaying() {
        // このビューコントローラーで特別な処理は不要
    }
    
    func musicPlayerDidReceiveError(message: String) {
        // エラー処理
        DispatchQueue.main.async {
            let alert = UIAlertController(title: "エラー", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alert, animated: true)
        }
    }
    
}
