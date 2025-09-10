import UIKit
import MSAL

/// アプリの UI シーンのライフサイクルを管理するクラスです。
///
/// アプリの起動時に最初に呼ばれ、どの画面から始めるかを決定します。
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    
    // UIWindow は、アプリのコンテンツを表示するための土台です。
    // このプロパティに、最初に表示する画面の UIWindow を保持します。
    var window: UIWindow?

    /// 新しいシーンが作成され、アプリの UI に接続される準備ができたときに呼ばれます。
    /// ここで、アプリの起動時の最初の画面を設定します。
    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {

        // シーンが UIWindowScene であることを確認します。
        guard let windowScene = (scene as? UIWindowScene) else { return }

        // 新しい UIWindow を作成し、それを windowScene に関連付けます。
        let window = UIWindow(windowScene: windowScene)

        // AuthManager を使って、現在ログインしているアカウントがあるかを確認します。
        // この処理は非同期（バックグラウンド）で行われます。
        AuthManager.shared.currentAccount { account in
            // メインスレッドで UI を更新します。
            DispatchQueue.main.async {
                if account != nil {
                    // アカウントが存在する場合（= ログイン済み）の処理
                    // OneDriveのファイル一覧画面を最初の画面に設定します。
                    let vc = OneDriveViewController()
                    let nav = UINavigationController(rootViewController: vc)
                    window.rootViewController = nav
                } else {
                    // アカウントが存在しない場合（= 未ログイン）の処理
                    // ログイン画面を最初の画面に設定します。
                    let vc = LoginViewController()
                    let nav = UINavigationController(rootViewController: vc)
                    window.rootViewController = nav
                }
                
                // 作成した UIWindow をアプリのメインウィンドウとして設定します。
                self.window = window
                // ウィンドウをキーウィンドウ（一番手前のウィンドウ）にして、表示します。
                window.makeKeyAndVisible()
            }
        }
    }
    
    // 他のシーンデリゲートメソッドは省略...
}
