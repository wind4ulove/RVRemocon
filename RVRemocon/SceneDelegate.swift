//
//  SceneDelegate.swift
//  RVRemocon
//
//  Created by 김선욱 on 8/2/25.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
        guard let _ = (scene as? UIWindowScene) else { return }
    }
//    func scene(_ scene: UIScene,
//               willConnectTo session: UISceneSession,
//               options connectionOptions: UIScene.ConnectionOptions) {
//        guard let _ = (scene as? UIWindowScene) else { return }
////        guard let windowScene = (scene as? UIWindowScene) else { return }
////        let window = UIWindow(windowScene: windowScene)
//
////         ✅ MainControlViewController를 시작화면으로 지정
////        let mainVC = MainControlViewController()
////        window.rootViewController = UINavigationController(rootViewController: mainVC)
////        self.window = window
////        window.makeKeyAndVisible()
//    }
    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        print("🟢 Scene 활성")
        NotificationCenter.default.post(name: .sceneDidBecomeActive, object: nil)
    }
//    func sceneDidBecomeActive(_ scene: UIScene) {
//        // Called when the scene has moved from an inactive state to an active state.
//        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.        
//        print("🟢 Scene 활성")
//
//            guard
//                let windowScene = scene as? UIWindowScene,
//                let window = windowScene.windows.first,
//                let rootVC = window.rootViewController
//            else { return }
//
//            if let nav = rootVC as? UINavigationController,
//               let mainVC = nav.topViewController as? MainControlViewController {
//
//                print("✅ 메인 화면 활성 — BLE 재연결")
//                mainVC.bleReconnect()
//            }
//    }

    func sceneWillResignActive(_ scene: UIScene) {
//        print("🔴 Scene 비활성 — BLE 끊기")
//        BluetoothManager.shared.disconnect()
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
        
//        showLoadingOverlay()
//        if BluetoothManager.shared.isConnected == false {
//            print("⚠️ 블루투스 연결 안됨 — 재검색 시작")
//            checkBluetoothConnection()
//        } else {
//            print("✅ 블루투스 연결됨 — 기존 연결 유지")
//        }
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
        print("📴 Scene 백그라운드 — BLE 끊기")
        BluetoothManager.shared.disconnect()
    }

}

import Foundation

extension Notification.Name {
    static let sceneDidBecomeActive =
        Notification.Name("sceneDidBecomeActive")
}
