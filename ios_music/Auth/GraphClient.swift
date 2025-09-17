import Foundation

/// Microsoft Graph APIへのアクセスを管理するクラスです。
///
/// このクラスは、Graph APIのエンドポイントを叩き、
/// フォルダやファイルの情報を取得する機能を提供します。
final class GraphClient {
    /// アプリ全体で共有される唯一のインスタンス。
    static let shared = GraphClient()

    /// OneDriveのルートフォルダID。
    private let kRootFolderId = "root"

    /// プライベートな初期化メソッド。
    private init() {}

    /// 指定されたフォルダの子アイテム（ファイルとサブフォルダ）を非同期で取得します。
    ///
    /// - Parameters:
    ///   - token: OneDriveへのアクセスを許可する認証トークン。
    ///   - folderId: 取得したいフォルダのID。`nil`の場合はルートフォルダを指します。
    ///   - completion: 完了時に呼ばれるコールバック。`Result`型で結果を返します。
    func listChildren(token: String, folderId: String?, completion: @escaping (Result<[DriveItem], Error>) -> Void) {
        let folderPath = folderId ?? kRootFolderId
        let endpoint = "https://graph.microsoft.com/v1.0/me/drive/items/\(folderPath)/children?select=id,name,folder,file,webUrl"
        
        guard let url = URL(string: endpoint) else {
            completion(.failure(GraphError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(GraphError.noData))
                return
            }
            
            do {
                let response = try JSONDecoder().decode(GraphResponse.self, from: data)
                completion(.success(response.value))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    /// 指定されたアイテムのストリーミングダウンロードURLを非同期で取得します。
    ///
    /// - Parameters:
    ///   - itemId: ダウンロードURLを取得したいアイテムのID。
    ///   - token: OneDriveへのアクセスを許可する認証トークン。
    ///   - completion: 完了時に呼ばれるコールバック。`Result`型でURL文字列を返します。
    func getDownloadUrl(for itemId: String, token: String, completion: @escaping (Result<String, Error>) -> Void) {
        let endpoint = "https://graph.microsoft.com/v1.0/me/drive/items/\(itemId)?$select=@microsoft.graph.downloadUrl"
        
        guard let url = URL(string: endpoint) else {
            completion(.failure(GraphError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(GraphError.noData))
                return
            }
            
            do {
                let response = try JSONDecoder().decode(DownloadUrlResponse.self, from: data)
                if let downloadUrl = response.downloadUrl {
                    completion(.success(downloadUrl))
                } else {
                    completion(.failure(GraphError.noDownloadUrl))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}



// --- カスタムエラー ---
enum GraphError: LocalizedError {
    case invalidURL
    case noData
    case noDownloadUrl
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "無効なURLです。"
        case .noData: return "データが取得できませんでした。"
        case .noDownloadUrl: return "ダウンロードURLが見つかりませんでした。"
        }
    }
}
