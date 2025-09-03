import UIKit

final class LoginViewController: UIViewController {
    private let signInButton = UIButton(type: .system)
    private let statusLabel  = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Microsoft にサインイン"

        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0

        signInButton.setTitle("Sign in with Microsoft", for: .normal)
        signInButton.addTarget(self, action: #selector(didTapSignIn), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [statusLabel, signInButton])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, multiplier: 0.8)
        ])
    }

    @objc private func didTapSignIn() {
        AuthManager.shared.signInInteractively(from: self) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self.routeToMain()
                case .failure(let error):
                    self.statusLabel.text = "サインイン失敗: \(error.localizedDescription)"
                }
            }
        }
    }

    private func routeToMain() {
        let main = OneDriveViewController()
        let nav = UINavigationController(rootViewController: main)
        // ルート切替（ログイン完了後はメインに置き換える）
        if let sceneDelegate = view.window?.windowScene?.delegate as? SceneDelegate,
           let window = sceneDelegate.window {
            window.rootViewController = nav
            UIView.transition(with: window,
                              duration: 0.3,
                              options: .transitionCrossDissolve,
                              animations: nil,
                              completion: nil)
        } else {
            present(nav, animated: true)
        }
    }
}
