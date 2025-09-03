import UIKit
import MSAL

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {

        guard let windowScene = (scene as? UIWindowScene) else { return }

        let window = UIWindow(windowScene: windowScene)

        // 起動時にログイン状態でルーティング
        AuthManager.shared.currentAccount { account in
            if account != nil {
                // ログイン済 → OneDrive 画面へ
                let vc = OneDriveViewController()
                let nav = UINavigationController(rootViewController: vc)
                window.rootViewController = nav
            } else {
                // 未ログイン → ログイン画面へ
                let vc = LoginViewController()
                let nav = UINavigationController(rootViewController: vc)
                window.rootViewController = nav
            }
            self.window = window
            window.makeKeyAndVisible()
        }
    }
}
