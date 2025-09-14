import Foundation
import MSAL
import UIKit

/// Microsoftアカウントの認証を管理するクラスです。
///
/// このクラスは、アプリ全体で1つのインスタンスのみが存在するように
/// **シングルトン・パターン**で設計されています。
/// これにより、認証の状態を一元的に管理できます。
final class AuthManager {
    /// アプリ全体で共有される唯一のインスタンス。
    static let shared = AuthManager()

    // --- MSAL認証に必要な設定情報 ---
    /// ★ Azure Portalで取得したクライアントID (アプリケーションID) をここに入力します。
    /// これが、あなたのアプリを識別するIDになります。
    private let kClientID = "07ae1968-dfca-4a9a-911d-4c4ff2adbfcc"
    /// ★ 認証局のURLです。通常、この値は変更しません。
    /// "organizations"を指定することで、組織アカウントでのログインが可能になります。
    private let kAuthority = "https://login.microsoftonline.com/organizations"
    /// ★ 認証が完了した後に、MSALがアプリに戻るためのリダイレクトURIです。
    /// フォーマットは "msauth.<バンドルID>://auth" です。
    private let kRedirectUri = "msauth.sota.ios-music://auth"
    /// ★ アプリがMicrosoft Graph APIで何にアクセスしたいかを指定する権限のリストです。
    /// "User.Read"はユーザーの基本情報を読み取る権限、"Files.Read"はOneDriveファイルの読み取り権限です。
    private let kScopes = ["User.Read", "Files.Read"] 

    // --- 内部で使用するプロパティ ---
    /// MSALライブラリの中心となるオブジェクト。認証処理のほとんどをここから呼び出します。
    private var application: MSALPublicClientApplication?
    /// 対話的なログイン画面を表示するために必要な設定です。
    private var webParams: MSALWebviewParameters?

    /// プライベートな初期化メソッドです。
    /// これにより、外部から直接AuthManagerを生成することができなくなります。
    private init() {
        do {
            // 認証局のURLを安全にURL型に変換します。
            guard let authorityURL = URL(string: kAuthority) else { return }
            let authority = try MSALAADAuthority(url: authorityURL)

            // MSALの設定オブジェクトを作成します。
            // Client IDとRedirect URI、Authorityを設定します。
            let config = MSALPublicClientApplicationConfig(clientId: kClientID, redirectUri: kRedirectUri, authority: authority)

            // キーチェーン共有グループを設定し、認証情報を安全に保存できるようにします。
            config.cacheConfig.keychainSharingGroup = "com.microsoft.adalcache"
            // 上記の設定を使って、MSALPublicClientApplicationのインスタンスを作成します。
            self.application = try MSALPublicClientApplication(configuration: config)
        } catch {
            // MSALの初期化に失敗した場合、エラーを出力します。
            print("MSAL init error: \(error)")
        }
    }

    // --- 公開メソッド（外部から呼び出す関数） ---

    /// 認証画面を表示する親のビューコントローラー (画面) を設定します。
    /// ログイン処理を呼び出す前に、必ずこの関数を呼び出す必要があります。
    func prepareWebParams(presenting: UIViewController) {
        self.webParams = MSALWebviewParameters(authPresentationViewController: presenting)
    }

    /// 現在ログインしているアカウントを取得します。
    /// アプリ起動時に、すでにログインしているかを判定するのに使用します。
    func currentAccount(completion: @escaping (MSALAccount?) -> Void) {
        // MSALアプリケーションのインスタンスがなければ処理を終了します。
        guard let app = application else { completion(nil); return }
        let params = MSALParameters()
        // コールバックをメインスレッドで実行するように設定します。
        params.completionBlockQueue = .main
        
        // 現在ログインしているアカウントを非同期で取得します。
        app.getCurrentAccount(with: params) { account, _, error in
            if let error = error {
                print("getCurrentAccount error: \(error)")
            }
            completion(account)
        }
    }

    /// ユーザーがログイン済みかどうかをチェックする便利な関数です。
    func isSignedIn(_ completion: @escaping (Bool) -> Void) {
        currentAccount { completion($0 != nil) }
    }

