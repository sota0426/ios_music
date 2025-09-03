import Foundation

struct DriveItemsResponse: Decodable {
    let value: [DriveItem]
    let nextLink: String?

    enum CodingKeys: String, CodingKey {
        case value
        case nextLink = "@odata.nextLink"
    }
}

struct DriveItem: Decodable {
    let id: String
    let name: String
    let webUrl: String?
    let folder: FolderInfo?
    let file: FileInfo?

    struct FolderInfo: Decodable {
        let childCount: Int?
    }
    struct FileInfo: Decodable {
        let mimeType: String?
    }
}

final class GraphClient {
    static let shared = GraphClient()
    private init() {}

    private let base = URL(string: "https://graph.microsoft.com/v1.0")!

    /// ルートまたは任意フォルダ配下の children を取得（簡易ページング）
    func listChildren(token: String, folderId: String?, top: Int = 50, completion: @escaping (Result<[DriveItem], Error>) -> Void) {
        let path: String
        if let id = folderId {
            path = "/me/drive/items/\(id)/children"
        } else {
            path = "/me/drive/root/children"
        }

        var comps = URLComponents(url: base.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            URLQueryItem(name: "$top", value: "\(top)"),
            URLQueryItem(name: "$select", value: "id,name,webUrl,folder,file")
        ]

        guard let url = comps.url else {
            completion(.failure(NSError(domain: "Graph", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: req) { data, resp, err in
            if let err = err { completion(.failure(err)); return }
            guard let data = data else {
                completion(.failure(NSError(domain: "Graph", code: -2, userInfo: [NSLocalizedDescriptionKey: "No data"])))
                return
            }
            do {
                let decoded = try JSONDecoder().decode(DriveItemsResponse.self, from: data)
                completion(.success(decoded.value))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}
