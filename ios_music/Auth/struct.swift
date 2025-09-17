// --- モデル構造体 ---

/// Graph APIのレスポンスのルート構造体。
struct GraphResponse: Codable {
    let value: [DriveItem]
}

/// OneDrive上のアイテム（ファイルまたはフォルダ）を表す構造体。
struct DriveItem: Codable {
    let id: String
    let name: String
    let folder: Folder?
    let file: File?
    let webUrl: String?
}

/// フォルダ情報を表す構造体。
struct Folder: Codable {}

/// ファイル情報を表す構造体。
struct File: Codable {
    let mimeType: String
}

/// ダウンロードURLのレスポンス構造体。
struct DownloadUrlResponse: Codable {
    enum CodingKeys: String, CodingKey {
        case downloadUrl = "@microsoft.graph.downloadUrl"
    }
    let downloadUrl: String?
}