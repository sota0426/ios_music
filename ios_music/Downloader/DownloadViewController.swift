import UIKit

final class DownloadViewController: UIViewController {

    private let urlTextView = UITextView()
    private let folderTextField = UITextField()
    private let modeSegment = UISegmentedControl(items: ["Playlist", "Multiple"])
    private let formatSegment = UISegmentedControl(items: ["MP3", "MP4"])
    private let resultLabel = UILabel()
    private let downloadButton = UIButton(type: .system)

    // FastAPIのベースURL（RenderにデプロイしたAPIのURLに置き換え）

    // private let apiBase = "https://<your-render-service>.onrender.com"
    private let apiBase = "http://192.168.1.26:8000"

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "YouTube Downloader"

        setupUI()
        setupLayout()
        modeChanged() // 初期状態
    }

    // MARK: - UI Setup
    private func setupUI() {
        // URL入力
        urlTextView.font = .systemFont(ofSize: 16)
        urlTextView.layer.borderWidth = 1
        urlTextView.layer.borderColor = UIColor.lightGray.cgColor
        urlTextView.layer.cornerRadius = 8
        urlTextView.text = "ここにURLを入力"
        view.addSubview(urlTextView)

        // フォルダ名
        folderTextField.placeholder = "保存フォルダ名 (multiple時のみ)"
        folderTextField.borderStyle = .roundedRect
        view.addSubview(folderTextField)

        // モード選択
        modeSegment.selectedSegmentIndex = 0
        modeSegment.addTarget(self, action: #selector(modeChanged), for: .valueChanged)
        view.addSubview(modeSegment)

        // 形式選択
        formatSegment.selectedSegmentIndex = 0
        view.addSubview(formatSegment)

        // ダウンロードボタン
        downloadButton.setTitle("ダウンロード", for: .normal)
        downloadButton.titleLabel?.font = .boldSystemFont(ofSize: 18)
        downloadButton.addTarget(self, action: #selector(didTapDownload), for: .touchUpInside)
        view.addSubview(downloadButton)

        // 結果ラベル
        resultLabel.font = .systemFont(ofSize: 14)
        resultLabel.numberOfLines = 0
        resultLabel.textColor = .label
        view.addSubview(resultLabel)
    }

    private func setupLayout() {
        let margin: CGFloat = 20
        urlTextView.translatesAutoresizingMaskIntoConstraints = false
        folderTextField.translatesAutoresizingMaskIntoConstraints = false
        modeSegment.translatesAutoresizingMaskIntoConstraints = false
        formatSegment.translatesAutoresizingMaskIntoConstraints = false
        downloadButton.translatesAutoresizingMaskIntoConstraints = false
        resultLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            modeSegment.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: margin),
            modeSegment.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: margin),
            modeSegment.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -margin),

            formatSegment.topAnchor.constraint(equalTo: modeSegment.bottomAnchor, constant: margin),
            formatSegment.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: margin),
            formatSegment.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -margin),

            urlTextView.topAnchor.constraint(equalTo: formatSegment.bottomAnchor, constant: margin),
            urlTextView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: margin),
            urlTextView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -margin),
            urlTextView.heightAnchor.constraint(equalToConstant: 100),

            folderTextField.topAnchor.constraint(equalTo: urlTextView.bottomAnchor, constant: margin),
            folderTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: margin),
            folderTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -margin),
            folderTextField.heightAnchor.constraint(equalToConstant: 44),

            downloadButton.topAnchor.constraint(equalTo: folderTextField.bottomAnchor, constant: margin),
            downloadButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            resultLabel.topAnchor.constraint(equalTo: downloadButton.bottomAnchor, constant: margin),
            resultLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: margin),
            resultLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -margin)
        ])
    }

    // MARK: - Actions
    @objc private func modeChanged() {
        let isMultiple = modeSegment.selectedSegmentIndex == 1
        folderTextField.isHidden = !isMultiple
    }

    @objc private func didTapDownload() {
        resultLabel.text = "認証中..."
        AuthManager.shared.withAccessToken(from: self) { result in
            switch result {
            case .success(let token):
                self.callDownloadAPI(token: token)
            case .failure(let error):
                DispatchQueue.main.async {
                    self.resultLabel.text = "Auth error: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - API Call
    private func callDownloadAPI(token: String) {
        let mode = modeSegment.selectedSegmentIndex == 0 ? "playlist" : "multiple"
        let format = formatSegment.selectedSegmentIndex == 0 ? "mp3" : "mp4"

        let raw = urlTextView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let urls = raw
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var body: [String: Any] = [
            "mode": mode,
            "urls": urls,
            "format": format
        ]
        if mode == "multiple" {
            body["folder_name"] = folderTextField.text ?? ""
        }

        guard let url = URL(string: "\(apiBase)/download") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: req) { data, resp, err in
            if let err = err {
                DispatchQueue.main.async { self.resultLabel.text = "通信エラー: \(err.localizedDescription)" }
                return
            }
            guard let data = data,
                  let res = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                DispatchQueue.main.async { self.resultLabel.text = "不正なレスポンス" }
                return
            }
            DispatchQueue.main.async {
                self.resultLabel.text = "結果: \(res)"
            }
        }.resume()
    }
}