    /// 対話式サインイン
    ///
    /// ユーザーが手動でメールアドレスやパスワードを入力してログインする画面を表示します。
    func signInInteractively(from vc: UIViewController, completion: @escaping (Result<MSALResult, Error>) -> Void) {
        guard let app = application else { return }
        prepareWebParams(presenting: vc) // 認証画面の親を設定します。
        guard let webParams = webParams else { return }

        // 対話的なトークン取得のためのパラメータを設定します。
        let params = MSALInteractiveTokenParameters(scopes: kScopes, webviewParameters: webParams)
        
        // ★ 変更点: ここで「常にログインを強制する」ように設定します。
        // これにより、アカウント選択画面やAuthenticatorアプリへのリダイレクトがスキップされます。
        params.promptType = .login

        // トークンを対話的に取得する処理を実行します。
        app.acquireToken(with: params) { result, error in
            if let error = error {
                completion(.failure(error)) // エラーをコールバックで返します。
                return
            }
            guard let result = result else {
                // 結果がnilの場合のエラーを生成して返します。
                completion(.failure(NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "No Result"])))
                return
            }
            completion(.success(result)) // 成功した場合は結果を返します。
        }
    }

    /// サイレント更新（必要に応じて）
    ///
    /// アプリのバックグラウンドで、ユーザーに操作を求めずに新しいアクセストークンを取得します。
    func acquireTokenSilently(account: MSALAccount, completion: @escaping (Result<MSALResult, Error>) -> Void) {
        guard let app = application else { return }
        // サイレントトークン取得のためのパラメータを設定します。
        let params = MSALSilentTokenParameters(scopes: kScopes, account: account)
        
        // サイレントにトークンを取得する処理を実行します。
        app.acquireTokenSilent(with: params) { result, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let result = result else {
                completion(.failure(NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "No Result"])))
                return
            }
            completion(.success(result))
        }
    }

    /// 現在ログインしているアカウントからサインアウトします。
    func signOut(from authPresentationViewController: UIViewController, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let app = application else { return }
        // 現在のアカウントを取得します。
        currentAccount { account in
            guard let account = account else {
                completion(.success(())) // アカウントがなければ、すでにログアウト済みとみなし成功とします。
                return
            }
            
            let webParams = MSALWebviewParameters(authPresentationViewController: authPresentationViewController)
            let signoutParams = MSALSignoutParameters(webviewParameters: webParams)
            signoutParams.signoutFromBrowser = false
            
            // サインアウト処理を実行します。
            app.signout(with: account, signoutParameters: signoutParams) { _, error in
                if let error = error {
                    completion(.failure(error)) // エラーを返します。
                    return
                }
                completion(.success(())) // 成功を返します。
            }
        }
    }
}


// --- 便利な拡張機能 ---
extension AuthManager {
    
    /// APIを呼び出す際に必要なアクセストークンを取得します。
    ///
    /// この関数は、まずサイレントでトークン取得を試みます。
    /// もしサイレントで失敗した場合（例えばトークンの有効期限切れ）、
    /// 自動的に対話的なログイン画面を表示して再認証を促します。
    ///
    /// - Parameter presentingVC: ログイン画面を表示するための親のビューコントローラー
    /// - Parameter completion: 結果を返すコールバック
    func withAccessToken(from presentingVC: UIViewController,
                         _ completion: @escaping (Result<String, Error>) -> Void) {
        // 現在のアカウントを取得します。
        currentAccount { account in
            guard let account = account else {
                // アカウントが存在しない場合、最初から対話的なログインを開始します。
                return self.acquireTokenInteractivelyAndReturn(from: presentingVC, completion)
            }
            
            // アカウントが存在する場合、まずはサイレントでトークンを更新しようと試みます。
            self.acquireTokenSilently(account: account) { result in
                switch result {
                case .success(let msalResult):
                    // 成功した場合、アクセストークンを返します。
                    completion(.success(msalResult.accessToken))
                    
                case .failure(let error as NSError):
                    // エラーが発生した場合、それが「ユーザー操作が必要」なエラーかチェックします。
                    // エラーコード -50002 は、対話的なログインが必要であることを示します。
                    if error.domain == MSALErrorDomain, error.code == -50002 {
                        // 対話的なログインに切り替えます。
                        self.acquireTokenInteractivelyAndReturn(from: presentingVC, completion)
                    } else {
                        // その他のエラーの場合は、そのまま返します。
                        completion(.failure(error))
                    }
                }
            }
        }
    }
    
    /// `withAccessToken`から呼ばれる、対話的なログインを行うヘルパー関数です。
    /// 処理内容が分かりやすいように、別の関数に分割しています。
    private func acquireTokenInteractivelyAndReturn(from vc: UIViewController,
                                                    _ completion: @escaping (Result<String, Error>) -> Void) {
        // 既存の signInInteractively(from:) を使って対話的なログイン処理を実行します。
        self.signInInteractively(from: vc) { result in
            switch result {
            case .success(let msalResult):
                // 成功した場合は、アクセストークンを返します。
                completion(.success(msalResult.accessToken))
            case .failure(let error):
                // 失敗した場合は、エラーを返します。
                completion(.failure(error))
            }
        }
    }
}
