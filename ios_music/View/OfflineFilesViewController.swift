// import UIKit

// final class OfflineFilesViewController: UITableViewController {
    
//     private var offlineItems: [URL] = []
//     private let musicPlayer = MusicPlayer()
    
//     override func viewDidLoad() {
//         super.viewDidLoad()
//         title = "オフライン音楽"
//         tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        
//         // オフラインファイルを読み込む
//         loadOfflineFiles()
//     }
    
//     private func loadOfflineFiles() {
//         offlineItems.removeAll()
//         let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
//         let offlineRoot = docs.appendingPathComponent("OneDriveOffline")
        
//         if let enumerator = FileManager.default.enumerator(at: offlineRoot, includingPropertiesForKeys: nil) {
//             for case let fileURL as URL in enumerator {
//                 if fileURL.pathExtension.lowercased().hasPrefix("mp3") ||
//                    fileURL.pathExtension.lowercased().hasPrefix("m4a") ||
//                    fileURL.pathExtension.lowercased().hasPrefix("wav") {
//                     offlineItems.append(fileURL)
//                 }
//             }
//         }
        
//         // ファイル名順にソート
//         offlineItems.sort { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
        
//         tableView.reloadData()
//     }
    
//     // --- TableView ---
//     override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
//         offlineItems.count
//     }
    
//     override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
//         let url = offlineItems[indexPath.row]
//         let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        
//         var config = cell.defaultContentConfiguration()
//         config.text = url.lastPathComponent
//         config.image = UIImage(systemName: "music.note.list")
//         cell.contentConfiguration = config
        
//         return cell
//     }
    
//     override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
//         tableView.deselectRow(at: indexPath, animated: true)
//         let urls = offlineItems
//         let selectedIndex = indexPath.row
        
//         // DriveItem をダミーで作ってもいいが、ここではファイル名だけ再利用
//         let items = urls.map { url -> DriveItem in
//             DriveItem(id: url.lastPathComponent, name: url.lastPathComponent, folder: nil, file: DriveItem.file(mimeType: "audio/\(url.pathExtension)"), webUrl: <#String?#>)
//         }
        
//         musicPlayer.playMusic(with: items, at: selectedIndex)
//     }
    
//     // --- スワイプで削除 ---
//     override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
//         let deleteAction = UIContextualAction(style: .destructive, title: "削除") { [weak self] _, _, completion in
//             guard let self = self else { return }
//             let url = self.offlineItems[indexPath.row]
//             try? FileManager.default.removeItem(at: url)
//             self.loadOfflineFiles()
//             completion(true)
//         }
//         return UISwipeActionsConfiguration(actions: [deleteAction])
//     }
// }
