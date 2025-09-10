//
// AppDelegate.swift
// ios_music
//
// Created by 飯森壮太 on 2025/09/03.
//

import UIKit
import MSAL

/// アプリのデリゲートクラスです。
/// アプリケーション全体のイベント（起動、バックグラウンド移行など）を管理します。
@main
class AppDelegate: UIResponder, UIApplicationDelegate {

  /// アプリの起動が完了したときに呼ばれる最初のメソッドです。
  /// ここにアプリの初期設定を記述します。
  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    return true
  }

  // MARK: UISceneSession Lifecycle

  /// 新しいシーンセッションが作成されるときに呼ばれます。
  func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
    return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
  }

  /// ユーザーがシーンセッションを破棄したときに呼ばれます。
  func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
  }

  // --- MSALのために追加する重要な部分 ---
    /// アプリが外部からURLを開くときに呼ばれるメソッドです。
    ///
    /// Microsoftアカウントの認証が完了すると、Webブラウザがこのメソッドを使って、
    /// 認証結果を含むURLをアプリに送り返します。
    /// MSALライブラリは、このURLを処理して認証を完了させます。
  func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
    
        // MSALにURLを渡して、認証の結果を処理させます。
        // MSALPublicClientApplication.handleMSALResponseは、受け取ったURLから
        // 認証成功・失敗の情報を解析し、MSALライブラリの内部状態を更新します。
        // この処理がないと、認証が完了してもアプリがトークンを受け取れません。
    return MSALPublicClientApplication.handleMSALResponse(url, sourceApplication: options[UIApplication.OpenURLOptionsKey.sourceApplication] as? String)
  }

}