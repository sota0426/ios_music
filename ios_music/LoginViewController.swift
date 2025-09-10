import UIKit

/// ログイン画面を表示するビューコントローラーです。
///
/// この画面は、Microsoftアカウントへのサインインボタンと、
/// 認証の状態を表示するラベルを持っています。
final class LoginViewController: UIViewController {
    
    // --- 画面を構成するUI要素 ---
    /// サインインボタン
    private let signInButton = UIButton(type: .system)
    /// 認証の状態やエラーメッセージを表示するラベル
    private let statusLabel  = UILabel()

    // --- ライフサイクルメソッド ---
    /// ビューコントローラーのビューがメモリにロードされた後に呼ばれるメソッドです。
    /// 主にUI要素の初期設定を行います。
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 1. ビューの基本設定
        view.backgroundColor = .systemBackground // ビューの背景色をシステムカラーに設定
        title = "Microsoft にサインイン"          // ナビゲーションバーのタイトルを設定
        
        // 2. ラベルのスタイル設定
        statusLabel.textAlignment = .center     // テキストを中央寄せにする
        statusLabel.numberOfLines = 0           // テキストが複数行にわたることを許可する
        
        // 3. ボタンのスタイルとアクション設定
        signInButton.setTitle("Sign in with Microsoft", for: .normal) // ボタンに表示するテキストを設定
        signInButton.addTarget(self, action: #selector(didTapSignIn), for: .touchUpInside) // ボタンがタップされたときに呼ばれるメソッドを指定
        
        // 4. UIStackViewでUI要素を配置
        // ボタンとラベルを縦に並べるためのスタックビューを作成します。
        let stack = UIStackView(arrangedSubviews: [statusLabel, signInButton])
        stack.axis = .vertical                  // 垂直方向に要素を並べる
        stack.spacing = 16                      // 要素間の間隔を16ポイントにする
        stack.translatesAutoresizingMaskIntoConstraints = false // Auto Layoutを使うことを宣言
        
        // 5. スタックビューをビューに追加し、中央に配置
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor), // 水平方向の中央に配置
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor), // 垂直方向の中央に配置
            stack.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, multiplier: 0.8) // 幅をビューの80%以下に制限
        ])
    }

    // --- アクションメソッド ---
    /// サインインボタンがタップされたときに呼ばれるメソッドです。
    @objc private func didTapSignIn() {
        // AuthManagerのシングルトンインスタンスを取得し、対話的なサインイン処理を開始します。
        // `from: self` で、このビューコントローラーが認証画面の親になることを伝えています。
        AuthManager.shared.signInInteractively(from: self) { result in
            // UIの更新は必ずメインスレッドで行う必要があります。
            // 認証処理はバックグラウンドスレッドで行われる可能性があるため、
            // UIスレッドに戻ってから画面の更新を行います。
            DispatchQueue.main.async {
                switch result {
                case .success:
                    // 認証成功した場合、次の画面に遷移します。
                    self.routeToMain()
                case .failure(let error):
                    // 認証失敗した場合、エラーメッセージをラベルに表示します。
                    self.statusLabel.text = "サインイン失敗: \(error.localizedDescription)"
                }
            }
        }
    }

    // --- 画面遷移のメソッド ---
    /// サインイン成功後に、メイン画面に遷移します。
    private func routeToMain() {
        // メイン画面となる `OneDriveViewController` のインスタンスを生成します。
        let main = OneDriveViewController()
        let nav = UINavigationController(rootViewController: main)
        
        // ルートビューコントローラーを置き換えることで、ログイン画面に戻れないようにします。
        if let sceneDelegate = view.window?.windowScene?.delegate as? SceneDelegate,
           let window = sceneDelegate.window {
            window.rootViewController = nav
            
            // 画面の切り替えにアニメーション（クロスディゾルブ）を適用します。
            UIView.transition(with: window,
                              duration: 0.3,
                              options: .transitionCrossDissolve,
                              animations: nil,
                              completion: nil)
        } else {
            // もし何らかの理由でルートビューコントローラーを置き換えられない場合、モーダル表示に切り替えます。
            present(nav, animated: true)
        }
    }
}
