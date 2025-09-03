import UIKit
import SafariServices

final class OneDriveViewController: UITableViewController {

    // 現在のフォルダID（nil ならルート）
    private let folderId: String?
    private var items: [DriveItem] = []

    init(folderId: String? = nil, title: String = "OneDrive") {
        self.folderId = folderId
        super.init(style: .insetGrouped)
        self.title = title
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        // サインアウト
        let signOutButton = UIBarButtonItem(title: "Sign Out", style: .plain, target: self, action: #selector(signOut))
        navigationItem.rightBarButtonItem = signOutButton

        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.rowHeight = 54

        // Pull to refresh
        refreshControl = UIRefreshControl()
        refreshControl?.addTarget(self, action: #selector(reload), for: .valueChanged)

        // 初回ロード
        reload()
    }

    @objc private func reload() {
        AuthManager.shared.withAccessToken(from: self)  { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let token):
                    self.fetchItems(token: token)
                case .failure(let error):
                    self.endRefreshing()
                    self.showError(error.localizedDescription)
                }
            }
        }
    }

    private func fetchItems(token: String) {
        GraphClient.shared.listChildren(token: token, folderId: folderId) { result in
            DispatchQueue.main.async {
                self.endRefreshing()
                switch result {
                case .success(let list):
                    self.items = list.sorted(by: { (a, b) -> Bool in
                        // フォルダを先に、次に名前でソート
                        let aIsFolder = a.folder != nil
                        let bIsFolder = b.folder != nil
                        if aIsFolder != bIsFolder { return aIsFolder && !bIsFolder }
                        return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
                    })
                    self.tableView.reloadData()
                case .failure(let error):
                    self.showError(error.localizedDescription)
                }
            }
        }
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
            config.secondaryText = "\(item.folder?.childCount ?? 0) items"
            cell.accessoryType = .disclosureIndicator
            config.image = UIImage(systemName: "folder")
        } else {
            config.secondaryText = item.file?.mimeType
            cell.accessoryType = .none
            config.image = UIImage(systemName: "doc")
        }

        cell.contentConfiguration = config
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = items[indexPath.row]

        if item.folder != nil {
            // フォルダへドリルダウン
            let next = OneDriveViewController(folderId: item.id, title: item.name)
            navigationController?.pushViewController(next, animated: true)
        } else if let webUrl = item.webUrl, let url = URL(string: webUrl) {
            // ファイルは webUrl を表示（簡易）
            let safari = SFSafariViewController(url: url)
            present(safari, animated: true)
        }
    }

    // MARK: - Sign out

    @objc private func signOut() {
        AuthManager.shared.signOut { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    let login = LoginViewController()
                    let nav = UINavigationController(rootViewController: login)
                    if let sceneDelegate = self.view.window?.windowScene?.delegate as? SceneDelegate,
                       let window = sceneDelegate.window {
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
