import Foundation
import MSAL
import UIKit

final class AuthManager {
    static let shared = AuthManager()

    // ★あなたの値に置き換え
    private let kClientID = "07ae1968-dfca-4a9a-911d-4c4ff2adbfcc"
    private let kAuthority = "https://login.microsoftonline.com/organizations"
    private let kRedirectUri = "msauth.sota.ios-music://auth"
    // OneDrive を使う予定なら Files.Read などを含める
    private let kScopes = ["User.Read", "Files.Read"] 

    private var application: MSALPublicClientApplication?
    private var webParams: MSALWebviewParameters?

    private init() {
        do {
            guard let authorityURL = URL(string: kAuthority) else { return }
            let authority = try MSALAADAuthority(url: authorityURL)

            // Use broker-compatible redirect URI: msauth.<bundle_id>://auth
            // Bundle ID = sota.ios-music => redirect = msauth.sota.ios-music://auth
            let config = MSALPublicClientApplicationConfig(clientId: kClientID, redirectUri: kRedirectUri, authority: authority)

            // Ensure keychain sharing group matches entitlements
            config.cacheConfig.keychainSharingGroup = "com.microsoft.adalcache"
            self.application = try MSALPublicClientApplication(configuration: config)
        } catch {
            print("MSAL init error: \(error)")
        }
    }

    func prepareWebParams(presenting: UIViewController) {
        self.webParams = MSALWebviewParameters(authPresentationViewController: presenting)
    }

    /// 現在アカウントの取得（起動時判定に使用）
    func currentAccount(completion: @escaping (MSALAccount?) -> Void) {
        guard let app = application else { completion(nil); return }
        let params = MSALParameters()
        params.completionBlockQueue = .main
        app.getCurrentAccount(with: params) { account, _, error in
            if let error = error {
                print("getCurrentAccount error: \(error)")
            }
            completion(account)
        }
    }

    /// ログインしているかの同期的な便宜関数（コールバック版が本質）
    func isSignedIn(_ completion: @escaping (Bool) -> Void) {
        currentAccount { completion($0 != nil) }
    }

    /// 対話式サインイン
    func signInInteractively(from vc: UIViewController, completion: @escaping (Result<MSALResult, Error>) -> Void) {
        guard let app = application else { return }
        prepareWebParams(presenting: vc)
        guard let webParams = webParams else { return }

        let params = MSALInteractiveTokenParameters(scopes: kScopes, webviewParameters: webParams)
        params.promptType = .selectAccount

        app.acquireToken(with: params) { result, error in
            if let error = error { completion(.failure(error)); return }
            guard let result = result else {
                completion(.failure(NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "No Result"])))
                return
            }
            completion(.success(result))
        }
    }

    /// サイレント更新（必要に応じて）
    func acquireTokenSilently(account: MSALAccount, completion: @escaping (Result<MSALResult, Error>) -> Void) {
        guard let app = application else { return }
        let params = MSALSilentTokenParameters(scopes: kScopes, account: account)
        app.acquireTokenSilent(with: params) { result, error in
            if let error = error { completion(.failure(error)); return }
            guard let result = result else {
                completion(.failure(NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "No Result"])))
                return
            }
            completion(.success(result))
        }
    }

    func signOut(completion: @escaping (Result<Void, Error>) -> Void) {
        guard let app = application else { return }
        currentAccount { account in
            guard let account = account else { completion(.success(())); return }
            let signoutParams = MSALSignoutParameters(webviewParameters: self.webParams ?? MSALWebviewParameters(authPresentationViewController: UIViewController()))
            signoutParams.signoutFromBrowser = false
            app.signout(with: account, signoutParameters: signoutParams) { _, error in
                if let error = error { completion(.failure(error)); return }
                completion(.success(()))
            }
        }
    }
}




extension AuthManager {
    
    // presenting VC を受け取る
    func withAccessToken(from presentingVC: UIViewController,
                         _ completion: @escaping (Result<String, Error>) -> Void) {
        currentAccount { account in
            guard let account = account else {
                // 最初から対話型へ
                return self.acquireTokenInteractivelyAndReturn(from: presentingVC, completion)
            }
            
            self.acquireTokenSilently(account: account) { result in
                switch result {
                case .success(let msalResult):
                    completion(.success(msalResult.accessToken))
                    
                case .failure(let error as NSError):
                    // -50002 = interaction required
                    if error.domain == MSALErrorDomain, error.code == -50002 {
                        self.acquireTokenInteractivelyAndReturn(from: presentingVC, completion)
                    } else {
                        completion(.failure(error))
                    }
                    
                }
            }
        }
    }
        private func acquireTokenInteractivelyAndReturn(from vc: UIViewController,
                                                        _ completion: @escaping (Result<String, Error>) -> Void) {
            // 既存の signInInteractively(from:) を使用
            self.signInInteractively(from: vc) { result in
                switch result {
                case .success(let msalResult):
                    completion(.success(msalResult.accessToken))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }
