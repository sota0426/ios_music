//
//  Untitled.swift
//  ios_music
//
//  Created by 飯森壮太 on 2025/09/18.
//

import UIKit

final class HiddenFoldersViewController: UITableViewController {
    
    weak var delegate: HiddenFoldersViewControllerDelegate?
    
    private var hiddenFolderIds: [String] {
        get { UserDefaults.standard.array(forKey: "hiddenFolderIds") as? [String] ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: "hiddenFolderIds") }
    }
    
    private var hiddenFolders: [DriveItem] = []
    
    init(allItems: [DriveItem]) {
        super.init(style: .insetGrouped)
        self.title = "非表示フォルダ一覧"
        // allItems から hiddenFolderIds に該当するものだけを抽出
        self.hiddenFolders = allItems.filter { hiddenFolderIds.contains($0.id) }
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        hiddenFolders.count
    }
    
    override func tableView(_ tableView: UITableView,
                            cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let folder = hiddenFolders[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.text = folder.name
        cell.accessoryType = .disclosureIndicator
        return cell
    }
    
    override func tableView(_ tableView: UITableView,
                            trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let folder = hiddenFolders[indexPath.row]
        
        let showAction = UIContextualAction(style: .normal, title: "表示") { [weak self] (_, _, completion) in
            guard let self = self else { return }
            // UserDefaults から削除
            var ids = self.hiddenFolderIds
            ids.removeAll { $0 == folder.id }
            self.hiddenFolderIds = ids
            
            // ローカル配列からも削除
            self.hiddenFolders.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .automatic)
            
            // 👇 デリゲートに通知
            self.delegate?.hiddenFoldersDidChange()
            
            completion(true)
        }
        showAction.backgroundColor = .systemGreen
        
        return UISwipeActionsConfiguration(actions: [showAction])
    
    }
}
