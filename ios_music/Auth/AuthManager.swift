import Foundation
import MSAL
import UIKit

final class AuthManager {
    static let shared = AuthManager()

    private let kClientID = "07ae1968-dfca-4a9a-911d-4c4ff2adbfcc"
    private let kAuthority = "https://login.microsoftonline.com/organizations"
    private let kRedirectUri = "msauth.sota.ios-music://auth"
    private let kScopes = ["User.Read", "Files.Read"]

    private var application: MSALPublicClientApplication?
    private var webParams: MSALWebviewParameters?

    private init() {
        do {
            guard let authorityURL = URL(string: kAuthority) else { return }
            let authority = try MSALAADAuthority(url: authorityURL)
            let config = MSALPublicClientApplicationConfig(clientId: kClientID, redirectUri: kRedirectUri, authority: authority)
            config.cacheConfig.keychainSharingGroup = "com.microsoft.adalcache"
            self.application = try MSALPublicClientApplication(configuration: config)
        } catch {
            print("MSAL init error: \(error)")
        }
    }

    func prepareWebParams(presenting: UIViewController) {
        self.webParams = MSALWebviewParameters(authPresentationViewController: presenting)
    }

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

    func isSignedIn(_ completion: @escaping (Bool) -> Void) {
        currentAccount { completion($0 != nil) }
    }

    func signInInteractively(from vc: UIViewController, completion: @escaping (Result<MSALResult, Error>) -> Void) {
        guard let app = application else { return }
        prepareWebParams(presenting: vc)
        guard let webParams = webParams else { return }

        let params = MSALInteractiveTokenParameters(scopes: kScopes, webviewParameters: webParams)
        params.promptType = .login

        app.acquireToken(with: params) { result, error in
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

    func acquireTokenSilently(account: MSALAccount, completion: @escaping (Result<MSALResult, Error>) -> Void) {
        guard let app = application else { return }
        let params = MSALSilentTokenParameters(scopes: kScopes, account: account)
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

    func signOut(from authPresentationViewController: UIViewController, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let app = application else { return }
        currentAccount { account in
            guard let account = account else {
                completion(.success(()))
                return
            }

            let webParams = MSALWebviewParameters(authPresentationViewController: authPresentationViewController)
            let signoutParams = MSALSignoutParameters(webviewParameters: webParams)
            signoutParams.signoutFromBrowser = false

            app.signout(with: account, signoutParameters: signoutParams) { _, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                completion(.success(()))
            }
        }
    }
}

extension AuthManager {
    func withAccessToken(from presentingVC: UIViewController,
                         _ completion: @escaping (Result<String, Error>) -> Void) {
        currentAccount { account in
            guard let account = account else {
                return self.acquireTokenInteractivelyAndReturn(from: presentingVC, completion)
            }

            self.acquireTokenSilently(account: account) { result in
                switch result {
                case .success(let msalResult):
                    completion(.success(msalResult.accessToken))
                case .failure(let error as NSError):
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
